unit uGameEngine;

interface

uses
  System.SysUtils,
  uTypes,
  uTurnManager,
  uRulesEngine;

type
  TOnDiceRolled  = procedure(PlayerID, DiceValue: Integer) of object;
  TOnPlayerMoved = procedure(PlayerID, NewCellIdx: Integer) of object;
  TOnTurnChanged = procedure(NewPlayerID: Integer) of object;
  TOnGameOver    = procedure(WinnerID: Integer) of object;
  TOnRuleTriggered = procedure(PlayerID: Integer; const RuleType, Message: string) of object;

  TGameEngine = class
  private
    FTurnManager        : TTurnManager;
    FTotalPlayers       : Integer;
    FGameActive         : Boolean;
    FPlayerPositions    : array[0..3] of Integer;
    FPlayerBlockedTurns : array[0..3] of Integer; // <-- NUEVO: Control de castigos

    FOnDiceRolled    : TOnDiceRolled;
    FOnPlayerMoved   : TOnPlayerMoved;
    FOnTurnChanged   : TOnTurnChanged;
    FOnGameOver      : TOnGameOver;
    FOnRuleTriggered : TOnRuleTriggered;

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
    property OnRuleTriggered : TOnRuleTriggered read FOnRuleTriggered write FOnRuleTriggered;
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
  begin
    FPlayerPositions[i] := 0;
    FPlayerBlockedTurns[i] := 0;
  end;
end;

destructor TGameEngine.Destroy;
begin
  FTurnManager.Free;
  inherited;
end;

function TGameEngine.RollDiceValue: Integer;
begin
  Result := Random(6) + 1;
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
  for i := 0 to 3 do
  begin
    FPlayerPositions[i] := 0;
    FPlayerBlockedTurns[i] := 0; // Limpiar castigos de partidas anteriores
  end;
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

function TGameEngine.TryRollDice(PlayerID: Integer): Boolean;
var
  diceVal, newPos, pIdx, i, loops: Integer;
  rule: TRuleResult;
begin
  Result := False;
  if not FGameActive then Exit;

  // Si no es el turno de PlayerID, ignorar el input
  if not FTurnManager.IsPlayerTurn(PlayerID) then Exit;

  Result := True;
  pIdx   := PlayerID - 1;

  // 1. Tirar dado
  diceVal := RollDiceValue;
  if Assigned(FOnDiceRolled) then FOnDiceRolled(PlayerID, diceVal);

  // 2. Movimiento
  newPos := FPlayerPositions[pIdx] + diceVal;
  if newPos >= MAX_CELLS then newPos := MAX_CELLS - 1;

  // -- ¡SISTEMA DE RESCATE DEL POZO! --
  // Si caes en la casilla 31, liberas a cualquier otro que estuviera atrapado ahí
  if newPos = 31 then
  begin
    for i := 0 to FTotalPlayers - 1 do
      if (i <> pIdx) and (FPlayerPositions[i] = 31) then
        FPlayerBlockedTurns[i] := 0; // ¡Ha sido rescatado!
  end;

  FPlayerPositions[pIdx] := newPos;
  if Assigned(FOnPlayerMoved) then FOnPlayerMoved(PlayerID, newPos);

  // 3. Evaluar Reglas
  rule := TRulesEngine.EvaluateCell(0, newPos);

  if rule.Message <> '' then
  begin
    if Assigned(FOnRuleTriggered) then
      FOnRuleTriggered(PlayerID, rule.RuleType, rule.Message);
  end;

  // Si hay teletransporte (Oca, Laberinto, Muerte)
  if rule.NewCell <> -1 then
  begin
    FPlayerPositions[pIdx] := rule.NewCell;
    newPos := rule.NewCell;
    if Assigned(FOnPlayerMoved) then FOnPlayerMoved(PlayerID, newPos);
  end;

  // Si la regla indica perder turnos, aplicamos el castigo
  if rule.TurnsToSkip > 0 then
    FPlayerBlockedTurns[pIdx] := rule.TurnsToSkip;

  // Verificar victoria
  if newPos >= MAX_CELLS - 1 then
  begin
    FGameActive := False;
    if Assigned(FOnGameOver) then FOnGameOver(PlayerID);
    Exit;
  end;

  // 4. PASAR TURNO (Bucle Inteligente)
  // El motor saltará a todos los jugadores que tengan castigos activos
  loops := 0;
  repeat
    FTurnManager.AdvanceTurn;
    pIdx := FTurnManager.CurrentPlayer - 1;

    if FPlayerBlockedTurns[pIdx] > 0 then
    begin
       // Si es menor a 999, es un castigo temporal. Restamos 1 turno.
       // Si es 999 (Pozo), no restamos nada, se queda atrapado.
       if FPlayerBlockedTurns[pIdx] < 999 then
         FPlayerBlockedTurns[pIdx] := FPlayerBlockedTurns[pIdx] - 1;
    end
    else
       Break; // ¡Encontramos a un jugador que sí puede jugar!

    Inc(loops);
  until loops >= FTotalPlayers;

  if Assigned(FOnTurnChanged) then
    FOnTurnChanged(FTurnManager.CurrentPlayer);
end;

end.
