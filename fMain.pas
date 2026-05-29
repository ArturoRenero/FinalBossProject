unit fMain;

// Principio de separación de responsabilidades (SoC): Cada módulo tiene una
// única responsabilidad. La UI solo dibuja y captura input; el GE solo ejecuta
// la lógica; el Data Layer solo persiste. Esto permite testear cada capa de
// forma independiente y escalar la conectividad de red sin reescribir la lógica del juego.

// ¿Por qué separar tantos módulos? Si el GE y la UI están en el mismo form,
// no puedes testear la lógica de turnos sin abrir la interfaz gráfica.
// Tampoco puedes reusar el GE para el modo en red sin duplicar código.
// Con esta arquitectura: la UI puede ser reemplazada (FMX → VCL) sin tocar el GE;
// el GE puede correrse en un servidor headless; la capa Network puede agregarse
// sin modificar ninguna línea del GE o la UI; la capa Data puede migrar de
// SQLite a cualquier otra base de datos modificando solo uDatabase.

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils,                           // ← TPath.Combine, GetDocumentsPath
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects, FMX.Layouts,
  System.ImageList, FMX.ImgList,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FMX.DialogService.Sync,
  uTypes,           // ← MAX_CELLS, BLANK_IDX, TBoardCells, TAllBoardCoords
  uDatabase,        // ← TDatabase
  uBoardManager,
  uPlayerManager,
  fAvatarSelectForm,
  uConfig,
  uTurnManager,
  uGameEngine,
  fBoardSelectForm,
  fDiceForm,
  fRulesForm,
  FMX.Ani;

type
  TfrmMain = class(TForm)
    // ── Componentes del diseñador (published) ─────────────────────
    ilBoards: TImageList;
    lytBoard: TLayout;
    imgBoard: TImage;
    stat1: TStatusBar;
    lblCoords: TLabel;
    ilAvatars: TImageList;
    imgAvatar1: TImage;
    imgAvatar2: TImage;
    imgAvatar3: TImage;
    imgAvatar4: TImage;
    btnTirarDado: TButton;
    btnCapturar: TButton;
    lytButtons: TLayout;
    rctngl1: TRectangle;
    lblTurno: TLabel;
    lblDado: TLabel;
    btnStartGame: TButton;
    ilDiceFaces: TImageList;
    lblEventoEspecial: TLabel;
    rctnglSpecialEvent: TRectangle;
    imgWell: TImage;
    btnRules: TButton;
//    FTmrWalk: TTimer; // Declarado en private
    // ── Event handlers ────────────────────────────────────────────
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
    { Private declarations }
    // ── Campos de estado ──────────────────────────────────────────
    FIndex: Integer; // <-- Declarada aquí para que persista. La 'F' es convención de Delphi para 'Fields' (Campos).
    FLastX  : Single;   // ← última posición X del mouse sobre el tablero
    FLastY  : Single;   // ← última posición Y del mouse sobre el tablero
//    FCurrentCell : Integer;  // ← índice de la casilla que se está definiendo
    FDemoCell    : Integer;   // casilla actual de la demo
    FTotalPlayers : Integer;
    // ── Managers ──────────────────────────────────────────────────
    FDB          : TDatabase; // referencia a la base de datos
    FBoardManager  : TBoardManager;
    FPlayerManager : TPlayerManager;
    FGameEngine    : TGameEngine;

    // Variables para la animación paso a paso
    FWalkingPlayer: Integer;
    FWalkTargetCell: Integer;
    FSecondaryTargetCell: Integer; // Guarda el salto de la Oca/Laberinto
    FVisualPositions: array[1..4] of Integer; // Dónde está visualmente el pato
    FTmrWalk: TTimer;

    // Variables para "pausar" la regla hasta que termine de caminar
    FPendingRuleType: string;
    FPendingRuleMessage: string;
    FPendingRulePlayer: Integer;

    // ── Métodos privados ──────────────────────────────────────────
    procedure ResetAvatarsToStart;
    function  GetAvatarImage(PlayerID: Integer): TImage;
    procedure MoveAvatarToCell(PlayerID, CellIdx: Integer);
    // ── Callbacks del Game Engine → UI ────────────────────────────
    procedure GE_OnDiceRolled(PlayerID, DiceValue: Integer);
    procedure GE_OnPlayerMoved(PlayerID, NewCellIdx: Integer);
    procedure GE_OnTurnChanged(NewPlayerID: Integer);
    procedure GE_OnGameOver(WinnerID: Integer);
    procedure GE_OnRuleTriggered(PlayerID: Integer; const RuleType, Message: string);

    procedure tmrWalkTimer(Sender: TObject);
    procedure EjecutarAnimacionRegla(PlayerID: Integer; const RuleType, Message: string);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

