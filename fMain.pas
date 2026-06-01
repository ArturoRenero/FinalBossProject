unit fMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects, FMX.Layouts,
  System.ImageList, FMX.ImgList, System.JSON, FMX.Ani,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FMX.DialogService.Sync,
  uTypes,
  uDatabase,
  uBoardManager,
  uPlayerManager,
  fAvatarSelectForm,
  uConfig,
  uTurnManager,
  uGameEngine,
  fBoardSelectForm,
  fDiceForm,
  fRulesForm,
  uNetworkManager,
  fLobbyForm;

type
  TfrmMain = class(TForm)
    ilBoards: TImageList;
    lytBoard: TLayout;
    imgBoard: TImage;
    ilAvatars: TImageList;
    imgAvatar1: TImage;
    imgAvatar2: TImage;
    imgAvatar3: TImage;
    imgAvatar4: TImage;
    btnTirarDado: TButton;
    btnCapturar: TButton;
    lytButtons: TLayout;
    rctnglSidebar: TRectangle;
    lblTurno: TLabel;
    lblDado: TLabel;
    btnStartGame: TButton;
    ilDiceFaces: TImageList;
    lblEventoEspecial: TLabel;
    rctnglSpecialEvent: TRectangle;
    imgWell: TImage;
    btnRules: TButton;
    lblCasilla: TLabel;
    stat1: TStatusBar;
    lblCoords: TLabel;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnCapturarClick(Sender: TObject);
    procedure imgBoardDblClick(Sender: TObject);
    procedure btnTirarDadoClick(Sender: TObject);
    procedure imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    function SeleccionarAvatar(PlayerID: Integer; const NombreJugador: string): Boolean;
    procedure imgBoardResize(Sender: TObject);
    procedure btnStartGameClick(Sender: TObject);
    procedure btnRulesClick(Sender: TObject);
  private
    FIndex: Integer;
    FLastX  : Single;
    FLastY  : Single;
    FDemoCell    : Integer;
    FTotalPlayers : Integer;

    // --- VARIABLES DE RED Y MULTIJUGADOR ---
    FNetworkManager: TNetworkManager;
    FLocalPlayerID: Integer;
    FNextPlayerID: Integer;   // Solo lo usa el Host para auto-asignar
    FMyClientToken: string;   // Token de seguridad para evitar Race Conditions
    FPlayerName: string;      // Nombre de este dispositivo

    FDB          : TDatabase;
    FBoardManager  : TBoardManager;
    FPlayerManager : TPlayerManager;
    FGameEngine    : TGameEngine;

    FWalkingPlayer: Integer;
    FWalkTargetCell: Integer;
    FSecondaryTargetCell: Integer;
    FVisualPositions: array[1..4] of Integer;
    FTmrWalk: TTimer;

    FPendingRuleType: string;
    FPendingRuleMessage: string;
    FPendingRulePlayer: Integer;

    FDiceIsRolling: Boolean;

    procedure ResetAvatarsToStart;
    function  GetAvatarImage(PlayerID: Integer): TImage;
    procedure MoveAvatarToCell(PlayerID, CellIdx: Integer);

    procedure GE_OnDiceRolled(PlayerID, DiceValue: Integer);
    procedure GE_OnPlayerMoved(PlayerID, NewCellIdx: Integer);
    procedure GE_OnTurnChanged(NewPlayerID: Integer);
    procedure GE_OnGameOver(WinnerID: Integer);
    procedure GE_OnRuleTriggered(PlayerID: Integer; const RuleType, Message: string);

    procedure tmrWalkTimer(Sender: TObject);
    procedure EjecutarAnimacionRegla(PlayerID: Integer; const RuleType, Message: string);
    procedure Net_OnMessageReceived(const Command: string; JSONData: TJSONObject);
    procedure OnDiceFormClose(Sender: TObject; var Action: TCloseAction);
  end;

var
  frmMain: TfrmMain;

const
  AVATAR_START_OFFSET : array[0..3] of TPointF = (
      (X:  0;  Y:  0),
      (X: 45;  Y:  0),
      (X:  0;  Y: 45),
      (X: 45;  Y: 45)
    );

implementation

