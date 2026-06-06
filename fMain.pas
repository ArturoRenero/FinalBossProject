unit fMain;

interface

uses
  // ¡Asegúrate de que System.IOUtils esté aquí para que no marque error en 'Combine'!
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects, FMX.Layouts,
  System.ImageList, FMX.ImgList, System.JSON, FMX.Ani, FMX.DialogService,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteWrapper.Stat, System.StrUtils, // ¡Obligatorio para usar IndexStr
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
  fLobbyForm,
  uNetworkManager,
  uBluetoothManager,
  fAdminLogin,
  uSaveManager,
  uBotAI, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo;

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

    // Botones de Fase 8 y 9
    btnGuardar: TButton;
    btnCargar: TButton;
    btnReiniciar: TButton;
    btnPausar: TButton;
    btnReanudar: TButton; // <-- ¡Tu nuevo botón agregado!
    btnMenuPrincipal: TButton;
    btnRellenarBots: TButton;

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
    procedure imgBoardResize(Sender: TObject);
    procedure btnStartGameClick(Sender: TObject);
    procedure btnRulesClick(Sender: TObject);

    // Eventos Fase 8 y 9
    procedure btnGuardarClick(Sender: TObject);
    procedure btnCargarClick(Sender: TObject);
    procedure btnReiniciarClick(Sender: TObject);
    procedure btnPausarClick(Sender: TObject);
    procedure btnReanudarClick(Sender: TObject); // <-- ¡Evento para reanudar!
    procedure btnMenuPrincipalClick(Sender: TObject);
    procedure btnRellenarBotsClick(Sender: TObject);

  private
    FIndex: Integer;
    FLastX  : Single;
    FLastY  : Single;
    FDemoCell    : Integer;
    FTotalPlayers : Integer;

    FUseBluetooth: Boolean;
    FNetworkManager: TNetworkManager;
    FBluetoothManager: TBluetoothNetworkManager;

    FLocalPlayerID: Integer;
    FNextPlayerID: Integer;
    FMyClientToken: string;
    FPlayerName: string;

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
    FPartidaPausada: Boolean;
    FAplicandoEstadoRemoto: Boolean;
    FRollIDsProcesados: TStringList;

    FBots: array[1..4] of TBotAI; // Memoria para los bots

    function JuegoOcupado: Boolean;
    function AvatarCellOffset(PlayerID, CellIdx: Integer): TPointF;
    function NuevoRollID: string;
    function RollIDYaProcesado(const RollID: string): Boolean;
    procedure RegistrarRollID(const RollID: string);
    procedure Bot_OnRollRequested(PlayerID: Integer);
    procedure EnviarTiradaAutorizada(PlayerID: Integer);

    function NetIsHost: Boolean;
    procedure NetSendCommand(const Command: string; JSONData: TJSONObject = nil);
    procedure NetBroadcastState(const StateJSON: string);

    procedure ResetAvatarsToStart;
    function  GetAvatarImage(PlayerID: Integer): TImage;
    procedure MoveAvatarToCell(PlayerID, CellIdx: Integer);

    procedure RestaurarVisualesDesdeMotor;

    procedure SeleccionarAvatar(PlayerID: Integer; const NombreJugador: string; OnComplete: TProc<Boolean>);

    procedure GE_OnDiceRolled(PlayerID, DiceValue: Integer);
    procedure GE_OnPlayerMoved(PlayerID, NewCellIdx: Integer);
    procedure GE_OnTurnChanged(NewPlayerID: Integer);
    procedure GE_OnGameOver(WinnerID: Integer);
    procedure GE_OnRuleTriggered(PlayerID: Integer; const RuleType, Message: string);

    procedure tmrWalkTimer(Sender: TObject);
    procedure EjecutarAnimacionRegla(PlayerID: Integer; const RuleType, Message: string);
    procedure Net_OnMessageReceived(const Command: string; JSONData: TJSONObject);
    procedure OnDiceFormClose(Sender: TObject; var Action: TCloseAction);

    function GetBTManager: TBluetoothNetworkManager;

    procedure ComprobarTurnoActual;
    procedure RellenarConBots;
  end;

var
  frmMain: TfrmMain;

const
  AVATAR_SIZE = 64; // <-- Cambia este único número para probar nuevas medidas

  AVATAR_START_OFFSET : array[0..3] of TPointF = (
      (X:  0;  Y:  0), (X: 45;  Y:  0),
      (X:  0;  Y: 45), (X: 45;  Y: 45)
    );

implementation

{$R *.fmx}

procedure TfrmMain.FormCreate(Sender: TObject);
var
  RutaDB: string;