const
  // Offsets para separar visualmente los 4 avatares en la casilla inicial
  // Forman un cuadrado de ~40px con el avatar de 128x128 como referencia
  AVATAR_START_OFFSET : array[0..3] of TPointF = (
    (X:  0;  Y:  0),   // Player 1 — esquina superior izquierda
    (X: 40;  Y:  0),   // Player 2 — esquina superior derecha
    (X:  0;  Y: 40),   // Player 3 — esquina inferior izquierda
    (X: 40;  Y: 40)    // Player 4 — esquina inferior derecha
  );

implementation

{$R *.fmx}

// ── Inicialización ────────────────────────────────────────────────────────────
procedure TfrmMain.FormCreate(Sender: TObject);
var
  i   : Integer;
  idx : Integer;
  avatarImgs : array[0..3] of TImage;
begin
  FIndex := 0;
  Randomize;

  // Crear directorio de datos si no existe en esta máquina
  ForceDirectories(ExtractFilePath(DB_PATH));

  // Inicializar managers (DB_PATH viene de uConfig)
  FDB            := TDatabase.Create(DB_PATH);
  FBoardManager  := TBoardManager.Create(ilBoards, FDB);
  FPlayerManager := TPlayerManager.Create(ilAvatars);
  FDemoCell      := 0;
  FTotalPlayers  := 4;   // F4: será configurable

  // Inicializar Game Engine y conectar callbacks
  FGameEngine := TGameEngine.Create(FTotalPlayers);
  FGameEngine.OnDiceRolled  := GE_OnDiceRolled;
  FGameEngine.OnPlayerMoved := GE_OnPlayerMoved;
  FGameEngine.OnTurnChanged := GE_OnTurnChanged;
  FGameEngine.OnGameOver    := GE_OnGameOver;
  FGameEngine.OnRuleTriggered := GE_OnRuleTriggered;

  // Asignar avatares aleatorios a los 4 jugadores
  // (solo para demo — será reemplazado por fAvatarSelectForm)
  avatarImgs[0] := imgAvatar1; // TODO: comentar las siguiente 4 lineas para probar runtime results
  avatarImgs[1] := imgAvatar2;
  avatarImgs[2] := imgAvatar3;
  avatarImgs[3] := imgAvatar4;

  // Cargar solo los avatares de los jugadores activos
  for i := 0 to 3 do
  begin
    if i < FTotalPlayers then
    begin
      // Verificar que aún hay avatares disponibles antes de seleccionar
      if FPlayerManager.AvailableCount > 0 then
      begin
        idx := FPlayerManager.SelectRandomAvatar;
        FPlayerManager.LoadAvatarIntoImage(idx, avatarImgs[i]);
      end;
      avatarImgs[i].Visible := True;
    end
    else
      avatarImgs[i].Visible := False;
  end;

  lblTurno.Text := 'Selecciona un tablero para iniciar';
  lblDado.Text  := 'Dado: —';

  // Para evitar mal flujo del juego
  btnTirarDado.Enabled := False;

  // -- Inicializar temporizador de caminado --
  FTmrWalk := TTimer.Create(Self);
  FTmrWalk.Interval := 250; // 250ms por cada casilla que avanza
  FTmrWalk.Enabled := False;
  FTmrWalk.OnTimer := tmrWalkTimer;
end; // FormCreate()

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FGameEngine.Free;
  FBoardManager.Free;
  FPlayerManager.Free;
  FDB.Free;
end;

procedure TfrmMain.imgBoardResize(Sender: TObject);
begin
  // 1. Verificamos que FBoardManager ya esté instanciado en memoria
  if Assigned(FBoardManager) then
  begin
    // 2. Ahora sí es seguro consultar sus propiedades
    if FBoardManager.ActiveBoardHasCoords then
      ResetAvatarsToStart; // TODO F5: reposicionar cada jugador en su casilla actual
  end;
end;