{$R *.fmx}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FIndex := 0;
  Randomize;
  ForceDirectories(ExtractFilePath(DB_PATH));

  FDB            := TDatabase.Create(DB_PATH);
  FBoardManager  := TBoardManager.Create(ilBoards, FDB);
  FPlayerManager := TPlayerManager.Create(ilAvatars);
  FDemoCell      := 0;
  FTotalPlayers  := 4;

  FNextPlayerID := 2; // El Host siempre es 1, el primer invitado será el 2.

  FGameEngine := TGameEngine.Create(FTotalPlayers);
  FGameEngine.OnDiceRolled  := GE_OnDiceRolled;
  FGameEngine.OnPlayerMoved := GE_OnPlayerMoved;
  FGameEngine.OnTurnChanged := GE_OnTurnChanged;
  FGameEngine.OnGameOver    := GE_OnGameOver;
  FGameEngine.OnRuleTriggered := GE_OnRuleTriggered;

  // Limpieza inicial
  imgAvatar1.Visible := False;
  imgAvatar2.Visible := False;
  imgAvatar3.Visible := False;
  imgAvatar4.Visible := False;

  lblTurno.Text := 'Selecciona un tablero para iniciar';
  lblDado.Text  := 'Dado: —';
  if Assigned(lblCasilla) then lblCasilla.Text := '';

  btnTirarDado.Enabled := False;

  FTmrWalk := TTimer.Create(Self);
  FTmrWalk.Interval := 250;
  FTmrWalk.Enabled := False;
  FTmrWalk.OnTimer := tmrWalkTimer;

  FNetworkManager := TNetworkManager.Create;
  FNetworkManager.OnMessageReceived := Net_OnMessageReceived;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FNetworkManager.Free;
  FGameEngine.Free;
  FBoardManager.Free;
  FPlayerManager.Free;
  FDB.Free;
end;

procedure TfrmMain.imgBoardResize(Sender: TObject);
begin
  if Assigned(FBoardManager) then
  begin
    if FBoardManager.ActiveBoardHasCoords then
      ResetAvatarsToStart;
  end;
end;

procedure TfrmMain.imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  FLastX := X;
  FLastY := Y;
  lblCoords.Text := Format('X: %.1f | Y: %.1f', [X, Y]);
end;

procedure TfrmMain.imgBoardDblClick(Sender: TObject);
begin
  if not FBoardManager.IsCapturing then Exit;

  FBoardManager.RecordCell(FLastX, FLastY);
  lblCoords.Text := Format('Capturando: %d/%d  →  X:%.1f Y:%.1f', [FBoardManager.CaptureProgress, MAX_CELLS, FLastX, FLastY]);

  if FBoardManager.CaptureProgress >= MAX_CELLS then
  begin
    FBoardManager.FinishCapture;
    ShowMessage('¡Coordenadas guardadas correctamente!');
    ResetAvatarsToStart;
  end;
end;

procedure TfrmMain.btnCapturarClick(Sender: TObject);
begin
  if FBoardManager.ActiveBoardIdx = BLANK_IDX then
  begin
    ShowMessage('Selecciona un tablero primero');
    Exit;
  end;
  FBoardManager.StartCapture(
    FBoardManager.ActiveBoardIdx,
    imgBoard.Width,
    imgBoard.Height
  );

  imgAvatar1.Visible := False;
  imgAvatar2.Visible := False;
  imgAvatar3.Visible := False;
  imgAvatar4.Visible := False;

  lblCoords.Text := Format('Modo captura — Tablero %d: doble click en casilla 1/%d', [FBoardManager.ActiveBoardIdx, MAX_CELLS]);
end;

procedure TfrmMain.btnRulesClick(Sender: TObject);
begin
  if not Assigned(frmRules) then
    frmRules := TfrmRules.Create(Application);

  frmRules.CargarReglas(FBoardManager.ActiveBoardIdx);
  frmRules.Show;
end;

procedure TfrmMain.btnStartGameClick(Sender: TObject);
var
  frmLobby: TfrmLobby;
  frmBoard: TfrmBoardSelect;
  arrInput: TArray<string>;
  numPlayers, i: Integer;