begin
  try
    FIndex := 0; Randomize;
    FPartidaPausada := False;
    FAplicandoEstadoRemoto := False;
    FRollIDsProcesados := TStringList.Create;
    FRollIDsProcesados.Sorted := True;
    FRollIDsProcesados.Duplicates := dupIgnore;

    RutaDB := GetDBPath;
    ForceDirectories(ExtractFilePath(RutaDB));
    FDB := TDatabase.Create(RutaDB);

    FBoardManager  := TBoardManager.Create(ilBoards, FDB);
    FPlayerManager := TPlayerManager.Create(ilAvatars);

    FDemoCell := 0; FTotalPlayers := 4; FNextPlayerID := 2;

    FGameEngine := TGameEngine.Create(FTotalPlayers);
    FGameEngine.OnDiceRolled  := GE_OnDiceRolled;
    FGameEngine.OnPlayerMoved := GE_OnPlayerMoved;
    FGameEngine.OnTurnChanged := GE_OnTurnChanged;
    FGameEngine.OnGameOver    := GE_OnGameOver;
    FGameEngine.OnRuleTriggered := GE_OnRuleTriggered;

    imgAvatar1.Visible := False; imgAvatar2.Visible := False;
    imgAvatar3.Visible := False; imgAvatar4.Visible := False;

    imgAvatar1.Parent := imgBoard; imgAvatar2.Parent := imgBoard;
    imgAvatar3.Parent := imgBoard; imgAvatar4.Parent := imgBoard;
    if Assigned(imgWell) then imgWell.Parent := imgBoard;

    lblTurno.Text := 'Selecciona un tablero para iniciar';
    lblDado.Text  := 'Dado: —';
    if Assigned(lblCasilla) then lblCasilla.Text := '';

    btnTirarDado.Enabled := False;
    FWalkTargetCell := -1; FSecondaryTargetCell := -1; FWalkingPlayer := 0;

    FTmrWalk := TTimer.Create(Self);
    FTmrWalk.Interval := 250;
    FTmrWalk.Enabled := False;
    FTmrWalk.OnTimer := tmrWalkTimer;

    FNetworkManager := TNetworkManager.Create;
    FNetworkManager.OnMessageReceived := Net_OnMessageReceived;

    // Configuración inicial de los botones de Pausa
    if Assigned(btnPausar) then btnPausar.Visible := True;
    if Assigned(btnReanudar) then btnReanudar.Visible := False;

    // --- CONTINUAR PARTIDA AUTOMÁTICA ---
    if TSaveManager.HayPartidaGuardada(FDB) then
    begin
      TDialogService.MessageDialog('Se encontró una partida guardada. ¿Deseas continuarla?',
        System.UITypes.TMsgDlgType.mtConfirmation,
        [System.UITypes.TMsgDlgBtn.mbYes, System.UITypes.TMsgDlgBtn.mbNo],
        System.UITypes.TMsgDlgBtn.mbYes, 0,
        procedure(const AResult: TModalResult)
        begin
          if AResult = mrYes then
          begin
            if TSaveManager.CargarPartida(FGameEngine, FDB) then
            begin
              FTotalPlayers := FGameEngine.TotalPlayers;
              FLocalPlayerID := 1;
              RestaurarVisualesDesdeMotor;
              ComprobarTurnoActual;
              ShowMessage('Partida recuperada exitosamente.');
            end;
          end
          else
            TSaveManager.BorrarPartida(FDB);
        end);
    end;

  except
    on E: Exception do ShowMessage('Error fatal al iniciar: ' + E.Message);
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
var i: Integer;
begin
  for i := 1 to 4 do
    if Assigned(FBots[i]) then FreeAndNil(FBots[i]); // Limpieza segura de bots
  FRollIDsProcesados.Free;
  FNetworkManager.Free;
  FBluetoothManager.Free;
  FGameEngine.Free;
  FBoardManager.Free;
  FPlayerManager.Free;
  FDB.Free;
end;

function TfrmMain.NetIsHost: Boolean;
begin
  if FUseBluetooth
  then Result := GetBTManager.IsHost
  else Result := FNetworkManager.IsHost;
end;

procedure TfrmMain.NetSendCommand(const Command: string; JSONData: TJSONObject);
begin
  if FUseBluetooth
  then GetBTManager.SendCommand(Command, JSONData)
  else FNetworkManager.SendCommand(Command, JSONData);
end;

procedure TfrmMain.NetBroadcastState(const StateJSON: string);
begin
  if FUseBluetooth
  then GetBTManager.BroadcastState(StateJSON)
  else FNetworkManager.BroadcastState(StateJSON);
end;

function TfrmMain.JuegoOcupado: Boolean;
begin
  // El juego está ocupado si el dado se está mostrando o si una ficha sigue caminando.
  // Este candado bloquea botones y peticiones, pero no bloquea el SYNC_ROLL autorizado.
  Result := FDiceIsRolling or FTmrWalk.Enabled or (FWalkTargetCell <> -1);
end;

function TfrmMain.AvatarCellOffset(PlayerID, CellIdx: Integer): TPointF;
var
  i, jugadoresEnCasilla: Integer;
begin
  Result := TPointF.Create(0, 0);

  // En la salida ya usamos una separación especial más grande.
  if CellIdx = 0 then
  begin
    if (PlayerID >= 1) and (PlayerID <= 4) then
      Result := AVATAR_START_OFFSET[PlayerID - 1];
    Exit;
  end;

  jugadoresEnCasilla := 0;
  for i := 1 to FGameEngine.TotalPlayers do
    if FGameEngine.GetPlayerPosition(i) = CellIdx then
      Inc(jugadoresEnCasilla);

  // Si solo hay una ficha en la casilla, no la movemos de su centro normal.
  if jugadoresEnCasilla <= 1 then Exit;

  case PlayerID of
    1: Result := TPointF.Create(-10, -10);
    2: Result := TPointF.Create( 10, -10);
    3: Result := TPointF.Create(-10,  10);
    4: Result := TPointF.Create( 10,  10);
  end;
end;

function TfrmMain.NuevoRollID: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := GUIDToString(G);
end;

function TfrmMain.RollIDYaProcesado(const RollID: string): Boolean;
begin
  Result := (RollID <> '') and Assigned(FRollIDsProcesados) and
            (FRollIDsProcesados.IndexOf(RollID) >= 0);
end;

procedure TfrmMain.RegistrarRollID(const RollID: string);
begin
  if (RollID = '') or not Assigned(FRollIDsProcesados) then Exit;

  FRollIDsProcesados.Add(RollID);

  // Evitamos que la lista crezca sin límite durante partidas largas.
  while FRollIDsProcesados.Count > 80 do
    FRollIDsProcesados.Delete(0);
end;

procedure TfrmMain.EnviarTiradaAutorizada(PlayerID: Integer);
var
  json: TJSONObject;
begin
  if not NetIsHost then Exit;
  if not FGameEngine.GameActive then Exit;
  if FPartidaPausada then Exit;
  if JuegoOcupado then Exit;
  if FGameEngine.GetCurrentPlayer <> PlayerID then Exit;

  json := TJSONObject.Create;
  try
    json.AddPair('player', TJSONNumber.Create(PlayerID));
    json.AddPair('dice', TJSONNumber.Create(Random(6) + 1));
    json.AddPair('roll_id', NuevoRollID);
    NetSendCommand('SYNC_ROLL', json);
  finally
    json.Free;
  end;
end;

procedure TfrmMain.Bot_OnRollRequested(PlayerID: Integer);
begin
  // El bot no mueve el motor directamente. Solo pide al Host una tirada autorizada.
  // Así LAN y Bluetooth reciben el mismo SYNC_ROLL que un jugador humano.
  EnviarTiradaAutorizada(PlayerID);
end;

// ════════════════════════════════════════════════════════════════
// FASE 8 Y 9: SISTEMA DE GUARDADO, CARGA, PAUSA Y REINICIO
// ════════════════════════════════════════════════════════════════
procedure TfrmMain.btnGuardarClick(Sender: TObject);
begin
  if not FGameEngine.GameActive then
  begin
    ShowMessage('Inicia una partida primero para poder guardarla.');
    Exit;
  end;

  if not NetIsHost then
  begin
    ShowMessage('Solo el Anfitrión (Host) puede guardar la partida en el servidor.');
    Exit;
  end;

  TSaveManager.GuardarPartida(FGameEngine, FDB);
  ShowMessage('¡Partida guardada exitosamente en la base de datos!');
