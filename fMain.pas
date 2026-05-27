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
  uTypes,           // ← MAX_CELLS, BLANK_IDX, TBoardCells, TAllBoardCoords
  uDatabase,        // ← TDatabase
  uBoardManager,
  uPlayerManager,
  fAvatarSelectForm,
  uConfig,
  uTurnManager,
  uGameEngine,
  fBoardSelectForm,
  fDiceForm;

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
    // ── Métodos privados ──────────────────────────────────────────
    procedure ResetAvatarsToStart;
    function  GetAvatarImage(PlayerID: Integer): TImage;
    procedure MoveAvatarToCell(PlayerID, CellIdx: Integer);
    // ── Callbacks del Game Engine → UI ────────────────────────────
    procedure GE_OnDiceRolled(PlayerID, DiceValue: Integer);
    procedure GE_OnPlayerMoved(PlayerID, NewCellIdx: Integer);
    procedure GE_OnTurnChanged(NewPlayerID: Integer);
    procedure GE_OnGameOver(WinnerID: Integer);
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
  // TODO: dafajdsfasdf ========================================================
  {No olvides ir a fMain.pas, declarar el nuevo método que se enlazará a este
  evento (como lo hicimos con la animación del pozo) y conectarlo en el
  FormCreate (FGameEngine.OnRuleTriggered := GE_OnRuleTriggered;).
  ¡Tu juego ya casi tiene mecánicas completas!}

  // TODO: incluir animaciones especiales y el formulario de reglas

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

  // Asignar avatares aleatorios a los 4 jugadores
  // (solo para demo — será reemplazado por fAvatarSelectForm)
  avatarImgs[0] := imgAvatar1;
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
procedure TfrmMain.btnStartGameClick(Sender: TObject);
var
  strPlayers: string;
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
  strPlayers := '2';
  if not InputQuery('Nueva Partida', '¿Cuántos jugadores? (2-4):', strPlayers) then
  begin
    ShowMessage('Configuración de partida cancelada.');
    Exit;
  end;

  numPlayers := StrToIntDef(strPlayers, 0);
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
  // GetCellPosition convierte de coordenada normalizada (0..1) a píxeles actuales
  pt  := FBoardManager.GetCellPosition(CellIdx, imgBoard.Width, imgBoard.Height);
  img := GetAvatarImage(PlayerID);
  img.Position.X := pt.X;
  img.Position.Y := pt.Y;
  img.Visible    := True;
end;

procedure TfrmMain.ResetAvatarsToStart;
var
  basePos : TPointF;
  avatars : array[0..3] of TImage;
  i       : Integer;
begin
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
begin
  MoveAvatarToCell(PlayerID, NewCellIdx);
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