// ── Captura de coordenadas (directamente sobre imgBoard) ──────────────────────
procedure TfrmMain.imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
begin
// Atrapamos las coordenadas exactas del mouse justo antes del click/doble click
  FLastX := X;
  FLastY := Y;
  lblCoords.Text := Format('X: %.1f  Y: %.1f', [X, Y]);
end;

// DblClick — graba casilla si está en modo captura
procedure TfrmMain.imgBoardDblClick(Sender: TObject);
begin
  if not FBoardManager.IsCapturing then Exit;

  // RecordCell normaliza internamente X,Y a 0..1
  FBoardManager.RecordCell(FLastX, FLastY);

  lblCoords.Text := Format('Capturando: %d/%d  →  X:%.1f Y:%.1f',
    [FBoardManager.CaptureProgress, MAX_CELLS, FLastX, FLastY]);

  if FBoardManager.CaptureProgress >= MAX_CELLS then
  begin
    FBoardManager.FinishCapture;
    ShowMessage('¡Coordenadas guardadas correctamente!');
    lblCoords.Text := 'Listo';

    // Restaurar avatares a la casilla 0
    ResetAvatarsToStart;
  end;
end; // imgBoardDblClick()

// btnCapturarClick — pasar dimensiones al iniciar captura
procedure TfrmMain.btnCapturarClick(Sender: TObject);
begin
  if FBoardManager.ActiveBoardIdx = BLANK_IDX then
  begin
    ShowMessage('Selecciona un tablero primero');
    Exit;
  end;
  // Pasar dimensiones actuales para normalización (fix coordenadas relativas)
  FBoardManager.StartCapture(
    FBoardManager.ActiveBoardIdx,
    imgBoard.Width, // ← dimensiones actuales del imgBoard
    imgBoard.Height
  );

  // Ocultar avatares para que no estorben durante la captura
  imgAvatar1.Visible := False;
  imgAvatar2.Visible := False;
  imgAvatar3.Visible := False;
  imgAvatar4.Visible := False;

  lblCoords.Text := Format('Modo captura — Tablero %d: doble click en casilla 1/%d',
                            [FBoardManager.ActiveBoardIdx, MAX_CELLS]);
end;

// ── Navegación de tableros ────────────────────────────────────────────────────
procedure TfrmMain.btnRulesClick(Sender: TObject);
begin
  if not Assigned(frmRules) then
    frmRules := TfrmRules.Create(Application);

  frmRules.CargarReglas(FBoardManager.ActiveBoardIdx);

  // Usamos Show en lugar de ShowModal.
  // Esto abre la ventana, pero permite seguir jugando en el tablero de fondo.
  frmRules.Show;
end;

procedure TfrmMain.btnStartGameClick(Sender: TObject);
var
  arrInput: TArray<string>;
  numPlayers: Integer;
  i: Integer;
  frmBoard: TfrmBoardSelect; // Variable para nuestro nuevo formulario
  selectedBoardIdx: Integer;
begin
  // --- 1. SELECCIÓN DE TABLERO ---
  selectedBoardIdx := -1;
  frmBoard := TfrmBoardSelect.CreateWithImages(Application, ilBoards);
  try
    if frmBoard.ShowModal = mrOk then
      selectedBoardIdx := frmBoard.SelectedIdx
    else
    begin
      ShowMessage('Partida cancelada: No se seleccionó un tablero.');
      Exit;
    end;
  finally
    frmBoard.Free;
  end;

  // Cargar visualmente el tablero seleccionado y actualizar el BoardManager
  FBoardManager.LoadBoardIntoImage(selectedBoardIdx, imgBoard);
  FBoardManager.SetActiveBoard(selectedBoardIdx);

  // Validación CRÍTICA: ¿El tablero elegido tiene coordenadas en SQLite?
  if not FBoardManager.ActiveBoardHasCoords then
  begin
    ShowMessage('El tablero seleccionado no tiene sus coordenadas definidas. ' +
                'Por favor, usa "Capturar Casillas" primero.');
    Exit;
  end;