begin
  frmLobby := TfrmLobby.Create(Application);
  try
    if frmLobby.ShowModal = mrOk then
    begin
      FPlayerName := frmLobby.PlayerName;

      if frmLobby.IsHost then
      begin
        // ════════════════ FLUJO DEL HOST ════════════════
        FNetworkManager.StartAsHost(7777);
        FLocalPlayerID := 1;
        FMyClientToken := 'HOST';

        frmBoard := TfrmBoardSelect.CreateWithImages(Application, ilBoards);
        try
          if frmBoard.ShowModal = mrOk then
          begin
            FBoardManager.LoadBoardIntoImage(frmBoard.SelectedIdx, imgBoard);
            FBoardManager.SetActiveBoard(frmBoard.SelectedIdx);
            FGameEngine.BoardIndex := frmBoard.SelectedIdx;
          end else Exit;
        finally
          frmBoard.Free;
        end;

        SetLength(arrInput, 1); arrInput[0] := '2';
        if not TDialogServiceSync.InputQuery('Host', ['Jugadores totales (2-4):'], arrInput) then Exit;
        numPlayers := StrToIntDef(arrInput[0], 0);

        FTotalPlayers := numPlayers;
        FGameEngine.TotalPlayers := numPlayers;

        FPlayerManager.ResetTakenAvatars;
        FPlayerManager.MarkAvatarTaken(BLANK_IDX);
        for i := 1 to 4 do
        begin
           GetAvatarImage(i).Visible := False;
           FPlayerManager.LoadAvatarIntoImage(1, GetAvatarImage(i));
        end;

        SeleccionarAvatar(1, FPlayerName);

        ResetAvatarsToStart;
        FGameEngine.StartGame;
        btnTirarDado.Enabled := True;

        ShowMessage('¡Servidor Abierto! Tu IP es: ' + FNetworkManager.GetLocalIP);
      end
      else
      begin
        // ════════════════ FLUJO DEL CLIENTE ════════════════
        FLocalPlayerID := 0; // Desconocido. El host lo asignará.
        FMyClientToken := IntToStr(Random(9999999)); // Etiqueta de seguridad

        lblTurno.Text := 'Conectando a ' + frmLobby.HostIP + '...';

        FNetworkManager.ConnectToHost(frmLobby.HostIP, 7777);

        // Pedimos al host que nos asigne un asiento enviando nuestro token
        var json := TJSONObject.Create;
        json.AddPair('token', FMyClientToken);
        json.AddPair('name', FPlayerName);
        FNetworkManager.SendCommand('JOIN_REQUEST', json);
      end;
    end;
  finally
    frmLobby.Free;
  end;
end;

function TfrmMain.GetAvatarImage(PlayerID: Integer): TImage;
begin
  case PlayerID of
    1: Result := imgAvatar1;
    2: Result := imgAvatar2;
    3: Result := imgAvatar3;
    4: Result := imgAvatar4;
  else
    Result := imgAvatar1;
  end;
end;

procedure TfrmMain.MoveAvatarToCell(PlayerID, CellIdx: Integer);
var
  pt  : TPointF;
  img : TImage;
begin
  pt  := FBoardManager.GetCellPosition(CellIdx, imgBoard.Width, imgBoard.Height);
  img := GetAvatarImage(PlayerID);

  img.Position.X := pt.X;
  img.Position.Y := pt.Y;

  img.Opacity := 1.0;
  img.Scale.X := 1.0;
  img.Scale.Y := 1.0;
  img.RotationAngle := 0;

  img.Visible    := True;
  img.BringToFront;
end;

procedure TfrmMain.ResetAvatarsToStart;
var
  basePos : TPointF;
  avatars : array[0..3] of TImage;
  i       : Integer;
begin
  for i := 1 to 4 do FVisualPositions[i] := 0;

  avatars[0] := imgAvatar1;
  avatars[1] := imgAvatar2;
  avatars[2] := imgAvatar3;
  avatars[3] := imgAvatar4;

  if not FBoardManager.ActiveBoardHasCoords then
  begin
    for i := 0 to 3 do avatars[i].Visible := False;
    Exit;
  end;

  // Restaurar el Pozo
  if Assigned(imgWell)
  then imgWell.Visible := True;

  basePos := FBoardManager.GetCellPosition(0, imgBoard.Width, imgBoard.Height);

  for i := 0 to 3 do
  begin
    if i < FTotalPlayers then
    begin
      avatars[i].Position.X := basePos.X + AVATAR_START_OFFSET[i].X;
      avatars[i].Position.Y := basePos.Y + AVATAR_START_OFFSET[i].Y;
      avatars[i].Visible    := True;
    end
    else
      avatars[i].Visible := False;
  end;
end;

function TfrmMain.SeleccionarAvatar(PlayerID: Integer; const NombreJugador: string): Boolean;
var
  frm : TfrmAvatarSelect;
  idx : Integer;
  imgDestino : TImage;
