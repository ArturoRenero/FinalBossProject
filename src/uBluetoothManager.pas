unit uBluetoothManager;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.Bluetooth;

const
  OCA_SERVICE_UUID = '{1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}';
  OCA_SERVICE_NAME = 'JuegoOcaBT';

type
  TNetMessageEvent = procedure(const Command: string; JSONData: TJSONObject) of object;

  TBluetoothNetworkManager = class
  private
    FIsHost: Boolean;
    FBTManager: TBluetoothManager;
    FServerSocket: TBluetoothServerSocket;
    FConnectedClients: TList<TBluetoothSocket>;
    FClientSocket: TBluetoothSocket;

    FHostThread: TThread;

    FOnMessageReceived: TNetMessageEvent;

    procedure ProcessIncomingMessage(const RawMessage: string);
    procedure StartReaderThread(Socket: TBluetoothSocket);
  public
    constructor Create;
    destructor Destroy; override;

    function GetPairedDevices: TBluetoothDeviceList;

    procedure StartAsHost;
    procedure ConnectToDevice(DeviceName: string);
    procedure Disconnect;

    procedure BroadcastState(const StateJSON: string);
    procedure SendCommand(const Command: string; JSONData: TJSONObject = nil);

    property IsHost: Boolean read FIsHost;
    property OnMessageReceived: TNetMessageEvent read FOnMessageReceived write FOnMessageReceived;
  end;

implementation

constructor TBluetoothNetworkManager.Create;
begin
  inherited Create;
  FConnectedClients := TList<TBluetoothSocket>.Create;
  FBTManager := TBluetoothManager.Current;
  FIsHost := False;
end;

destructor TBluetoothNetworkManager.Destroy;
begin
  Disconnect;
  FConnectedClients.Free;
  inherited;
end;

function TBluetoothNetworkManager.GetPairedDevices: TBluetoothDeviceList;
begin
  Result := nil;
  if Assigned(FBTManager) then
    Result := FBTManager.GetPairedDevices;
end;

procedure TBluetoothNetworkManager.StartAsHost;
var
  LUUID: TGUID;
begin
  Disconnect;
  FIsHost := True;

  if not Assigned(FBTManager) then Exit;

  LUUID := StringToGUID(OCA_SERVICE_UUID);
  FServerSocket := FBTManager.CreateServerSocket(OCA_SERVICE_NAME, LUUID, False);

  FHostThread := TThread.CreateAnonymousThread(
    procedure
    var
      AcceptedSocket: TBluetoothSocket;
    begin
      while FIsHost and Assigned(FServerSocket) do
      begin
        try
          AcceptedSocket := FServerSocket.Accept(1000);
          if Assigned(AcceptedSocket) then
          begin
            // ¡CAMBIADO A QUEUE!
            TThread.Queue(nil, procedure
              begin
                FConnectedClients.Add(AcceptedSocket);
              end);
            StartReaderThread(AcceptedSocket);
          end;
        except
        end;
      end;
    end);
  FHostThread.Start;
end;

procedure TBluetoothNetworkManager.ConnectToDevice(DeviceName: string);
var
  Devices: TBluetoothDeviceList;
  Device: TBluetoothDevice;
  LUUID: TGUID;
  i: Integer;
begin
  Disconnect;
  FIsHost := False;

  if not Assigned(FBTManager) then Exit;

  Devices := FBTManager.GetPairedDevices;
  Device := nil;

  for i := 0 to Devices.Count - 1 do
  begin
    if Devices[i].DeviceName = DeviceName then
    begin
      Device := Devices[i];
      Break;
    end;
  end;

  if Assigned(Device) then
  begin
    LUUID := StringToGUID(OCA_SERVICE_UUID);
    FClientSocket := Device.CreateClientSocket(LUUID, False);
    if Assigned(FClientSocket) then
    begin
      FClientSocket.Connect;
      StartReaderThread(FClientSocket);
    end;
  end
  else
    raise Exception.Create('Dispositivo Bluetooth no encontrado. ¿Están emparejados?');
end;

procedure TBluetoothNetworkManager.Disconnect;
var
  Socket: TBluetoothSocket;
begin
  FIsHost := False;
  if Assigned(FServerSocket) then
  begin
    FServerSocket.Free;
    FServerSocket := nil;
  end;

  if Assigned(FClientSocket) then
  begin
    FClientSocket.Close;
    FClientSocket.Free;
    FClientSocket := nil;
  end;

  for Socket in FConnectedClients do
  begin
    Socket.Close;
    Socket.Free;
  end;
  FConnectedClients.Clear;
end;

procedure TBluetoothNetworkManager.StartReaderThread(Socket: TBluetoothSocket);
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      Bytes: TBytes;
      Buffer, Msg: string;
      p: Integer;
    begin
      Buffer := '';
      while Assigned(Socket) and Socket.Connected do
      begin
        try
          Bytes := Socket.ReceiveData;
          if Length(Bytes) > 0 then
          begin
            Buffer := Buffer + TEncoding.UTF8.GetString(Bytes);

            p := Pos(#10, Buffer);
            while p > 0 do
            begin
              Msg := Copy(Buffer, 1, p - 1);
              Delete(Buffer, 1, p);
              Msg := StringReplace(Msg, #13, '', [rfReplaceAll]);
              if Msg <> '' then ProcessIncomingMessage(Msg);
              p := Pos(#10, Buffer);
            end;
          end
          else Sleep(100);
        except
          Break;
        end;
      end;
    end).Start;
end;

procedure TBluetoothNetworkManager.BroadcastState(const StateJSON: string);
var
  DataObj: TJSONObject;
begin
  if not FIsHost then Exit;
  DataObj := TJSONObject.ParseJSONValue(StateJSON) as TJSONObject;
  try
    SendCommand('STATE', DataObj);
  finally
    DataObj.Free;
  end;
end;

procedure TBluetoothNetworkManager.SendCommand(const Command: string; JSONData: TJSONObject = nil);
var
  JSONMsg: TJSONObject;
  RawMsg: string;
  Bytes: TBytes;
  i: Integer;
begin
  JSONMsg := TJSONObject.Create;
  try
    JSONMsg.AddPair('command', Command);
    if Assigned(JSONData) then
      JSONMsg.AddPair('data', JSONData.Clone as TJSONObject);

    RawMsg := JSONMsg.ToJSON + #13#10;
    Bytes := TEncoding.UTF8.GetBytes(RawMsg);

    if FIsHost then
    begin
      ProcessIncomingMessage(JSONMsg.ToJSON);

      for i := 0 to FConnectedClients.Count - 1 do
      begin
        try
          if FConnectedClients[i].Connected then
            FConnectedClients[i].SendData(Bytes);
        except
        end;
      end;
    end
    else if Assigned(FClientSocket) and FClientSocket.Connected then
    begin
      FClientSocket.SendData(Bytes);
    end;
  finally
    JSONMsg.Free;
  end;
end;

procedure TBluetoothNetworkManager.ProcessIncomingMessage(const RawMessage: string);
begin
  TThread.Queue(TThread(nil), procedure // ¡CORREGIDO!
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