// --- 2. CANTIDAD DE JUGADORES ---

  // Asignamos tamaño al arreglo dinámico y le damos su valor por defecto
  SetLength(arrInput, 1);
  arrInput[0] := '2';

  // Usamos la sobrecarga de 3 parámetros. arrInput entra como '2' y sale con la respuesta.
  if not TDialogServiceSync.InputQuery('Nueva Partida', ['¿Cuántos jugadores? (2-4):'], arrInput) then
  begin
    ShowMessage('Configuración de partida cancelada.');
    Exit;
  end;

  // Leemos la respuesta que se guardó en arrInput
  numPlayers := StrToIntDef(arrInput[0], 0);

  if (numPlayers < 2) or (numPlayers > 4) then
  begin
    ShowMessage('La cantidad de jugadores debe ser entre 2 y 4.');
    Exit;
  end;

  // --- 3. PREPARAR EL MOTOR ---
  FTotalPlayers := numPlayers;
  FGameEngine.TotalPlayers := numPlayers;
  FPlayerManager.ResetTakenAvatars;

  // Ocultar avatares viejos y bloquear el blank
  for i := 1 to 4 do GetAvatarImage(i).Visible := False;
  FPlayerManager.MarkAvatarTaken(BLANK_IDX);

  // --- 4. SELECCIÓN DE AVATARES ---
  for i := 1 to FTotalPlayers do
  begin
    if not SeleccionarAvatar(i, 'Jugador ' + IntToStr(i)) then
    begin
      ShowMessage('Configuración de partida cancelada.');
      Exit;
    end;
  end;

  // --- 5. INICIAR PARTIDA ---
  ResetAvatarsToStart;
  FGameEngine.StartGame;
  btnTirarDado.Enabled := True;
end; // btnStartGameClick()

// ── Gestión de avatares ───────────────────────────────────────────────────────
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

  // ¡RESETEAR PROPIEDADES VISUALES POR SI VENÍAN DE UNA ANIMACIÓN!
  img.Opacity := 1.0;
  img.Scale.X := 1.0;
  img.Scale.Y := 1.0;
  img.RotationAngle := 0;

  img.Visible    := True;
  img.BringToFront; // Nos aseguramos de que el pato no quede detrás del tablero
end;
procedure TfrmMain.ResetAvatarsToStart;
var
  basePos : TPointF;
  avatars : array[0..3] of TImage;
  i       : Integer;
begin
  for i := 1 to 4 do FVisualPositions[i] := 0; // Reiniciar posiciones visuales

  avatars[0] := imgAvatar1;
  avatars[1] := imgAvatar2;
  avatars[2] := imgAvatar3;
  avatars[3] := imgAvatar4;

  // Si el tablero activo no tiene coordenadas, ocultar avatares y salir
  if not FBoardManager.ActiveBoardHasCoords then
  begin
    for i := 0 to 3 do avatars[i].Visible := False;
    Exit;
  end;

  // Posición base = casilla 0 del tablero activo (tu coordenada de inicio)
  basePos := FBoardManager.GetCellPosition(0, imgBoard.Width, imgBoard.Height);

  for i := 0 to 3 do
  begin
    if i < FTotalPlayers then
    begin
      avatars[i].Width      := 64;
      avatars[i].Height     := 64;
      avatars[i].Position.X := basePos.X + AVATAR_START_OFFSET[i].X;
      avatars[i].Position.Y := basePos.Y + AVATAR_START_OFFSET[i].Y;
      avatars[i].Visible    := True;
    end
    else
      avatars[i].Visible := False;
  end;
end;

// ── Selector de avatares ──────────────────────────────────────────────────────
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

      // Evitar que elijan el índice 0 (Blank)
      if idx > 0 then
      begin
        FPlayerManager.MarkAvatarTaken(idx);

        // Obtenemos el TImage dinámicamente según el jugador (1 al 4)
        imgDestino := GetAvatarImage(PlayerID);
        FPlayerManager.LoadAvatarIntoImage(idx, imgDestino);

        Result := True;
      end else
      begin
        ShowMessage('El avatar en blanco no es seleccionable.');
      end;
    end;
  finally
    frm.Free;
  end;
end;

// ── Game Engine — F3 ──────────────────────────────────────────────────────────
procedure TfrmMain.btnTirarDadoClick(Sender: TObject);
begin
  if not FGameEngine.GameActive then
  begin
    ShowMessage('Selecciona un tablero con coordenadas para iniciar.');
    Exit;
  end;
  FGameEngine.TryRollDice(FGameEngine.GetCurrentPlayer);
end;