begin
  Result := False;
  frm := TfrmAvatarSelect.CreateForPlayer(
            Application, ilAvatars,
            FPlayerManager.GetTakenArray,
            NombreJugador);
  try
    if frm.ShowModal = mrOk then
    begin
      idx := frm.SelectedIdx;

      if idx > 0 then
      begin
        FPlayerManager.MarkAvatarTaken(idx);

        imgDestino := GetAvatarImage(PlayerID);
        FPlayerManager.LoadAvatarIntoImage(idx, imgDestino);

        imgDestino.Tag := idx;
        imgDestino.Visible := True;

        FGameEngine.PlayerAvatars[PlayerID] := idx;

        if Assigned(FNetworkManager) then
        begin
          var json := TJSONObject.Create;
          json.AddPair('player', TJSONNumber.Create(PlayerID));
          json.AddPair('avatar', TJSONNumber.Create(idx));
          FNetworkManager.SendCommand('SYNC_AVATAR', json);
        end;

        Result := True;
      end
      else
      begin
        ShowMessage('El avatar en blanco no es seleccionable.');
      end;
    end;
  finally
    frm.Free;
  end;
end;

procedure TfrmMain.btnTirarDadoClick(Sender: TObject);
var json: TJSONObject;
begin
  if not FGameEngine.GameActive then Exit;

  btnTirarDado.Enabled := False;

  if FNetworkManager.IsHost then
  begin
    json := TJSONObject.Create;
    json.AddPair('player', TJSONNumber.Create(FGameEngine.GetCurrentPlayer));
    json.AddPair('dice', TJSONNumber.Create(Random(6) + 1));
    FNetworkManager.SendCommand('SYNC_ROLL', json);
  end
  else
  begin
    FNetworkManager.SendCommand('ROLL_REQUEST');
  end;
end;

procedure TfrmMain.tmrWalkTimer(Sender: TObject);
var
  step: Integer;
  pt: TPointF;
begin
  if FVisualPositions[FWalkingPlayer] = FWalkTargetCell then
  begin
    FTmrWalk.Enabled := False;

    if Assigned(lblCasilla)
    then lblCasilla.Text := Format('J%d cayó en C%d', [FWalkingPlayer, FWalkTargetCell + 1]);

    if FPendingRuleType <> '' then
    begin
      EjecutarAnimacionRegla(FWalkingPlayer, FPendingRuleType, FPendingRuleMessage);
      FPendingRuleType := '';
    end;

    if FSecondaryTargetCell <> -1 then
      begin
        FWalkTargetCell := FSecondaryTargetCell;
        FSecondaryTargetCell := -1;

        TThread.CreateAnonymousThread(procedure
          begin
            Sleep(1200);
            TThread.Synchronize(TThread(nil), procedure
              begin
                FTmrWalk.Enabled := True;
              end);
          end).Start;
      end
    else
      begin
          // ¡NUEVO! Limpiamos el objetivo para el siguiente turno
          FWalkTargetCell := -1;

          if FGameEngine.GameActive and (FGameEngine.GetCurrentPlayer = FLocalPlayerID)
          then btnTirarDado.Enabled := True;
      end;

    Exit;
  end;

  if FVisualPositions[FWalkingPlayer] < FWalkTargetCell then
    step := 1
  else
    step := -1;

  FVisualPositions[FWalkingPlayer] := FVisualPositions[FWalkingPlayer] + step;
  pt := FBoardManager.GetCellPosition(FVisualPositions[FWalkingPlayer], imgBoard.Width, imgBoard.Height);

  TAnimator.AnimateFloat(GetAvatarImage(FWalkingPlayer), 'Position.X', pt.X, 0.2);
  TAnimator.AnimateFloat(GetAvatarImage(FWalkingPlayer), 'Position.Y', pt.Y, 0.2);
end;

procedure TfrmMain.EjecutarAnimacionRegla(PlayerID: Integer; const RuleType, Message: string);
var
  imgPlayer: TImage;
