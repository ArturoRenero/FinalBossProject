unit uGameEngine;

// Coordinador central. Inicializa y orquesta los sub-módulos. Detecta si hay bots, dispara sus turnos automáticos, y actúa como punto de entrada único para la UI.

interface

uses
  System.SysUtils,
  uTypes,
  uTurnManager;

type
  // Callbacks hacia la UI — el GE no conoce componentes FMX
  TOnDiceRolled  = procedure(PlayerID, DiceValue: Integer) of object;
  TOnPlayerMoved = procedure(PlayerID, NewCellIdx: Integer) of object;
  TOnTurnChanged = procedure(NewPlayerID: Integer) of object;
  TOnGameOver    = procedure(WinnerID: Integer) of object;

  TGameEngine = class
  private
    FTurnManager     : TTurnManager;
    FTotalPlayers    : Integer;
    FGameActive      : Boolean;
    FPlayerPositions : array[0..3] of Integer;  // posición actual de cada jugador (0-based idx de casilla)

    FOnDiceRolled  : TOnDiceRolled;
    FOnPlayerMoved : TOnPlayerMoved;
    FOnTurnChanged : TOnTurnChanged;
    FOnGameOver    : TOnGameOver;

    function RollDiceValue: Integer;
  public
    constructor Create(ATotalPlayers: Integer);
    destructor  Destroy; override;

    // El jugador activo presiona "Tirar Dado"
    // Devuelve False si no era el turno de PlayerID (input ignorado)
    function TryRollDice(PlayerID: Integer): Boolean;

    procedure StartGame;
    procedure ResetGame;

    function GetPlayerPosition(PlayerID: Integer): Integer;
    function GetCurrentPlayer: Integer;

    property GameActive    : Boolean        read FGameActive;
    property OnDiceRolled  : TOnDiceRolled  read FOnDiceRolled  write FOnDiceRolled;
    property OnPlayerMoved : TOnPlayerMoved read FOnPlayerMoved write FOnPlayerMoved;
    property OnTurnChanged : TOnTurnChanged read FOnTurnChanged write FOnTurnChanged;
    property OnGameOver    : TOnGameOver    read FOnGameOver    write FOnGameOver;
  end;

implementation

constructor TGameEngine.Create(ATotalPlayers: Integer);
var i: Integer;
begin
  inherited Create;
  FTotalPlayers := ATotalPlayers;
  FTurnManager  := TTurnManager.Create(ATotalPlayers);
  FGameActive   := False;
  for i := 0 to 3 do
    FPlayerPositions[i] := 0;
end;

destructor TGameEngine.Destroy;
begin
  FTurnManager.Free;
  inherited;
end;

function TGameEngine.RollDiceValue: Integer;
begin
  Result := Random(6) + 1;  // 1..6
end;

function TGameEngine.TryRollDice(PlayerID: Integer): Boolean;
var
  diceVal  : Integer;
  newPos   : Integer;
  pIdx     : Integer;  // índice 0-based del jugador
begin
  Result := False;
  if not FGameActive then Exit;

  // ── Guard de turno ─────────────────────────────────────────────
  // Si no es el turno de PlayerID, ignorar el input completamente
  if not FTurnManager.IsPlayerTurn(PlayerID) then Exit;

  Result := True;
  pIdx   := PlayerID - 1;

  // ── Tirar dado ─────────────────────────────────────────────────
  diceVal := RollDiceValue;
  if Assigned(FOnDiceRolled)
  then FOnDiceRolled(PlayerID, diceVal);

  // ── Mover jugador ──────────────────────────────────────────────
  newPos := FPlayerPositions[pIdx] + diceVal;

  // Sin reglas aún (F7): si supera el límite, no avanza más allá
  // del último casillero válido
  if newPos >= MAX_CELLS
  then newPos := MAX_CELLS - 1;

  FPlayerPositions[pIdx] := newPos;

  if Assigned(FOnPlayerMoved)
  then FOnPlayerMoved(PlayerID, newPos);

  // ── Verificar victoria ─────────────────────────────────────────
  if newPos >= MAX_CELLS - 1 then
  begin
    FGameActive := False;
    if Assigned(FOnGameOver)
    then FOnGameOver(PlayerID);
    Exit;
  end;

  // ── Pasar turno ────────────────────────────────────────────────
  FTurnManager.AdvanceTurn;
  if Assigned(FOnTurnChanged)
  then FOnTurnChanged(FTurnManager.CurrentPlayer);
end; // TryRollDice

procedure TGameEngine.StartGame;
var i: Integer;
begin
  for i := 0 to 3 do
    FPlayerPositions[i] := 0;

  FTurnManager.Reset;
  FGameActive := True;

  if Assigned(FOnTurnChanged)
  then FOnTurnChanged(1);
end;

procedure TGameEngine.ResetGame;
begin
  StartGame;
end;

function TGameEngine.GetPlayerPosition(PlayerID: Integer): Integer;
begin
  Result := FPlayerPositions[PlayerID - 1];
end;

function TGameEngine.GetCurrentPlayer: Integer;
begin
  Result := FTurnManager.CurrentPlayer;
end;

end.
