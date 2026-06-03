unit uGameEngine;

interface

uses
  System.SysUtils, System.JSON,
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
    FPlayerBlockedTurns : array[0..3] of Integer; // Control de castigos
    FBoardIndex: Integer;

    FOnDiceRolled    : TOnDiceRolled;
    FOnPlayerMoved   : TOnPlayerMoved;
    FOnTurnChanged   : TOnTurnChanged;
    FOnGameOver      : TOnGameOver;
    FOnRuleTriggered : TOnRuleTriggered;

    FPlayerAvatars: array[0..3] of Integer; // Memoria de avatares

    function RollDiceValue: Integer;
    procedure SetTotalPlayers(Value: Integer);
    function GetPlayerAvatar(Index: Integer): Integer;
    procedure SetPlayerAvatar(Index: Integer; Value: Integer);
  public
    constructor Create(ATotalPlayers: Integer);
    destructor  Destroy; override;

    function TryRollDice(PlayerID: Integer; ForcedDice: Integer = 0): Boolean;
    procedure StartGame;
    procedure ResetGame;

    function GetPlayerPosition(PlayerID: Integer): Integer;
    function GetCurrentPlayer: Integer;

    property TotalPlayers    : Integer          read FTotalPlayers    write SetTotalPlayers;
    property GameActive      : Boolean          read FGameActive;
    property OnDiceRolled    : TOnDiceRolled    read FOnDiceRolled    write FOnDiceRolled;
    property OnPlayerMoved   : TOnPlayerMoved   read FOnPlayerMoved   write FOnPlayerMoved;
    property OnTurnChanged   : TOnTurnChanged   read FOnTurnChanged   write FOnTurnChanged;
    property OnGameOver      : TOnGameOver      read FOnGameOver      write FOnGameOver;
    property OnRuleTriggered : TOnRuleTriggered read FOnRuleTriggered write FOnRuleTriggered;
    property BoardIndex      : Integer          read FBoardIndex      write FBoardIndex;

    // --- NUEVOS MÉTODOS PARA MULTIJUGADOR P2P ---
    function ExportStateToJSON: string;
    procedure ImportStateFromJSON(const JSONState: string);

    property PlayerAvatars[Index: Integer]: Integer read GetPlayerAvatar write SetPlayerAvatar;
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

procedure TGameEngine.SetPlayerAvatar(Index, Value: Integer);
begin
  FPlayerAvatars[Index - 1] := Value;
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

function TGameEngine.GetPlayerAvatar(Index: Integer): Integer;
begin
  Result := FPlayerAvatars[Index - 1];
end;

function TGameEngine.GetPlayerPosition(PlayerID: Integer): Integer;
begin
  Result := FPlayerPositions[PlayerID - 1];
end;

function TGameEngine.GetCurrentPlayer: Integer;
begin
  Result := FTurnManager.CurrentPlayer;
end;

function TGameEngine.TryRollDice(PlayerID: Integer; ForcedDice: Integer): Boolean;
var
  diceVal, newPos, pIdx, i, loops, excess: Integer;
  rule: TRuleResult;
begin
  Result := False;
  if not FGameActive then Exit;
  if not FTurnManager.IsPlayerTurn(PlayerID) then Exit;

  Result := True;
  pIdx   := PlayerID - 1;

  // 1. Tirar dado
  diceVal := RollDiceValue;
  if ForcedDice > 0
  then diceVal := ForcedDice
  else diceVal := RollDiceValue;

  if Assigned(FOnDiceRolled)
  then FOnDiceRolled(PlayerID, diceVal);

  // 2. Movimiento
  newPos := FPlayerPositions[pIdx] + diceVal;

  // ── LÓGICA DE REBOTE EXACTO A LA META ──
  if newPos > WINNING_CELL then
  begin
    // Calculamos cuánto nos pasamos. Ej: Meta es 63, tiramos desde la 61 un 4.
    // newPos = 65. Exceso = 2.
    // Nueva Posición Real = 63 - 2 = 61. ¡El jugador rebota!
    excess := newPos - WINNING_CELL;
    newPos := WINNING_CELL - excess;

    // Le avisamos a la UI que muestre una alerta visual del rebote
    if Assigned(FOnRuleTriggered) then
      FOnRuleTriggered(PlayerID, 'BOUNCE', Format('¡Te pasaste por %d! Rebotas hacia atrás.', [excess]));
  end;

  // -- SISTEMA DE RESCATE DEL POZO --
  if newPos = 31 then
  begin
    for i := 0 to FTotalPlayers - 1 do
      if (i <> pIdx) and (FPlayerPositions[i] = 31) then
        FPlayerBlockedTurns[i] := 0;
  end;

  FPlayerPositions[pIdx] := newPos;
  if Assigned(FOnPlayerMoved) then FOnPlayerMoved(PlayerID, newPos);

  // 3. Evaluar Reglas (Puede que el rebote te haga caer en una Oca o Laberinto)
  rule := TRulesEngine.EvaluateCell(FBoardIndex, newPos);

  if rule.Message <> '' then
  begin
    if Assigned(FOnRuleTriggered) then
      FOnRuleTriggered(PlayerID, rule.RuleType, rule.Message);
  end;

  // Si hay teletransporte
  if rule.NewCell <> -1 then
  begin
    FPlayerPositions[pIdx] := rule.NewCell;
    newPos := rule.NewCell;
    if Assigned(FOnPlayerMoved) then FOnPlayerMoved(PlayerID, newPos);
  end;

  // Si la regla indica perder turnos
  if rule.TurnsToSkip > 0 then
    FPlayerBlockedTurns[pIdx] := rule.TurnsToSkip;

  // ── VERIFICAR VICTORIA EXACTA ──
  if newPos = WINNING_CELL then
  begin
    FGameActive := False; // Bloquea los dados
    if Assigned(FOnGameOver) then FOnGameOver(PlayerID);
    Exit;
  end;

  // 4. PASAR TURNO (Bucle Inteligente)
  if not rule.RollAgain then
  begin
    loops := 0;
    repeat
      FTurnManager.AdvanceTurn;
      pIdx := FTurnManager.CurrentPlayer - 1;

      if FPlayerBlockedTurns[pIdx] > 0 then
      begin
         FPlayerBlockedTurns[pIdx] := FPlayerBlockedTurns[pIdx] - 1;
      end
      else
         Break;

      Inc(loops);
    until loops >= FTotalPlayers;
  end;

  if Assigned(FOnTurnChanged) then
    FOnTurnChanged(FTurnManager.CurrentPlayer);
