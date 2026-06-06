unit uBotAI;

// Controla los turnos de los bots sin mover directamente el motor del juego.
// El bot espera un momento para simular pensamiento y después solicita una tirada
// al formulario principal. Así el Host puede mandar la misma tirada por LAN/Bluetooth.

interface

uses
  System.SysUtils, System.Classes, uGameEngine;

type
  TBotRollRequestEvent = procedure(PlayerID: Integer) of object;

  TBotAI = class
  private
    FPlayerID: Integer;
    FGameEngine: TGameEngine;
    FThinking: Boolean;
    FOnRollRequested: TBotRollRequestEvent;
  public
    constructor Create(APlayerID: Integer; AEngine: TGameEngine);

    procedure AsignarAvatarAleatorio;
    procedure JugarTurno;

    property PlayerID: Integer read FPlayerID;
    property OnRollRequested: TBotRollRequestEvent read FOnRollRequested write FOnRollRequested;
  end;

implementation

constructor TBotAI.Create(APlayerID: Integer; AEngine: TGameEngine);
begin
  inherited Create;
  FPlayerID := APlayerID;
  FGameEngine := AEngine;
  FThinking := False;
end;

procedure TBotAI.AsignarAvatarAleatorio;
var
  Available: TArray<Integer>;
  i, randIdx: Integer;
begin
  SetLength(Available, 0);

  // Buscar avatares del 1 al 4 que no estén tomados por el motor.
  for i := 1 to 4 do
  begin
    if (FGameEngine.PlayerAvatars[1] <> i) and
       (FGameEngine.PlayerAvatars[2] <> i) and
       (FGameEngine.PlayerAvatars[3] <> i) and
       (FGameEngine.PlayerAvatars[4] <> i) then
    begin
      SetLength(Available, Length(Available) + 1);
      Available[Length(Available) - 1] := i;
    end;
  end;

  if Length(Available) > 0 then
  begin
    // Elegir uno al azar y asignarlo al motor.
    randIdx := Random(Length(Available));
    FGameEngine.PlayerAvatars[FPlayerID] := Available[randIdx];
  end;
end;

procedure TBotAI.JugarTurno;
begin
  if FThinking then Exit;
  if not FGameEngine.GameActive then Exit;
  if FGameEngine.GetCurrentPlayer <> FPlayerID then Exit;

  FThinking := True;

  // Hilo anónimo: evita congelar la interfaz mientras el bot "piensa".
  TThread.CreateAnonymousThread(
    procedure
    begin
      // Simulamos un pequeño tiempo de respuesta humano.
      Sleep(1000 + Random(1500));

      // Regresamos al hilo principal para pedir la tirada con seguridad.
      TThread.Queue(TThread(nil),
        procedure
        begin
          try
            if FGameEngine.GameActive and (FGameEngine.GetCurrentPlayer = FPlayerID) then
            begin
              if Assigned(FOnRollRequested) then
                FOnRollRequested(FPlayerID);
            end;
          finally
            FThinking := False;
          end;
        end);
    end).Start;
end;

end.
