unit uNetworkManager;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  IdTCPServer, IdTCPClient, IdContext, IdGlobal, IdStack,
  IdBaseComponent, IdComponent, IdCustomTCPServer;

type
  TNetMessageEvent = procedure(const Command: string; JSONData: TJSONObject) of object;

  TNetworkManager = class
  private
    FTCPServer : TIdTCPServer;
    FTCPClient : TIdTCPClient;
    FIsHost    : Boolean;
    FPlayerIPs : TStringList;

    FOnMessageReceived: TNetMessageEvent;

    procedure ServerExecute(AContext: TIdContext);
    procedure StartClientListener;
    procedure ProcessIncomingMessage(const RawMessage: string);
  public
    constructor Create;
    destructor Destroy; override;

    function  GetLocalIP: string;
    procedure StartAsHost(Port: Integer);
    procedure ConnectToHost(IP: string; Port: Integer);
    procedure Disconnect;

    procedure BroadcastState(const StateJSON: string);
    procedure SendCommand(const Command: string; JSONData: TJSONObject = nil);

    property IsHost: Boolean read FIsHost;
    property OnMessageReceived: TNetMessageEvent read FOnMessageReceived write FOnMessageReceived;
  end;

implementation

constructor TNetworkManager.Create;
begin
  inherited Create;
  FPlayerIPs := TStringList.Create;
  FTCPServer := TIdTCPServer.Create(nil);
  FTCPServer.OnExecute := ServerExecute;
  FTCPClient := TIdTCPClient.Create(nil);
  FIsHost := False;
end;

destructor TNetworkManager.Destroy;
begin
  Disconnect;
  FPlayerIPs.Free;
  FTCPServer.Free;
  FTCPClient.Free;
  inherited;
end;

function TNetworkManager.GetLocalIP: string;
begin
  TIdStack.IncUsage;
  try
    Result := GStack.LocalAddress;
  finally
    TIdStack.DecUsage;
  end;
end;

procedure TNetworkManager.StartAsHost(Port: Integer);
begin
  Disconnect;
  FIsHost := True;
  FTCPServer.DefaultPort := Port;
  FTCPServer.Active := True;
end;

procedure TNetworkManager.ConnectToHost(IP: string; Port: Integer);
begin
  Disconnect;
  FIsHost := False;
  FTCPClient.Host := IP;
  FTCPClient.Port := Port;
  FTCPClient.Connect;
  StartClientListener;
end;

procedure TNetworkManager.Disconnect;
begin
  if Assigned(FTCPServer) and FTCPServer.Active then
    FTCPServer.Active := False;
  if Assigned(FTCPClient) and FTCPClient.Connected then
    FTCPClient.Disconnect;
end;

procedure TNetworkManager.ServerExecute(AContext: TIdContext);
var
  Line: string;
begin
  Line := AContext.Connection.IOHandler.ReadLn();
  if Line <> '' then
  begin
    if FPlayerIPs.IndexOf(AContext.Binding.PeerIP) = -1 then
      FPlayerIPs.Add(AContext.Binding.PeerIP);
    ProcessIncomingMessage(Line);
  end;
end;

procedure TNetworkManager.StartClientListener;
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      Line: string;
    begin
      while Assigned(FTCPClient) and FTCPClient.Connected do
      begin
        try
          Line := FTCPClient.IOHandler.ReadLn();
          if Line <> '' then
            ProcessIncomingMessage(Line);
        except
          Break;
        end;
      end;
    end).Start;
end;

procedure TNetworkManager.BroadcastState(const StateJSON: string);
var
  DataObj: TJSONObject;
begin
  if not FIsHost then Exit;
  DataObj := TJSONObject.ParseJSONValue(StateJSON) as TJSONObject;
  try
    // Empaqueta el estado general y lo lanza por la red
    SendCommand('STATE', DataObj);
  finally
    DataObj.Free;
  end;
end;

procedure TNetworkManager.SendCommand(const Command: string; JSONData: TJSONObject = nil);
var
  JSONMsg: TJSONObject;
  RawMsg: string;
  List: TList;
  Context: TIdContext;
  i: Integer;
begin
  JSONMsg := TJSONObject.Create;
  try
    JSONMsg.AddPair('command', Command);
    if Assigned(JSONData) then
      JSONMsg.AddPair('data', JSONData.Clone as TJSONObject);

    RawMsg := JSONMsg.ToJSON;

    if FIsHost then
    begin
      // 1. El Host lo ejecuta localmente en su propia pantalla
      ProcessIncomingMessage(RawMsg);

      // 2. ¡EL FIX MAESTRO! El Host lo transmite a TODOS los clientes conectados
      List := FTCPServer.Contexts.LockList;
      try
        for i := 0 to List.Count - 1 do
        begin
          Context := TIdContext(List[i]);
          try
            Context.Connection.IOHandler.WriteLn(RawMsg); // WriteLn asegura la sincronía
          except
          end;
        end;
      finally
        FTCPServer.Contexts.UnlockList;
      end;
    end
    else if FTCPClient.Connected then
    begin
      // 3. El Cliente solo se lo envía al Host
      FTCPClient.IOHandler.WriteLn(RawMsg);
    end;
  finally
    JSONMsg.Free;
  end;
end;

procedure TNetworkManager.ProcessIncomingMessage(const RawMessage: string);
begin
  TThread.Queue(nil,
    procedure
    var
      JSONVal: TJSONValue;
      JSONObj, DataObj: TJSONObject;
      Command: string;
    begin
      JSONVal := TJSONObject.ParseJSONValue(RawMessage);
      if Assigned(JSONVal) and (JSONVal is TJSONObject) then
      begin
        JSONObj := JSONVal as TJSONObject;
        Command := JSONObj.GetValue('command').Value;

        DataObj := nil;
        JSONObj.TryGetValue<TJSONObject>('data', DataObj);

        if Assigned(FOnMessageReceived) then
          FOnMessageReceived(Command, DataObj);

        JSONVal.Free;
      end;
    end);
end;

end.