end; // TryRollDice()

function TGameEngine.ExportStateToJSON: string;
var
  JSONObj: TJSONObject;
  ArrPos, ArrBlocked, ArrAvatars: TJSONArray;
  i: Integer;
begin
  JSONObj := TJSONObject.Create;
  try
    // Variables simples
    JSONObj.AddPair('BoardIndex', TJSONNumber.Create(FBoardIndex));
    JSONObj.AddPair('GameActive', TJSONBool.Create(FGameActive));
    JSONObj.AddPair('TotalPlayers', TJSONNumber.Create(FTotalPlayers));
    JSONObj.AddPair('CurrentTurn', TJSONNumber.Create(FTurnManager.CurrentPlayer));

    // Arreglo de posiciones
    ArrPos := TJSONArray.Create;
    for i := 0 to 3
    do ArrPos.Add(FPlayerPositions[i]);
    JSONObj.AddPair('Positions', ArrPos);

    // Arreglo de castigos (turnos perdidos)
    ArrBlocked := TJSONArray.Create;
    for i := 0 to 3
    do ArrBlocked.Add(FPlayerBlockedTurns[i]);
    JSONObj.AddPair('BlockedTurns', ArrBlocked);

    ArrAvatars := TJSONArray.Create;
    for i := 0 to 3
    do ArrAvatars.Add(FPlayerAvatars[i]);
    JSONObj.AddPair('Avatars', ArrAvatars);

    Result := JSONObj.ToJSON;
  finally
    JSONObj.Free;
  end;
end; // ExportStateToJSON()

procedure TGameEngine.ImportStateFromJSON(const JSONState: string);
var
  JSONVal: TJSONValue;
  JSONObj: TJSONObject;
  ArrPos, ArrBlocked, ArrAvatars: TJSONArray;
  i, oldPos, newPos, newTurn: Integer;
begin
  JSONVal := TJSONObject.ParseJSONValue(JSONState);
  if not (JSONVal is TJSONObject) then Exit;

  JSONObj := JSONVal as TJSONObject;
  try
    FBoardIndex := JSONObj.GetValue<Integer>('BoardIndex');
    FGameActive := JSONObj.GetValue<Boolean>('GameActive');

    // ── ¡SOLUCIÓN AL BUG 1! Usamos la Propiedad (sin la 'F') para que reconstruya los turnos ──
    TotalPlayers := JSONObj.GetValue<Integer>('TotalPlayers');

    newTurn := JSONObj.GetValue<Integer>('CurrentTurn');
    while FTurnManager.CurrentPlayer <> newTurn do
      FTurnManager.AdvanceTurn;

    ArrPos := JSONObj.GetValue('Positions') as TJSONArray;
    ArrBlocked := JSONObj.GetValue('BlockedTurns') as TJSONArray;
    ArrAvatars := JSONObj.GetValue('Avatars') as TJSONArray;

    for i := 0 to 3 do
    begin
      oldPos := FPlayerPositions[i];
      newPos := ArrPos.Items[i].AsType<Integer>;

      FPlayerPositions[i] := newPos;
      FPlayerBlockedTurns[i] := ArrBlocked.Items[i].AsType<Integer>;

      if Assigned(ArrAvatars) then
        FPlayerAvatars[i] := ArrAvatars.Items[i].AsType<Integer>;

      if (oldPos <> newPos) and Assigned(FOnPlayerMoved) then
      begin
        FOnPlayerMoved(i + 1, newPos);
      end;
    end;

    if Assigned(FOnTurnChanged) then
      FOnTurnChanged(FTurnManager.CurrentPlayer);

  finally
    JSONVal.Free;
  end;
end; // ImportStateFromJSON()

end.
