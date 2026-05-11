unit uNetworkManager;

// Maneja conexiones LAN/WiFi con Indy (TIdTCPServer / TIdTCPClient). Serializa el estado del juego en JSON y lo sincroniza entre dispositivos. Almacena IPs de jugadores para reconexión. (v1.0)

interface

uses
  System.SysUtils,
  System.Classes,
  IdTCPServer,      // TIdTCPServer
  IdTCPClient,      // TIdTCPClient
  IdContext,        // TIdContext (conexiones activas en el server)
  IdGlobal,         // Tipos globales de Indy
  IdStack,          // TIdStack.LocalAddress → obtener IP local
  IdBaseComponent,  // Base de componentes Indy
  IdIOHandler,
  IdIOHandlerSocket;

type
  TNetworkManager = class
  private
    FTCPServer : TIdTCPServer;
    FTCPClient : TIdTCPClient;
    FPlayerIPs : TStringList;   // IPs de jugadores para reconexión
    FIsHost    : Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function  GetLocalIP: string;
    procedure StartAsHost(Port: Integer);
    procedure ConnectToHost(IP: string; Port: Integer);
    procedure Disconnect;
    procedure BroadcastState(StateJSON: string);
  end;

implementation

{ TNetworkManager }

constructor TNetworkManager.Create;
begin
  inherited;
  FPlayerIPs := TStringList.Create;
  FTCPServer := TIdTCPServer.Create(nil);
  FTCPClient := TIdTCPClient.Create(nil);
  FIsHost    := False; // siempre se inicializa como cliente en lugar de host
end;

destructor TNetworkManager.Destroy;
begin
  FPlayerIPs.Free; // libera localidades de memoria
  FTCPServer.Free;
  FTCPClient.Free;
  inherited;
end;

function TNetworkManager.GetLocalIP: string;
begin
  Result := GStack.LocalAddress; // consigue IP de maquina actual
end;

procedure TNetworkManager.StartAsHost(Port: Integer);
begin
  FIsHost := True;
  FTCPServer.DefaultPort := Port;
  FTCPServer.Active := True;
end;

procedure TNetworkManager.ConnectToHost(IP: string; Port: Integer);
begin
  FIsHost := False;
  FTCPClient.Host := IP;
  FTCPClient.Port := Port;
  FTCPClient.Connect;
end;

procedure TNetworkManager.Disconnect;
begin
  if FIsHost then
    FTCPServer.Active := False
  else
    FTCPClient.Disconnect;
end;

procedure TNetworkManager.BroadcastState(StateJSON: string);
begin
  // Implementar en Fase 11
end;

end.