procedure TfrmMain.tmrWalkTimer(Sender: TObject);
var
  step: Integer;
  pt: TPointF;
begin
  // ¿Ya llegamos a la casilla destino?
  if FVisualPositions[FWalkingPlayer] = FWalkTargetCell then
  begin
    FTmrWalk.Enabled := False;

    // 1. ¿Hay una trampa o regla esperándolo aquí?
    if FPendingRuleType <> '' then
    begin
      EjecutarAnimacionRegla(FWalkingPlayer, FPendingRuleType, FPendingRuleMessage);
      FPendingRuleType := ''; // Limpiar la memoria
    end;

    // 2. ¿Hay un salto secundario pendiente? (De Oca a Oca, Laberinto, etc.)
    if FSecondaryTargetCell <> -1 then
    begin
      FWalkTargetCell := FSecondaryTargetCell;
      FSecondaryTargetCell := -1; // Limpiar

      // Magia: Hacemos una pausa para dejar que la animación de la regla termine
      // Usamos un hilo anónimo para no congelar tu interfaz
      TThread.CreateAnonymousThread(procedure
        begin
          Sleep(1200); // 1.2 segundos para que el usuario admire el evento
          TThread.Synchronize(nil, procedure
            begin
              FTmrWalk.Enabled := True; // ¡A caminar hacia el destino final!
            end);
        end).Start;
    end;

    Exit;
  end;

  // Si no hemos llegado, damos 1 paso adelante (o hacia atrás)
  if FVisualPositions[FWalkingPlayer] < FWalkTargetCell then
    step := 1
  else
    step := -1;

  FVisualPositions[FWalkingPlayer] := FVisualPositions[FWalkingPlayer] + step;
  pt := FBoardManager.GetCellPosition(FVisualPositions[FWalkingPlayer], imgBoard.Width, imgBoard.Height);

  TAnimator.AnimateFloat(GetAvatarImage(FWalkingPlayer), 'Position.X', pt.X, 0.2);
  TAnimator.AnimateFloat(GetAvatarImage(FWalkingPlayer), 'Position.Y', pt.Y, 0.2);
end; // tmrWalkTimer()

procedure TfrmMain.EjecutarAnimacionRegla(PlayerID: Integer; const RuleType, Message: string);
var
  imgPlayer: TImage;
begin
  imgPlayer := GetAvatarImage(PlayerID);
  imgPlayer.BringToFront;

  // 1. Mostrar el mensaje flotante arreglado (animamos el rectángulo padre)
  if Assigned(rctnglSpecialEvent) and Assigned(lblEventoEspecial) then
  begin
    lblEventoEspecial.Text := Message;
    rctnglSpecialEvent.Opacity := 1.0;
    rctnglSpecialEvent.Visible := True;
    rctnglSpecialEvent.BringToFront;

    // Animamos la opacidad del rectángulo (se desvanecerá junto con su texto)
    TAnimator.AnimateFloat(rctnglSpecialEvent, 'Opacity', 0.0, 4.0);
  end;

// ── ANIMACIÓN: EL POZO ──
  if RuleType = 'WELL' then
  begin
    if Assigned(imgWell) then
    begin
      var ptAbs, ptLoc: TPointF;

      // Truco maestro: Obtenemos la posición exacta del pozo en la pantalla (Absoluta)
      ptAbs := imgWell.LocalToAbsolute(TPointF.Create(0,0));
      // Y la convertimos al idioma del contenedor donde viven los patos (Local)
      ptLoc := lytBoard.AbsoluteToLocal(ptAbs);

      // Ahora el pato volará exactamente hacia el pozo sin fallar
      TAnimator.AnimateFloat(imgPlayer, 'Position.X', ptLoc.X + 20, 1.0);
      TAnimator.AnimateFloat(imgPlayer, 'Position.Y', ptLoc.Y + 20, 1.0);

      TAnimator.AnimateFloat(imgPlayer, 'RotationAngle', 1080, 2.0);
      TAnimator.AnimateFloat(imgPlayer, 'Scale.X', 0.1, 2.0);
      TAnimator.AnimateFloat(imgPlayer, 'Scale.Y', 0.1, 2.0);
      TAnimator.AnimateFloat(imgPlayer, 'Opacity', 0.0, 2.0);
    end;
  end