begin
  imgPlayer := GetAvatarImage(PlayerID);
  imgPlayer.BringToFront;

  if Assigned(rctnglSpecialEvent) and Assigned(lblEventoEspecial) then
  begin
    lblEventoEspecial.Text := Message;
    rctnglSpecialEvent.Opacity := 1.0;
    rctnglSpecialEvent.Visible := True;
    rctnglSpecialEvent.BringToFront;

    TAnimator.AnimateFloat(rctnglSpecialEvent, 'Opacity', 0.0, 4.0);
  end;

  if RuleType = 'WELL' then
  begin
    if Assigned(imgWell) then
    begin
      var ptAbs, ptLoc: TPointF;
      ptAbs := imgWell.LocalToAbsolute(TPointF.Create(imgWell.Width / 2, imgWell.Height / 2));
      ptLoc := (imgPlayer.Parent as TControl).AbsoluteToLocal(ptAbs);

      TAnimator.AnimateFloat(imgPlayer, 'Position.X', ptLoc.X - (imgPlayer.Width / 2), 1.0);
      TAnimator.AnimateFloat(imgPlayer, 'Position.Y', ptLoc.Y - (imgPlayer.Height / 2), 1.0);

      TAnimator.AnimateFloat(imgPlayer, 'RotationAngle', 1080, 2.0);
      TAnimator.AnimateFloat(imgPlayer, 'Scale.X', 0.1, 2.0);
      TAnimator.AnimateFloat(imgPlayer, 'Scale.Y', 0.1, 2.0);
      TAnimator.AnimateFloat(imgPlayer, 'Opacity', 0.0, 2.0);
    end;
  end
  else if RuleType = 'DEATH' then
  begin
    TAnimator.AnimateFloat(imgPlayer, 'Position.X', imgPlayer.Position.X + 15, 0.05);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Position.X', imgPlayer.Position.X - 30, 0.05, 0.05);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Position.X', imgPlayer.Position.X + 15, 0.05, 0.1);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Position.Y', imgPlayer.Position.Y + 800, 1.0, 0.3);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Opacity', 0.0, 0.5, 0.3);
    FVisualPositions[PlayerID] := 0;
  end
  else if RuleType = 'GOOSE' then
  begin
    TAnimator.AnimateFloat(imgPlayer, 'Scale.X', 1.8, 0.3);
    TAnimator.AnimateFloat(imgPlayer, 'Scale.Y', 1.8, 0.3);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Scale.X', 1.0, 0.3, 0.4);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Scale.Y', 1.0, 0.3, 0.4);
  end
  else if RuleType = 'MAZE' then
  begin
    TAnimator.AnimateFloat(imgPlayer, 'RotationAngle', 1080, 1.5);
    TAnimator.AnimateFloat(imgPlayer, 'Opacity', 0.2, 0.2);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Opacity', 1.0, 0.2, 0.2);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Opacity', 0.2, 0.2, 0.4);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Opacity', 1.0, 0.2, 0.6);
  end
  else if RuleType = 'BOUNCE' then
  begin
    TAnimator.AnimateFloat(imgPlayer, 'Position.X', imgPlayer.Position.X + 20, 0.05);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Position.X', imgPlayer.Position.X - 20, 0.05, 0.05);
    TAnimator.AnimateFloat(imgPlayer, 'Opacity', 0.5, 0.2);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Opacity', 1.0, 0.2, 0.2);
  end
  else if (RuleType = 'GOOSE') or (RuleType = 'BRIDGE') or (RuleType = 'DICE') then
  begin
    TAnimator.AnimateFloat(imgPlayer, 'Scale.X', 1.8, 0.3);
    TAnimator.AnimateFloat(imgPlayer, 'Scale.Y', 1.8, 0.3);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Scale.X', 1.0, 0.3, 0.4);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Scale.Y', 1.0, 0.3, 0.4);
  end
  else if (RuleType = 'INN') or (RuleType = 'PRISON') then
  begin
    TAnimator.AnimateFloat(imgPlayer, 'RotationAngle', 15, 0.1);
    TAnimator.AnimateFloatDelay(imgPlayer, 'RotationAngle', -15, 0.1, 0.1);
    TAnimator.AnimateFloatDelay(imgPlayer, 'RotationAngle', 15, 0.1, 0.2);
    TAnimator.AnimateFloatDelay(imgPlayer, 'RotationAngle', 0, 0.1, 0.3);
    TAnimator.AnimateFloat(imgPlayer, 'Opacity', 0.6, 0.5);
  end;
end;