end;

procedure TfrmMain.btnCargarClick(Sender: TObject);
begin
  if not NetIsHost then
  begin
    ShowMessage('Solo el Anfitrión (Host) puede cargar una partida.');
    Exit;
  end;

  if TSaveManager.HayPartidaGuardada(FDB) then
  begin
    if TSaveManager.CargarPartida(FGameEngine, FDB) then
    begin
      FTotalPlayers := FGameEngine.TotalPlayers;
      RestaurarVisualesDesdeMotor;
      NetBroadcastState(FGameEngine.ExportStateToJSON);
      ShowMessage('¡Partida cargada y sincronizada con todos los jugadores!');
    end;
  end
  else
    ShowMessage('No se encontró ninguna partida guardada en la base de datos.');
end;

procedure TfrmMain.btnReiniciarClick(Sender: TObject);
begin
  // El reinicio debe permitirse aunque la partida ya haya terminado.
  // Por eso NO debemos poner: if not FGameEngine.GameActive then Exit;

  if not NetIsHost then
  begin
    ShowMessage('Solo el Anfitrión (Host) puede reiniciar la partida.');
    Exit;
  end;

  // Detener cualquier animación o movimiento pendiente.
  FDiceIsRolling := False;
  FWalkTargetCell := -1;
  FSecondaryTargetCell := -1;
  FWalkingPlayer := 0;

  if Assigned(FTmrWalk) then
    FTmrWalk.Enabled := False;

  // Limpiar IDs de tiradas procesadas para que la nueva partida empiece limpia.
  if Assigned(FRollIDsProcesados) then
    FRollIDsProcesados.Clear;

  // Quitar pausa si estaba pausada.
  FPartidaPausada := False;

  // Ocultar mensaje grande de victoria o evento especial.
  if Assigned(rctnglSpecialEvent) then
    rctnglSpecialEvent.Visible := False;

  if Assigned(lblEventoEspecial) then
    lblEventoEspecial.Text := '';

  // Borrar partida guardada.
  TSaveManager.BorrarPartida(FDB);

  // Reiniciar el motor del juego.
  FGameEngine.ResetGame;

  // Restaurar fichas y textos visuales.
  RestaurarVisualesDesdeMotor;
  ComprobarTurnoActual;

  // Sincronizar con los clientes LAN/Bluetooth.
  if NetIsHost then
    NetBroadcastState(FGameEngine.ExportStateToJSON);

  ShowMessage('La partida ha sido reiniciada.');
end;


// ════════ EVENTOS DE PAUSA (AHORA SINCRONIZADOS POR RED) ════════
procedure TfrmMain.btnPausarClick(Sender: TObject);
begin
  if not FGameEngine.GameActive then Exit;
  if not NetIsHost then
  begin
    ShowMessage('Solo el Anfitrión puede pausar la partida.');
    Exit;
  end;

  FGameEngine.Status := gsPaused;
  NetBroadcastState(FGameEngine.ExportStateToJSON); // ¡Avisa a los clientes!
  RestaurarVisualesDesdeMotor;
end;

procedure TfrmMain.btnReanudarClick(Sender: TObject);
begin
  if not FGameEngine.GameActive then Exit;
  if not NetIsHost then Exit;

  FGameEngine.Status := gsPlaying;
  NetBroadcastState(FGameEngine.ExportStateToJSON); // ¡Avisa a los clientes!
  RestaurarVisualesDesdeMotor;
end;

procedure TfrmMain.btnMenuPrincipalClick(Sender: TObject);
begin
  // 1. Limpiar red
  if FUseBluetooth then GetBTManager.Disconnect else FNetworkManager.Disconnect;
  FLocalPlayerID := 0; FUseBluetooth := False;

  // 2. Limpiar motor
  FGameEngine.ResetGame;
  FPlayerManager.ResetTakenAvatars;

  // 3. Limpiar visuales
  imgAvatar1.Visible := False; imgAvatar2.Visible := False;
  imgAvatar3.Visible := False; imgAvatar4.Visible := False;
  if Assigned(imgWell) then imgWell.Visible := False;

  FBoardManager.SetActiveBoard(BLANK_IDX);
  imgBoard.Bitmap := nil;

  btnTirarDado.Enabled := False;
  FPartidaPausada := False;

  // Reiniciar botones de pausa a su estado por defecto
  if Assigned(btnPausar) then btnPausar.Visible := True;
  if Assigned(btnReanudar) then btnReanudar.Visible := False;

  lblTurno.Text := 'Selecciona un tablero para iniciar';
  lblDado.Text  := 'Dado: —';
  if Assigned(lblCasilla) then lblCasilla.Text := '';

  ShowMessage('Has regresado al Menú Principal.');
end;

// ════════════════════════════════════════════════════════════════
// REFACTOR: MÉTODO CENTRAL DE DIBUJADO DE TABLERO
// ════════════════════════════════════════════════════════════════
procedure TfrmMain.RestaurarVisualesDesdeMotor;
var
  i, pos: Integer;
  pt: TPointF;
  img: TImage;
begin
  if FBoardManager.ActiveBoardIdx <> FGameEngine.BoardIndex then
  begin
    FBoardManager.LoadBoardIntoImage(FGameEngine.BoardIndex, imgBoard);
    FBoardManager.SetActiveBoard(FGameEngine.BoardIndex);
  end;

  if Assigned(imgWell) then imgWell.Visible := True;

  FPlayerManager.ResetTakenAvatars;
  FPlayerManager.MarkAvatarTaken(BLANK_IDX);

  for i := 1 to 4 do
  begin
    var avIdx := FGameEngine.PlayerAvatars[i];
    img := GetAvatarImage(i);

    if avIdx > 0 then
    begin
      FPlayerManager.MarkAvatarTaken(avIdx);
      FPlayerManager.LoadAvatarIntoImage(avIdx, img);
      img.Tag := avIdx;
      img.Width := AVATAR_SIZE;
      img.Height := AVATAR_SIZE;
      img.Visible := True;
    end
    else
      img.Visible := False;
  end;

  for i := 1 to FGameEngine.TotalPlayers do
  begin
    pos := FGameEngine.GetPlayerPosition(i);
    pt := FBoardManager.GetCellPosition(pos, imgBoard.Width, imgBoard.Height);
    img := GetAvatarImage(i);

    img.Opacity := 1.0;
    img.Scale.X := 1.0;
    img.Scale.Y := 1.0;
    img.RotationAngle := 0;

    var offset := AvatarCellOffset(i, pos);
    img.Position.X := pt.X + offset.X;
    img.Position.Y := pt.Y + offset.Y;

    img.Visible := True;
    img.BringToFront;

    // Mantiene el rastreador de animaciones sincronizado con el motor.
    FVisualPositions[i] := pos;
  end;

  if FGameEngine.Status = gsPaused then
  begin
    if Assigned(btnPausar) then btnPausar.Visible := False;
    if Assigned(btnReanudar) then btnReanudar.Visible := True;
    btnTirarDado.Enabled := False;
    lblTurno.Text := '-PARTIDA PAUSADA-';
  end
  else
  begin
    if Assigned(btnReanudar) then btnReanudar.Visible := False;
    if Assigned(btnPausar) then btnPausar.Visible := True;
    GE_OnTurnChanged(FGameEngine.GetCurrentPlayer);
  end;
