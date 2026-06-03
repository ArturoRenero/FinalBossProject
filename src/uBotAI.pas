unit uBotAI;

// Ejecuta los turnos del Bot. Llama a Sleep() para simular tiempo de respuesta humano, luego ejecuta el lanzamiento de dados y movimiento de ficha, pasando por el mismo RulesEngine que un jugador humano.

interface

uses
  System.SysUtils, System.Classes, uGameEngine;

type
  TBotAI = class
  private
    FPlayerID: Integer;
    FGameEngine: TGameEngine;
  public
    constructor Create(APlayerID: Integer; AEngine: TGameEngine);

    procedure AsignarAvatarAleatorio;
    procedure JugarTurno;

    property PlayerID: Integer read FPlayerID;
  end;

implementation

constructor TBotAI.Create(APlayerID: Integer; AEngine: TGameEngine);
begin
  inherited Create;
  FPlayerID := APlayerID;
  FGameEngine := AEngine;
end;

procedure TBotAI.AsignarAvatarAleatorio;
var
  Available: TArray<Integer>;
  i, randIdx: Integer;
begin
  SetLength(Available, 0);

  // Buscar avatares del 1 al 4 que no estén tomados por el motor
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
    // Elegir uno al azar y asignarlo directo a la memoria del motor
    randIdx := Random(Length(Available));
    FGameEngine.PlayerAvatars[FPlayerID] := Available[randIdx];
  end;
end;

procedure TBotAI.JugarTurno;
begin
  if not FGameEngine.GameActive then Exit;
  if FGameEngine.GetCurrentPlayer <> FPlayerID then Exit;

  // Hilo anónimo: Evita que el juego se congele mientras el Bot "Piensa"
  TThread.CreateAnonymousThread(
    procedure
    begin
      // Simulamos la latencia de un cerebro humano (entre 1 y 2.5 segundos)
      Sleep(1000 + Random(1500));

      // Regresamos al hilo principal para mover las fichas con seguridad
      TThread.Queue(TThread(nil),
        procedure
        begin
          // Doble validación: Asegurarnos de que nadie pausó o cerró el juego mientras pensaba
          if FGameEngine.GameActive and (FGameEngine.GetCurrentPlayer = FPlayerID) then
          begin
            FGameEngine.TryRollDice(FPlayerID);
          end;
        end);
    end).Start;
end;

end.