// 1. EL NUEVO MÉTODO QUE ESCUCHA CUANDO EL DADO SE CIERRA
procedure TfrmMain.OnDiceFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree; // Libera la memoria del dado
  FDiceIsRolling := False;

  // ¡El dado ya desapareció! Si el pato estaba esperando para moverse, lo soltamos:
  if (FWalkingPlayer > 0) and (FWalkTargetCell <> -1) then
    FTmrWalk.Enabled := True;
end;

// 2. ACTUALIZAR EL TIRADO DE DADO
procedure TfrmMain.GE_OnDiceRolled(PlayerID, DiceValue: Integer);
var
  frmDice: TfrmDice;
begin
  FDiceIsRolling := True; // Levantamos la bandera: ¡Nadie camina!
  frmDice := TfrmDice.CreateWithResult(Application, ilDiceFaces, DiceValue);
  frmDice.OnClose := OnDiceFormClose; // Conectamos la oreja al evento de cierre
  frmDice.Show;
  lblDado.Text := Format('J%d tiró: %d', [PlayerID, DiceValue]);
end;

// 3. ACTUALIZAR EL MOVIMIENTO DEL JUGADOR
procedure TfrmMain.GE_OnPlayerMoved(PlayerID, NewCellIdx: Integer);
var
  img: TImage;
begin
  img := GetAvatarImage(PlayerID);
  img.Opacity := 1.0;
  img.Scale.X := 1.0;
  img.Scale.Y := 1.0;
  img.RotationAngle := 0;
  img.Visible := True;
  img.BringToFront;

  // Si ya había un destino programado, lo mandamos a la cola secundaria
  if FWalkTargetCell <> -1 then
  begin
    FSecondaryTargetCell := NewCellIdx;
  end
  else
  begin
    // Es el primer movimiento del turno
    FWalkingPlayer := PlayerID;
    FWalkTargetCell := NewCellIdx;
    FSecondaryTargetCell := -1;

    // ¡SOLO EMPEZAMOS A CAMINAR SI EL DADO YA NO ESTÁ GIRANDO!
    if not FDiceIsRolling then
      FTmrWalk.Enabled := True;
  end;
end;

procedure TfrmMain.GE_OnRuleTriggered(PlayerID: Integer; const RuleType, Message: string);
begin
  FPendingRulePlayer := PlayerID;
  FPendingRuleType := RuleType;
  FPendingRuleMessage := Message;
end;

procedure TfrmMain.GE_OnTurnChanged(NewPlayerID: Integer);
begin
  lblTurno.Text := Format('Turno: Jugador %d', [NewPlayerID]);

  if NewPlayerID = FLocalPlayerID then
  begin
    rctnglSidebar.Fill.Color := TAlphaColorRec.Limegreen;
    lblTurno.Text := '¡ES TU TURNO!';
    if not FTmrWalk.Enabled and FGameEngine.GameActive then
      btnTirarDado.Enabled := True;
  end
  else
  begin
    rctnglSidebar.Fill.Color := TAlphaColorRec.Indianred;
    btnTirarDado.Enabled := False;
  end;
end;

procedure TfrmMain.GE_OnGameOver(WinnerID: Integer);
begin
  lblTurno.Text := Format('🏆 ¡Jugador %d ganó!', [WinnerID]);
  lblDado.Text  := '— Partida terminada —';

  TThread.CreateAnonymousThread(procedure
    begin
      Sleep(2000);
      TThread.Synchronize(TThread(nil), procedure
        begin
          ShowMessage(Format('¡Felicidades! ¡El Jugador %d ganó la partida!', [WinnerID]));
        end);
    end).Start;
end;

procedure TfrmMain.Net_OnMessageReceived(const Command: string; JSONData: TJSONObject);
var
  i, pos: Integer;
  json: TJSONObject;
  pt: TPointF;
  img: TImage;