end; // RestaurarVisualesDesdeMotor()

// ════════════════════════════════════════════════════════════════

procedure TfrmMain.imgBoardResize(Sender: TObject);
begin
  if not Assigned(FBoardManager) then Exit;
  if not FBoardManager.ActiveBoardHasCoords then Exit;

  // ── ¡EL ESCUDO ANTI-BUGS! ──
  // Si el dado está girando o un pato está caminando,
  // bloqueamos cualquier intromisión visual de FMX.
  if FDiceIsRolling or FTmrWalk.Enabled then Exit;

  // Evitamos fallos matemáticos si la ventana se minimiza (Width = 0)
  if imgBoard.Width > 50 then
    RestaurarVisualesDesdeMotor;
end;

procedure TfrmMain.imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  FLastX := X; FLastY := Y;
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

    // Sincronización de coordenadas por red.
    if NetIsHost
    then
      begin
        var jsonCoords := TJSONObject.Create;
        var arr := TJSONArray.Create;
        var cells := FDB.LoadBoardCoords(FBoardManager.ActiveBoardIdx);
        var pt: TPointF;

        jsonCoords.AddPair('boardIdx', TJSONNumber.Create(FBoardManager.ActiveBoardIdx));

        for pt in cells do
          begin
            var obj := TJSONObject.Create;
            obj.AddPair('x', TJSONNumber.Create(pt.X));
            obj.AddPair('y', TJSONNumber.Create(pt.Y));
            arr.Add(obj);
          end;

        jsonCoords.AddPair('coords', arr);
        // Las coordenadas no son un estado de partida. Se mandan con su propio comando.
        NetSendCommand('SYNC_COORDS', jsonCoords);
        jsonCoords.Free;
      end;
    // Fin de sincronización de coordenadas.

    // HOT-RELOADING: Restaura el juego en caliente localmente
    if FGameEngine.GameActive
    then RestaurarVisualesDesdeMotor
    else ResetAvatarsToStart;
  end;
end; // imgBoardDblClick()

procedure TfrmMain.btnCapturarClick(Sender: TObject);
var
  frmAdmin: TfrmAdminLogin;
  frmBoard: TfrmBoardSelect;
begin
  frmAdmin := TfrmAdminLogin.Create(Application);
  try
    if frmAdmin.ShowModal = mrOk then
    begin
      frmBoard := TfrmBoardSelect.CreateWithImages(Application, ilBoards);
      try
        if frmBoard.ShowModal = mrOk then
        begin
          FBoardManager.LoadBoardIntoImage(frmBoard.SelectedIdx, imgBoard);
          FBoardManager.SetActiveBoard(frmBoard.SelectedIdx);

          FBoardManager.StartCapture(
            FBoardManager.ActiveBoardIdx,
            imgBoard.Width,
            imgBoard.Height
          );

          imgAvatar1.Visible := False; imgAvatar2.Visible := False;
          imgAvatar3.Visible := False; imgAvatar4.Visible := False;
          if Assigned(imgWell) then imgWell.Visible := False;

          lblCoords.Text := Format('Modo Administrador — Tablero %d: doble click en casilla 1/%d', [FBoardManager.ActiveBoardIdx, MAX_CELLS]);
        end;
      finally
        frmBoard.Free;
      end;
    end;
  finally
    frmAdmin.Free;
  end;
end;

procedure TfrmMain.btnRulesClick(Sender: TObject);
begin
  if not Assigned(frmRules) then frmRules := TfrmRules.Create(Application);
  frmRules.CargarReglas(FBoardManager.ActiveBoardIdx);
  frmRules.Show;
end;

procedure TfrmMain.btnStartGameClick(Sender: TObject);
var
  frmLobby: TfrmLobby;
  frmBoard: TfrmBoardSelect;
  numPlayers, i: Integer;
  json: TJSONObject;