// ── ANIMACIÓN: LA MUERTE (CALAVERA) ──
  else if RuleType = 'DEATH' then
  begin
    TAnimator.AnimateFloat(imgPlayer, 'Position.X', imgPlayer.Position.X + 15, 0.05);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Position.X', imgPlayer.Position.X - 30, 0.05, 0.05);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Position.X', imgPlayer.Position.X + 15, 0.05, 0.1);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Position.Y', imgPlayer.Position.Y + 800, 1.0, 0.3);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Opacity', 0.0, 0.5, 0.3);

    // Como regresa al inicio, teletransportamos visualmente su posición interna
    // para evitar que tenga que caminar 58 casillas hacia atrás.
    FVisualPositions[PlayerID] := 0;
  end

  // ── ANIMACIÓN: DE OCA A OCA ──
  else if RuleType = 'GOOSE' then
  begin
    TAnimator.AnimateFloat(imgPlayer, 'Scale.X', 1.8, 0.3);
    TAnimator.AnimateFloat(imgPlayer, 'Scale.Y', 1.8, 0.3);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Scale.X', 1.0, 0.3, 0.4);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Scale.Y', 1.0, 0.3, 0.4);
  end

  // ── ANIMACIÓN: EL LABERINTO ──
  else if RuleType = 'MAZE' then
  begin
    TAnimator.AnimateFloat(imgPlayer, 'RotationAngle', 1080, 1.5);
    TAnimator.AnimateFloat(imgPlayer, 'Opacity', 0.2, 0.2);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Opacity', 1.0, 0.2, 0.2);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Opacity', 0.2, 0.2, 0.4);
    TAnimator.AnimateFloatDelay(imgPlayer, 'Opacity', 1.0, 0.2, 0.6);
  end;
end; // EjecutarAnimacionRegla()

procedure TfrmMain.GE_OnDiceRolled(PlayerID, DiceValue: Integer);
var
  frmDice: TfrmDice;
begin
  // Creamos el formulario
  frmDice := TfrmDice.CreateWithResult(Application, ilDiceFaces, DiceValue);

  // ¡El bloque try debe ir acompañado de un begin si abarca más de una línea de código!
  // Aunque en este caso es una sola línea (frmDice.ShowModal), la convención es ponerlo.
  try
    frmDice.ShowModal; // El juego se pausa aquí hasta que la animación termine
  finally
    frmDice.Free;
  end;

  lblDado.Text := Format('J%d tiró: %d', [PlayerID, DiceValue]);
end;

procedure TfrmMain.GE_OnPlayerMoved(PlayerID, NewCellIdx: Integer);
var
  img: TImage;
begin
  // ¡EL ANTÍDOTO CONTRA FANTASMAS!
  // Restauramos al pato a su estado original ANTES de que empiece a caminar
  img := GetAvatarImage(PlayerID);
  img.Opacity := 1.0;
  img.Scale.X := 1.0;
  img.Scale.Y := 1.0;
  img.RotationAngle := 0;
  img.Visible := True;
  img.BringToFront;

  if not FTmrWalk.Enabled then
  begin
    // Es el movimiento normal de los dados
    FWalkingPlayer := PlayerID;
    FWalkTargetCell := NewCellIdx;
    FSecondaryTargetCell := -1;
    FTmrWalk.Enabled := True;
  end
  else
  begin
    // El motor ya calculó el salto extra, lo guardamos para después
    FSecondaryTargetCell := NewCellIdx;
  end;
end; // GE_OnPlayerMoved()

procedure TfrmMain.GE_OnRuleTriggered(PlayerID: Integer; const RuleType, Message: string);
begin
  // El motor nos manda una regla, pero el pato apenas va a empezar a caminar.
  // Guardamos la regla en memoria para ejecutarla después.
  FPendingRulePlayer := PlayerID;
  FPendingRuleType := RuleType;
  FPendingRuleMessage := Message;
end;

procedure TfrmMain.GE_OnTurnChanged(NewPlayerID: Integer);
begin
  lblTurno.Text := Format('Turno: Jugador %d', [NewPlayerID]);
end;

procedure TfrmMain.GE_OnGameOver(WinnerID: Integer);
begin
  lblTurno.Text := Format('🏆 ¡Jugador %d ganó!', [WinnerID]);
  lblDado.Text  := '— Partida terminada —';
  ShowMessage(Format('¡Jugador %d ganó!', [WinnerID]));
end;

end.