begin
  if Command = 'JOIN_REQUEST' then
  begin
    // El host procesa a los nuevos invitados y les asigna asiento
    if FNetworkManager.IsHost then
    begin
      if FNextPlayerID <= FTotalPlayers then
      begin
        json := TJSONObject.Create;
        json.AddPair('assigned_id', TJSONNumber.Create(FNextPlayerID));
        json.AddPair('token', JSONData.GetValue<string>('token')); // Rebotar el token de seguridad
        FNetworkManager.SendCommand('JOIN_ACCEPTED', json);
        Inc(FNextPlayerID);
      end;
    end;
  end
  else if Command = 'JOIN_ACCEPTED' then
  begin
    // El cliente verifica si ese asiento es para él usando su token único
    if (not FNetworkManager.IsHost) and (FLocalPlayerID = 0) then
    begin
      if JSONData.GetValue<string>('token') = FMyClientToken then
      begin
        FLocalPlayerID := JSONData.GetValue<Integer>('assigned_id');
        lblTurno.Text := 'Esperando sincronización...';

        // Ya tengo mi ID, ahora pido ver el tablero de los demás
        FNetworkManager.SendCommand('SYNC_ALL_REQUEST');
      end;
    end;
  end
  else if Command = 'STATE' then
  begin
    if Assigned(JSONData) then
    begin
      FGameEngine.ImportStateFromJSON(JSONData.ToJSON);

      if FBoardManager.ActiveBoardIdx <> FGameEngine.BoardIndex then
      begin
        FBoardManager.LoadBoardIntoImage(FGameEngine.BoardIndex, imgBoard);
        FBoardManager.SetActiveBoard(FGameEngine.BoardIndex);
      end;

      for i := 1 to 4 do
      begin
        var avIdx := FGameEngine.PlayerAvatars[i];
        if avIdx > 0 then
        begin
          FPlayerManager.MarkAvatarTaken(avIdx);
          FPlayerManager.LoadAvatarIntoImage(avIdx, GetAvatarImage(i));
          GetAvatarImage(i).Tag := avIdx;
          GetAvatarImage(i).Visible := True;
        end;
      end;

      for i := 1 to FGameEngine.TotalPlayers do
      begin
        pos := FGameEngine.GetPlayerPosition(i);
        pt := FBoardManager.GetCellPosition(pos, imgBoard.Width, imgBoard.Height);
        img := GetAvatarImage(i);

        img.Opacity := 1.0;
        img.Scale.X := 1.0;
        img.Scale.Y := 1.0;

        if pos = 0 then
        begin
           img.Position.X := pt.X + AVATAR_START_OFFSET[i-1].X;
           img.Position.Y := pt.Y + AVATAR_START_OFFSET[i-1].Y;
        end
        else
        begin
           img.Position.X := pt.X;
           img.Position.Y := pt.Y;
        end;
        img.Visible := True;
        img.BringToFront;
      end;

      // Si soy el cliente nuevo y acabo de cargar el tablero ajeno, ¡es hora de elegir mi Pato!
      if (not FNetworkManager.IsHost) and (FLocalPlayerID > 0) and (FGameEngine.PlayerAvatars[FLocalPlayerID] = 0) then
      begin
         SeleccionarAvatar(FLocalPlayerID, FPlayerName);
      end;

      if not FGameEngine.GameActive then
        FGameEngine.StartGame;
    end;
  end
  else if Command = 'SYNC_ROLL' then
  begin
    if Assigned(JSONData) then
    begin
      var pID := JSONData.GetValue<Integer>('player');
      var dVal := JSONData.GetValue<Integer>('dice');
      FGameEngine.TryRollDice(pID, dVal);
    end;
  end
  else if (Command = 'ROLL_REQUEST') and FNetworkManager.IsHost then
  begin
    json := TJSONObject.Create;
    json.AddPair('player', TJSONNumber.Create(FGameEngine.GetCurrentPlayer));
    json.AddPair('dice', TJSONNumber.Create(Random(6) + 1));
    FNetworkManager.SendCommand('SYNC_ROLL', json);
  end
  else if Command = 'SYNC_AVATAR' then
  begin
    if Assigned(JSONData) then
    begin
      var pID := JSONData.GetValue<Integer>('player');
      var avIdx := JSONData.GetValue<Integer>('avatar');

      FGameEngine.PlayerAvatars[pID] := avIdx;
      FPlayerManager.MarkAvatarTaken(avIdx);
      FPlayerManager.LoadAvatarIntoImage(avIdx, GetAvatarImage(pID));

      GetAvatarImage(pID).Tag := avIdx;
      GetAvatarImage(pID).Visible := True;

      // NOTA: Hemos eliminado el "BroadcastState" aquí porque arruinaba la carrera visual.
      // SendCommand ya se encarga de repartir este SYNC_AVATAR a todos.
    end;
  end
  else if (Command = 'SYNC_ALL_REQUEST') and FNetworkManager.IsHost then
  begin
    FNetworkManager.BroadcastState(FGameEngine.ExportStateToJSON);
  end;
end;

end.