begin
  frmLobby := TfrmLobby.Create(Application);

  {$IF DEFINED(MSWINDOWS)}
  try
    if frmLobby.ShowModal = mrOk then
    begin
      FPlayerName := frmLobby.PlayerName;
      FUseBluetooth := frmLobby.UseBluetooth;

      if frmLobby.IsHost then
      begin
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

        numPlayers := frmLobby.SelectedNumber;
        FTotalPlayers := numPlayers;
        FGameEngine.TotalPlayers := numPlayers;

        FPlayerManager.ResetTakenAvatars;
        FPlayerManager.MarkAvatarTaken(BLANK_IDX);
        for i := 1 to 4 do
        begin
           GetAvatarImage(i).Visible := False;
           FPlayerManager.LoadAvatarIntoImage(1, GetAvatarImage(i));
        end;

        SeleccionarAvatar(1, FPlayerName, nil);

        if FUseBluetooth then GetBTManager.StartAsHost
        else FNetworkManager.StartAsHost(7777);

        FLocalPlayerID := 1;
        FMyClientToken := 'HOST';

        ResetAvatarsToStart;
        FGameEngine.StartGame;
        ComprobarTurnoActual;

        if FUseBluetooth then ShowMessage('¡Servidor Bluetooth Abierto!')
        else ShowMessage('¡Servidor Abierto! Tu IP es: ' + FNetworkManager.GetLocalIP);
      end
      else
      begin
        FLocalPlayerID := 0;
        FMyClientToken := IntToStr(Random(9999999));

        if FUseBluetooth then
        begin
          lblTurno.Text := 'Conectando por Bluetooth a ' + frmLobby.BluetoothDeviceName + '...';
          // Se usa TThread(nil) para evitar el error "no overloaded version of Queue"
          TThread.CreateAnonymousThread(procedure
          begin
            try
              GetBTManager.ConnectToDevice(frmLobby.BluetoothDeviceName);
              TThread.Queue(TThread(nil), procedure
              begin
                json := TJSONObject.Create;
                json.AddPair('token', FMyClientToken);
                json.AddPair('name', FPlayerName);
                NetSendCommand('JOIN_REQUEST', json);
                json.Free;
              end);
            except
              TThread.Queue(TThread(nil), procedure begin ShowMessage('Error de conexión Bluetooth.'); end);
            end;
          end).Start;
        end
        else
        begin
          lblTurno.Text := 'Conectando a ' + frmLobby.HostIP + '...';
          TThread.CreateAnonymousThread(procedure
          begin
            try
              FNetworkManager.ConnectToHost(frmLobby.HostIP, 7777);
              TThread.Queue(TThread(nil), procedure
              begin
                json := TJSONObject.Create;
                json.AddPair('token', FMyClientToken);
                json.AddPair('name', FPlayerName);
                NetSendCommand('JOIN_REQUEST', json);
                json.Free;
              end);
            except
              TThread.Queue(TThread(nil), procedure begin ShowMessage('Error de conexión LAN.'); end);
            end;
          end).Start;
        end;
      end;
    end;
  finally
    frmLobby.Free;
  end;
  {$ELSE}
  frmLobby.ShowModal(
    procedure(LobbyResult: TModalResult)
    begin
      if LobbyResult = mrOk then
      begin
        FPlayerName := frmLobby.PlayerName;
        FUseBluetooth := frmLobby.UseBluetooth;

        if frmLobby.IsHost then
        begin
          frmBoard := TfrmBoardSelect.CreateWithImages(Application, ilBoards);
          frmBoard.ShowModal(
            procedure(BoardResult: TModalResult)
            begin
              if BoardResult = mrOk then
              begin
                FBoardManager.LoadBoardIntoImage(frmBoard.SelectedIdx, imgBoard);
                FBoardManager.SetActiveBoard(frmBoard.SelectedIdx);
                FGameEngine.BoardIndex := frmBoard.SelectedIdx;

                numPlayers := frmLobby.SelectedNumber;
                FTotalPlayers := numPlayers;
                FGameEngine.TotalPlayers := numPlayers;

                FPlayerManager.ResetTakenAvatars;
                FPlayerManager.MarkAvatarTaken(BLANK_IDX);
                for i := 1 to 4 do
                begin
                   GetAvatarImage(i).Visible := False;
                   FPlayerManager.LoadAvatarIntoImage(1, GetAvatarImage(i));
                end;

                SeleccionarAvatar(1, FPlayerName, procedure(Success: Boolean)
                begin
                  if Success then
                  begin
                    if FUseBluetooth then GetBTManager.StartAsHost
                    else FNetworkManager.StartAsHost(7777);

                    FLocalPlayerID := 1;
                    FMyClientToken := 'HOST';

                    ResetAvatarsToStart;
                    FGameEngine.StartGame;
                    ComprobarTurnoActual;

                    if FUseBluetooth then ShowMessage('¡Servidor Bluetooth Abierto!')
                    else ShowMessage('¡Servidor Abierto! Tu IP es: ' + FNetworkManager.GetLocalIP);
                  end;
                end);
              end;
              frmBoard.DisposeOf;
            end
          );
        end
        else
        begin
          FLocalPlayerID := 0;
          FMyClientToken := IntToStr(Random(9999999));

          if FUseBluetooth then
          begin
            lblTurno.Text := 'Conectando por Bluetooth a ' + frmLobby.BluetoothDeviceName + '...';
            TThread.CreateAnonymousThread(procedure
            begin
              try
                GetBTManager.ConnectToDevice(frmLobby.BluetoothDeviceName);
                TThread.Queue(TThread(nil), procedure
                begin
                  json := TJSONObject.Create;
                  json.AddPair('token', FMyClientToken);
                  json.AddPair('name', FPlayerName);
                  NetSendCommand('JOIN_REQUEST', json);
                  json.Free;
                end);
              except
              end;
            end).Start;
          end
          else
          begin
            lblTurno.Text := 'Conectando a ' + frmLobby.HostIP + '...';
            TThread.CreateAnonymousThread(procedure
            begin
              try
                FNetworkManager.ConnectToHost(frmLobby.HostIP, 7777);
                TThread.Queue(TThread(nil), procedure
                begin
                  json := TJSONObject.Create;
                  json.AddPair('token', FMyClientToken);
                  json.AddPair('name', FPlayerName);
                  NetSendCommand('JOIN_REQUEST', json);
                  json.Free;
                end);
              except
              end;
            end).Start;
          end;
        end;
      end;
      frmLobby.DisposeOf;
    end
  );
  {$ENDIF}
end;

function TfrmMain.GetAvatarImage(PlayerID: Integer): TImage;
begin
  case PlayerID of
    1: Result := imgAvatar1; 2: Result := imgAvatar2;
    3: Result := imgAvatar3; 4: Result := imgAvatar4;
  else Result := imgAvatar1;
  end;
end;

procedure TfrmMain.MoveAvatarToCell(PlayerID, CellIdx: Integer);
var
  pt, offset: TPointF;
  img: TImage;
begin
  pt  := FBoardManager.GetCellPosition(CellIdx, imgBoard.Width, imgBoard.Height);
  offset := AvatarCellOffset(PlayerID, CellIdx);
  img := GetAvatarImage(PlayerID);

  img.Position.X := pt.X + offset.X;
  img.Position.Y := pt.Y + offset.Y;
  img.Opacity := 1.0; img.Scale.X := 1.0; img.Scale.Y := 1.0;
  img.RotationAngle := 0; img.Visible := True; img.BringToFront;
end;

procedure TfrmMain.ResetAvatarsToStart;
var
  basePos : TPointF;
  avatars : array[0..3] of TImage;
  i       : Integer;
