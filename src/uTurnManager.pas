unit uTurnManager;

// Gestiona el ciclo de turnos con una bandera booleana por jugador. Si el jugador que intenta tirar el dado no es el activo, el procedimiento hace Exit inmediato. Emite eventos al GE cuando el turno cambia.

interface

type
  TTurnManager = class
  private
    FCurrentPlayer : Integer;      // 1..FTotalPlayers
    FTotalPlayers  : Integer;
    FPlayerActive  : array[1..4] of Boolean;
  public
    constructor Create(ATotalPlayers: Integer);

    function  IsPlayerTurn(PlayerID: Integer): Boolean;
    function  CurrentPlayer: Integer;
    procedure AdvanceTurn;
    procedure Reset;
  end;

implementation

constructor TTurnManager.Create(ATotalPlayers: Integer);
var i: Integer;
begin
  inherited Create;
  FTotalPlayers  := ATotalPlayers;
  FCurrentPlayer := 1;
  for i := 1 to 4 do
    FPlayerActive[i] := (i = 1);  // Player 1 empieza
end;

function TTurnManager.IsPlayerTurn(PlayerID: Integer): Boolean;
begin
  Result := (PlayerID >= 1) and (PlayerID <= 4) and FPlayerActive[PlayerID];
end;

function TTurnManager.CurrentPlayer: Integer;
begin
  Result := FCurrentPlayer;
end;

procedure TTurnManager.AdvanceTurn;
begin
  FPlayerActive[FCurrentPlayer] := False;
  FCurrentPlayer := (FCurrentPlayer mod FTotalPlayers) + 1;
  FPlayerActive[FCurrentPlayer] := True;
end;

procedure TTurnManager.Reset;
var i: Integer;
begin
  FCurrentPlayer := 1;
  for i := 1 to 4 do
    FPlayerActive[i] := (i = 1);
end;

end.
