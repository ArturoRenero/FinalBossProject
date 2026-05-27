unit uGameEngine;

interface

uses
  System.SysUtils,
  uTypes,
  uTurnManager,
  uRulesEngine; // <-- ¡NUEVO! Importamos el motor de reglas

type
  TOnDiceRolled  = procedure(PlayerID, DiceValue: Integer) of object;
  TOnPlayerMoved = procedure(PlayerID, NewCellIdx: Integer) of object;
  TOnTurnChanged = procedure(NewPlayerID: Integer) of object;
  TOnGameOver    = procedure(WinnerID: Integer) of object;
  // <-- ¡NUEVO CALLBACK! Para comunicarle a la UI qué pasó
  TOnRuleTriggered = procedure(PlayerID: Integer; const RuleType, Message: string) of object;

  TGameEngine = class
  private
    FTurnManager     : TTurnManager;
    FTotalPlayers    : Integer;
    FGameActive      : Boolean;
    FPlayerPositions : array[0..3] of Integer;

    FOnDiceRolled    : TOnDiceRolled;
    FOnPlayerMoved   : TOnPlayerMoved;
    FOnTurnChanged   : TOnTurnChanged;
    FOnGameOver      : TOnGameOver;
    FOnRuleTriggered : TOnRuleTriggered; // <-- Variable interna

    function RollDiceValue: Integer;
    procedure SetTotalPlayers(Value: Integer);
  public
    constructor Create(ATotalPlayers: Integer);
    destructor  Destroy; override;

    function TryRollDice(PlayerID: Integer): Boolean;
    procedure StartGame;
    procedure ResetGame;

    function GetPlayerPosition(PlayerID: Integer): Integer;
    function GetCurrentPlayer: Integer;

    property TotalPlayers    : Integer          read FTotalPlayers write SetTotalPlayers;
    property GameActive      : Boolean          read FGameActive;
    property OnDiceRolled    : TOnDiceRolled    read FOnDiceRolled    write FOnDiceRolled;
    property OnPlayerMoved   : TOnPlayerMoved   read FOnPlayerMoved   write FOnPlayerMoved;
    property OnTurnChanged   : TOnTurnChanged   read FOnTurnChanged   write FOnTurnChanged;
    property OnGameOver      : TOnGameOver      read FOnGameOver      write FOnGameOver;
    property OnRuleTriggered : TOnRuleTriggered read FOnRuleTriggered write FOnRuleTriggered; // <-- Exponemos la propiedad
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
  pIdx     : Integer;
  rule     : TRuleResult; // <-- Variable para guardar el resultado de la evaluación
begin
  Result := False;
  if not FGameActive then Exit;

  // ── Guard de turno ─────────────────────────────────────────────
  if not FTurnManager.IsPlayerTurn(PlayerID) then Exit;

  Result := True;
  pIdx   := PlayerID - 1;

  // ── Tirar dado ─────────────────────────────────────────────────
  diceVal := RollDiceValue;
  if Assigned(FOnDiceRolled) then
    FOnDiceRolled(PlayerID, diceVal);

  // ── 1er Movimiento ─────────────────────────────────────────────
  newPos := FPlayerPositions[pIdx] + diceVal;

  if newPos >= MAX_CELLS then
    newPos := MAX_CELLS - 1;

  FPlayerPositions[pIdx] := newPos;
  if Assigned(FOnPlayerMoved) then
    FOnPlayerMoved(PlayerID, newPos);

  // ── 2do: Evaluar Reglas (¡NUEVO!) ──────────────────────────────
  rule := TRulesEngine.EvaluateCell(0, newPos); // 0 es el tablero base por ahora

  if rule.Message <> '' then
  begin
    // Si hay un mensaje, le avisamos a la UI
    if Assigned(FOnRuleTriggered)
    then FOnRuleTriggered(PlayerID, rule.RuleType, rule.Message);
  end;

  if rule.NewCell <> -1 then
  begin
    // La regla indica que el jugador fue teletransportado (Ej. Puente a Puente)
    FPlayerPositions[pIdx] := rule.NewCell;
    newPos := rule.NewCell; // Actualizamos la variable local

    // Volver a avisar a la UI del nuevo movimiento
    if Assigned(FOnPlayerMoved) then
      FOnPlayerMoved(PlayerID, newPos);
  end;

  // Manejo de turnos perdidos por reglas (Ej. Posada, Cárcel)
  if rule.TurnsToSkip > 0 then
  begin
    // Aquí, en el futuro, le dirías a uTurnManager que bloquee al jugador
    // FTurnManager.BlockPlayer(PlayerID, rule.TurnsToSkip);
  end;

  // ── Verificar victoria ─────────────────────────────────────────
  if newPos >= MAX_CELLS - 1 then
  begin
    FGameActive := False;
    if Assigned(FOnGameOver) then
      FOnGameOver(PlayerID);
    Exit;
  end;

  // ── Pasar turno ────────────────────────────────────────────────
  FTurnManager.AdvanceTurn;
  if Assigned(FOnTurnChanged) then
    FOnTurnChanged(FTurnManager.CurrentPlayer);
end;

procedure TGameEngine.SetTotalPlayers(Value: Integer);
begin
  if (Value >= 2) and (Value <= 4) then
  begin
    FTotalPlayers := Value;
    if Assigned(FTurnManager) then FTurnManager.Free;
    FTurnManager := TTurnManager.Create(FTotalPlayers);
  end;
end;

procedure TGameEngine.StartGame;
var i: Integer;
begin
  for i := 0 to 3 do FPlayerPositions[i] := 0;
  FTurnManager.Reset;
  FGameActive := True;
  if Assigned(FOnTurnChanged) then FOnTurnChanged(1);
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