begin
  for i := 1 to 4 do FVisualPositions[i] := 0;

  avatars[0] := imgAvatar1; avatars[1] := imgAvatar2;
  avatars[2] := imgAvatar3; avatars[3] := imgAvatar4;

  if not FBoardManager.ActiveBoardHasCoords then
  begin
    for i := 0 to 3 do avatars[i].Visible := False;
    Exit;
  end;

  if Assigned(imgWell) then imgWell.Visible := True;

  basePos := FBoardManager.GetCellPosition(0, imgBoard.Width, imgBoard.Height);

  for i := 0 to 3 do
  begin
    if i < FTotalPlayers then
    begin
      avatars[i].Position.X := basePos.X + AVATAR_START_OFFSET[i].X;
      avatars[i].Position.Y := basePos.Y + AVATAR_START_OFFSET[i].Y;
      avatars[i].Visible    := True;
    end
    else avatars[i].Visible := False;
  end;
end;

procedure TfrmMain.SeleccionarAvatar(PlayerID: Integer; const NombreJugador: string; OnComplete: TProc<Boolean>);
var
  frm : TfrmAvatarSelect;
  idx : Integer;
  imgDestino : TImage;
  json: TJSONObject;
begin
  frm := TfrmAvatarSelect.CreateForPlayer(Application, ilAvatars, FPlayerManager.GetTakenArray, NombreJugador);

  {$IF DEFINED(MSWINDOWS)}
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
        imgDestino.Width := AVATAR_SIZE;
        imgDestino.Height := AVATAR_SIZE;
        imgDestino.Visible := True;

        FGameEngine.PlayerAvatars[PlayerID] := idx;

        json := TJSONObject.Create;
        json.AddPair('player', TJSONNumber.Create(PlayerID));
        json.AddPair('avatar', TJSONNumber.Create(idx));
        NetSendCommand('SYNC_AVATAR', json);
        json.Free;

        if Assigned(OnComplete) then OnComplete(True);
      end
      else
      begin
        ShowMessage('El avatar en blanco no es seleccionable.');
        if Assigned(OnComplete) then OnComplete(False);
      end;
    end
    else
      if Assigned(OnComplete) then OnComplete(False);
  finally
    frm.Free;
  end;
  {$ELSE}
  frm.ShowModal(
    procedure(ModalResult: TModalResult)
    begin
      if ModalResult = mrOk then
      begin
        idx := frm.SelectedIdx;
        if idx > 0 then
        begin
          FPlayerManager.MarkAvatarTaken(idx);
          imgDestino := GetAvatarImage(PlayerID);
          FPlayerManager.LoadAvatarIntoImage(idx, imgDestino);
          imgDestino.Tag := idx;
          imgDestino.Width := AVATAR_SIZE;
          imgDestino.Height := AVATAR_SIZE;
          imgDestino.Visible := True;

          FGameEngine.PlayerAvatars[PlayerID] := idx;

          json := TJSONObject.Create;
          json.AddPair('player', TJSONNumber.Create(PlayerID));
          json.AddPair('avatar', TJSONNumber.Create(idx));
          NetSendCommand('SYNC_AVATAR', json);
          json.Free;

          if Assigned(OnComplete) then OnComplete(True);
        end
        else
        begin
          ShowMessage('El avatar en blanco no es seleccionable.');
          if Assigned(OnComplete) then OnComplete(False);
        end;
      end
      else
        if Assigned(OnComplete) then OnComplete(False);
      frm.DisposeOf;
    end
  );
  {$ENDIF}
end;

procedure TfrmMain.btnTirarDadoClick(Sender: TObject);
var
  json: TJSONObject;
begin
  if not FGameEngine.GameActive then Exit;
  if FPartidaPausada then Exit;
  if JuegoOcupado then Exit;
  if FGameEngine.GetCurrentPlayer <> FLocalPlayerID then Exit;

  btnTirarDado.Enabled := False;

  if NetIsHost then
  begin
    EnviarTiradaAutorizada(FLocalPlayerID);
  end
  else
  begin
    // El cliente solo solicita tirar. El Host valida si realmente es su turno.
    json := TJSONObject.Create;
    try
      json.AddPair('player', TJSONNumber.Create(FLocalPlayerID));
      NetSendCommand('ROLL_REQUEST', json);
    finally
      json.Free;
    end;
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

    if Assigned(lblCasilla) then
    begin
      if FWalkTargetCell = 0 then
        lblCasilla.Text := Format('J%d está en el Inicio', [FWalkingPlayer])
      else
        lblCasilla.Text := Format('J%d cayó en C%d', [FWalkingPlayer, FWalkTargetCell]);
    end;

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
            TThread.Queue(TThread(nil), procedure
              begin
                FTmrWalk.Enabled := True;
              end);
          end).Start;
      end
    else
      begin
          FWalkTargetCell := -1;
          ComprobarTurnoActual;
      end;
    Exit;
  end;

  if FVisualPositions[FWalkingPlayer] < FWalkTargetCell then step := 1 else step := -1;

  FVisualPositions[FWalkingPlayer] := FVisualPositions[FWalkingPlayer] + step;
  pt := FBoardManager.GetCellPosition(FVisualPositions[FWalkingPlayer], imgBoard.Width, imgBoard.Height);
  var offset := AvatarCellOffset(FWalkingPlayer, FVisualPositions[FWalkingPlayer]);
  pt.X := pt.X + offset.X;
  pt.Y := pt.Y + offset.Y;

  var img := GetAvatarImage(FWalkingPlayer);

  // Detiene animaciones anteriores para evitar saltos hacia la esquina del tablero.
  TAnimator.StopPropertyAnimation(img, 'Position.X');
  TAnimator.StopPropertyAnimation(img, 'Position.Y');

  TAnimator.AnimateFloat(img, 'Position.X', pt.X, 0.2);
  TAnimator.AnimateFloat(img, 'Position.Y', pt.Y, 0.2);
end; // tmrWalkTimer()

procedure TfrmMain.EjecutarAnimacionRegla(PlayerID: Integer; const RuleType, Message: string);
var imgPlayer: TImage; ptAbs, ptLoc: TPointF;
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

procedure TfrmMain.OnDiceFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree;
  FDiceIsRolling := False;
  if (FWalkingPlayer > 0) and (FWalkTargetCell <> -1) then FTmrWalk.Enabled := True;
end;

procedure TfrmMain.GE_OnDiceRolled(PlayerID, DiceValue: Integer);
var frmDice: TfrmDice;
begin
  FDiceIsRolling := True;
  frmDice := TfrmDice.CreateWithResult(Application, ilDiceFaces, DiceValue);
  frmDice.OnClose := OnDiceFormClose;
  frmDice.Show;
  lblDado.Text := Format('J%d tiró: %d', [PlayerID, DiceValue]);
//  mmo1.Lines.Add( // TODO: Remover este bloque
//    Format(
//      'Turn=%d Dice=%d',
//      [PlayerID, DiceValue]
//      )
//  );
end;

procedure TfrmMain.GE_OnPlayerMoved(PlayerID, NewCellIdx: Integer);
var img: TImage;
begin
  img := GetAvatarImage(PlayerID);
  img.Opacity := 1.0; img.Scale.X := 1.0; img.Scale.Y := 1.0;
  img.RotationAngle := 0; img.Visible := True; img.BringToFront;

  if FWalkTargetCell <> -1
  then FSecondaryTargetCell := NewCellIdx
  else
  begin
    FWalkingPlayer := PlayerID;
    FWalkTargetCell := NewCellIdx;
    FSecondaryTargetCell := -1;
    if not FDiceIsRolling
    then FTmrWalk.Enabled := True;
  end;
end;

procedure TfrmMain.GE_OnRuleTriggered(PlayerID: Integer; const RuleType, Message: string);
begin
  FPendingRulePlayer := PlayerID;
  FPendingRuleType := RuleType;
  FPendingRuleMessage := Message;
//  mmo1.Lines.Add( // TODO: Remover este bloque
//    Format(
//      'PlayerID=%d RuleType=%s Message=%s',
//      [PlayerID, string(RuleType), Message]
//    )
//  );
end;

procedure TfrmMain.GE_OnTurnChanged(NewPlayerID: Integer);
begin
  lblTurno.Text := Format('Turno: Jugador %d', [NewPlayerID]);
  if FPartidaPausada then Exit;

  if NewPlayerID = FLocalPlayerID then
  begin
    rctnglSidebar.Fill.Color := TAlphaColorRec.Limegreen;
    lblTurno.Text := '¡ES TU TURNO!';
  end
  else
  begin
    rctnglSidebar.Fill.Color := TAlphaColorRec.Indianred;
    btnTirarDado.Enabled := False;

    // Si le toca a un Bot, mostramos este texto especial:
    if NetIsHost and Assigned(FBots[NewPlayerID]) then
      lblTurno.Text := Format('El Bot %d está pensando...', [NewPlayerID]);
  end;

  // Solo revisamos el turno cuando no se está aplicando un estado remoto ni hay animaciones activas.
  if (not FAplicandoEstadoRemoto) and (not JuegoOcupado)
  then ComprobarTurnoActual;
end;

procedure TfrmMain.GE_OnGameOver(WinnerID: Integer);
begin
  lblTurno.Text := Format('GANADOR: JUGADOR %d', [WinnerID]);
  lblDado.Text  := 'Partida terminada';
  btnTirarDado.Enabled := False;

  // Aviso grande dentro del tablero para que no se pierda durante la presentación.
  if Assigned(rctnglSpecialEvent) and Assigned(lblEventoEspecial) then
  begin
    lblEventoEspecial.Text := Format('JUGADOR %d GANO LA PARTIDA', [WinnerID]);
    lblEventoEspecial.Font.Size := 22;
    lblEventoEspecial.TextSettings.FontColor := TAlphaColorRec.Black;
    rctnglSpecialEvent.Fill.Color := TAlphaColorRec.Gold;
    rctnglSpecialEvent.Opacity := 1.0;
    rctnglSpecialEvent.Visible := True;
    rctnglSpecialEvent.BringToFront;
    lblEventoEspecial.BringToFront;
  end;

  ShowMessage(Format('Felicidades. El Jugador %d gano la partida.', [WinnerID]));
end;

procedure TfrmMain.Net_OnMessageReceived(const Command: string; JSONData: TJSONObject);
var
  json : TJSONObject;
  i : Integer;
begin
  // IndexStr devuelve 0 para el primer string, 1 para el segundo, etc.
  // Devuelve -1 si el comando no existe en la lista.
  case IndexStr(Command, [
    'JOIN_REQUEST',      // 0
    'JOIN_ACCEPTED',     // 1
    'STATE',             // 2
    'SYNC_ROLL',         // 3
    'ROLL_REQUEST',      // 4
    'SYNC_AVATAR',       // 5
    'SYNC_ALL_REQUEST',  // 6
    'SYNC_COORDS'        // 7
  ]) of

    0: // ── JOIN_REQUEST ──
      begin
        if NetIsHost and (FNextPlayerID <= FTotalPlayers) then
        begin
          json := TJSONObject.Create;
          json.AddPair('assigned_id', TJSONNumber.Create(FNextPlayerID));
          json.AddPair('token', JSONData.GetValue<string>('token'));
          NetSendCommand('JOIN_ACCEPTED', json);
          json.Free;
          Inc(FNextPlayerID);
        end;
      end;

    1: // ── JOIN_ACCEPTED ──
      begin
        if (not NetIsHost) and (FLocalPlayerID = 0) then
        begin
          if JSONData.GetValue<string>('token') = FMyClientToken then
          begin
            FLocalPlayerID := JSONData.GetValue<Integer>('assigned_id');
            lblTurno.Text := 'Esperando sincronización...';
            NetSendCommand('SYNC_ALL_REQUEST');
          end;
        end;
      end;

    2: // ── STATE ──
      begin
        if Assigned(JSONData) then
        begin
          // STATE solo corrige datos. No debe disparar animaciones mientras llega por red.
          FAplicandoEstadoRemoto := True;
          FGameEngine.OnPlayerMoved := nil;
          FGameEngine.OnTurnChanged := nil;
          try
            FGameEngine.ImportStateFromJSON(JSONData.ToJSON);

            RestaurarVisualesDesdeMotor;
            ComprobarTurnoActual;

          finally
            FGameEngine.OnPlayerMoved := GE_OnPlayerMoved;
            FGameEngine.OnTurnChanged := GE_OnTurnChanged;
            FAplicandoEstadoRemoto := False;
          end;

          // Si el tablero está quieto, sí podemos redibujar todo.
          // Si está animando, no tocamos posiciones visuales para evitar saltos o regresos al inicio.
          if not JuegoOcupado then
            RestaurarVisualesDesdeMotor
          else
            GE_OnTurnChanged(FGameEngine.GetCurrentPlayer);

          if (not NetIsHost) and (FLocalPlayerID > 0) and (FGameEngine.PlayerAvatars[FLocalPlayerID] = 0) then
          begin
             SeleccionarAvatar(FLocalPlayerID, FPlayerName, nil);
          end;
        end;
      end;

    3: // SYNC_ROLL
      begin
        if Assigned(JSONData) then
        begin
          var RollPlayer := JSONData.GetValue<Integer>('player');
          var RollDice   := JSONData.GetValue<Integer>('dice');

          FGameEngine.TryRollDice(RollPlayer, RollDice);
        end;
      end;

    4: // ── ROLL_REQUEST ──
      begin
        if NetIsHost then
        begin
          var requestedPlayer := FGameEngine.GetCurrentPlayer;

          if Assigned(JSONData) then
            JSONData.TryGetValue<Integer>('player', requestedPlayer);

          // El Host valida el turno. Esto evita tiros atrasados o doble clics por red.
          EnviarTiradaAutorizada(requestedPlayer);
        end;
      end;

    5: // ── SYNC_AVATAR ──
      begin
        if Assigned(JSONData) then
        begin
          var pID := JSONData.GetValue<Integer>('player');
          var avIdx := JSONData.GetValue<Integer>('avatar');
          var img := GetAvatarImage(pID); // Cacheamos el avatar

          FGameEngine.PlayerAvatars[pID] := avIdx;
          FPlayerManager.MarkAvatarTaken(avIdx);
          FPlayerManager.LoadAvatarIntoImage(avIdx, img);

          // OPTIMIZACIÓN: Usamos 'with' para escribir directo en sus propiedades
          with img do
          begin
            Tag := avIdx;
            Width := AVATAR_SIZE;
            Height := AVATAR_SIZE;
            Visible := True;
          end;
        end;
      end;

    6: // ── SYNC_ALL_REQUEST ──
      begin
        if NetIsHost then
          NetBroadcastState(FGameEngine.ExportStateToJSON);
      end;

    7: // ── SYNC_COORDS ──
      begin
        if Assigned(JSONData) then
        begin
          var bIdx := JSONData.GetValue<Integer>('boardIdx');
          var arr := JSONData.GetValue('coords') as TJSONArray;
          var cells: TBoardCells;
          SetLength(cells, arr.Count);

          for i := 0 to arr.Count - 1 do
          begin
            var obj := arr.Items[i] as TJSONObject;
            cells[i] := TPointF.Create(
              (obj.GetValue('x') as TJSONNumber).AsDouble,
              (obj.GetValue('y') as TJSONNumber).AsDouble
            );
          end;

          FDB.SaveBoardCoords(bIdx, cells);
          FBoardManager.SetActiveBoard(bIdx);

          if FGameEngine.GameActive then
            RestaurarVisualesDesdeMotor;
        end;
      end;

  else
    // Opcional: Aquí puedes poner código si recibes un comando desconocido
     ShowMessage('Comando de red desconocido: ' + Command);
  end;
end; // Net_OnMessageReceived()

function TfrmMain.GetBTManager: TBluetoothNetworkManager;
begin
  if not Assigned(FBluetoothManager) then
  begin
    FBluetoothManager := TBluetoothNetworkManager.Create;
    FBluetoothManager.OnMessageReceived := Net_OnMessageReceived;
  end;
  Result := FBluetoothManager;
end;

// ════════════════════════════════════════════════════════════════
// FASE 6: INTELIGENCIA ARTIFICIAL (BOTS)
// ════════════════════════════════════════════════════════════════
procedure TfrmMain.ComprobarTurnoActual;
begin
//  mmo1.Lines.Add( // TODO: remover este bloque
//    Format(
//      'ComprobarTurnoActual -> Turno=%d Local=%d',
//      [FGameEngine.GetCurrentPlayer, FLocalPlayerID]
//    )
//  );
  if not FGameEngine.GameActive then Exit;
  if FPartidaPausada then Exit;
  if FAplicandoEstadoRemoto then Exit;
  if JuegoOcupado then Exit;

  if FGameEngine.GetCurrentPlayer = FLocalPlayerID then
  begin
    btnTirarDado.Enabled := True;
  end
  else if NetIsHost and Assigned(FBots[FGameEngine.GetCurrentPlayer]) then
  begin
    // Si es turno de un bot, solo el Host lo despierta.
    // El bot pedirá una tirada autorizada; no moverá el motor directamente.
    btnTirarDado.Enabled := False;
    FBots[FGameEngine.GetCurrentPlayer].JugarTurno;
  end;
end;

procedure TfrmMain.RellenarConBots;
var
  i, avIdx: Integer;
  json: TJSONObject;
begin
  if not NetIsHost then Exit;

  for i := 1 to FTotalPlayers do
  begin
    // Solo rellenamos asientos que el Host no ha asignado a un jugador humano.
    // Esto evita reemplazar clientes que ya entraron pero todavía no eligen avatar.
    if (i <> FLocalPlayerID) and (i >= FNextPlayerID) and (FGameEngine.PlayerAvatars[i] = 0) then
    begin
      if not Assigned(FBots[i]) then
      begin
        FBots[i] := TBotAI.Create(i, FGameEngine);
        FBots[i].OnRollRequested := Bot_OnRollRequested;
      end;

      // El bot elige avatar en secreto
      FBots[i].AsignarAvatarAleatorio;
      avIdx := FGameEngine.PlayerAvatars[i];

      // Lo mostramos en la interfaz local
      FPlayerManager.MarkAvatarTaken(avIdx);
      FPlayerManager.LoadAvatarIntoImage(avIdx, GetAvatarImage(i));
      GetAvatarImage(i).Tag := avIdx;
      GetAvatarImage(i).Width := AVATAR_SIZE;
      GetAvatarImage(i).Height := AVATAR_SIZE;
      GetAvatarImage(i).Visible := True;

      // Avisamos a la red (teléfonos Android) que un Bot entró a la partida
      json := TJSONObject.Create;
      json.AddPair('player', TJSONNumber.Create(i));
      json.AddPair('avatar', TJSONNumber.Create(avIdx));
      NetSendCommand('SYNC_AVATAR', json);
      json.Free;
    end;
  end;

  ComprobarTurnoActual; // Si el turno 1 resultó ser de un Bot recién creado, arranca.
  ShowMessage('Slots vacíos rellenados con Bots.');
end; // RellenarConBots()

// Evento para el botón que agregarás en la interfaz
procedure TfrmMain.btnRellenarBotsClick(Sender: TObject);
begin
  RellenarConBots;
end;

end.
