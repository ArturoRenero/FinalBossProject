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
  // DataBase Libs
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper.Stat,
  // External Units
  uTypes,           // ← MAX_CELLS, BLANK_IDX, TBoardCells, TAllBoardCoords
  uDatabase,        // ← TDatabase
  uBoardManager,
  uPlayerManager,
  fAvatarSelectForm,
  uConfig,
  fConfigForm,
  uTurnManager,
  uGameEngine;

type
  TfrmMain = class(TForm)
    // ── Componentes del diseñador (published) ────────────────────
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
    btnChangeBoard: TButton;
    lytButtons: TLayout;
    rctngl1: TRectangle;
    btnAvatarSelector: TButton;
    btnConfig: TButton;
    lblTurno: TLabel;
    lblDado: TLabel;
    // ── Event handlers (published) ───────────────────────────────
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnCapturarClick(Sender: TObject);
    procedure imgBoardDblClick(Sender: TObject);
    procedure btnTirarDadoClick(Sender: TObject);
    procedure btnChangeBoardClick(Sender: TObject);
    procedure imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure AbrirSeleccionAvatar(const NombreJugador: string);
    procedure btnAvatarSelectorClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure btnConfigClick(Sender: TObject);
  private
    { Private declarations }
    // ── Campos de estado ─────────────────────────────────────────
    FIndex: Integer; // <-- Declarada aquí para que persista. La 'F' es convención de Delphi para 'Fields' (Campos).
    FLastX  : Single;   // ← última posición X del mouse sobre el tablero
    FLastY  : Single;   // ← última posición Y del mouse sobre el tablero
    FCurrentCell : Integer;  // ← índice de la casilla que se está definiendo
    FDemoCell    : Integer;   // casilla actual de la demo
    FTotalPlayers : Integer;

    // ── Managers ─────────────────────────────────────────────────
    FDB          : TDatabase; // referencia a la base de datos
    FBoardManager  : TBoardManager;
    FPlayerManager : TPlayerManager;
    FGameEngine   : TGameEngine;


    // ── Helpers ──────────────────────────────────────────────────
    function  GetAvatarImage(PlayerID: Integer): TImage;
    procedure MoveAvatarToCell(PlayerID, CellIdx: Integer);
    procedure ResetAvatarsToStart;

    // ── Callbacks del Game Engine → UI ───────────────────────────
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

//procedure SetImageByIndex(AImageList: TImageList; AImage: TImage; const Index: Integer);
//var Bmp: TBitmap; Sz: TSizeF;
//begin
//  Sz := TSizeF.Create(AImage.Width, AImage.Height);
//  Bmp := AImageList.Bitmap(Sz, Index);
//  if Bmp <> nil then AImage.Bitmap.Assign(Bmp);
//end;

procedure TfrmMain.btnAvatarSelectorClick(Sender: TObject);
begin
  AbrirSeleccionAvatar('Player 1');
end;

procedure TfrmMain.btnCapturarClick(Sender: TObject);
begin
  // FIndex ya fue incrementado por btnChangeBoardClick.
  // ActiveBoardIdx es la fuente correcta del tablero actualmente visible.
  if FBoardManager.ActiveBoardIdx = BLANK_IDX then
  begin
    ShowMessage('Selecciona un tablero primero');
    Exit;
  end;
  FBoardManager.StartCapture(
    FBoardManager.ActiveBoardIdx,
    imgBoard.Width,    // ← dimensiones actuales del imgBoard
    imgBoard.Height
  );
  lblCoords.Text := Format('Modo captura — Tablero %d: doble click en cada casilla (0/%d)',
                            [FBoardManager.ActiveBoardIdx, MAX_CELLS]);
end;

procedure TfrmMain.btnChangeBoardClick(Sender: TObject);
begin
  // Metodo para cambiar los boards
  // 1. Cargar la imagen del tablero actual
  FBoardManager.LoadBoardIntoImage(FIndex, imgBoard);

  // 2. Notificar al BoardManager cuál es el tablero activo ANTES de incrementar
  FBoardManager.SetActiveBoard(FIndex);

  // 3. Resetear el demo al cambiar de tablero
  FDemoCell := 0;

  // 4. Avanzar al siguiente índice
  Inc(FIndex);
  if FIndex >= ilBoards.Count then FIndex := 0;

  // 5. Colocar avatares en casilla 0 del nuevo tablero
  ResetAvatarsToStart;

  // Iniciar o reiniciar el juego al cambiar tablero
  if FBoardManager.ActiveBoardHasCoords
  then
    begin
      // GE_OnTurnChanged se dispara automáticamente desde StartGame
      FGameEngine.StartGame;
    end
  else lblTurno.Text := 'Tablero sin coordenadas definidas';
end;

procedure TfrmMain.btnConfigClick(Sender: TObject);
var
  frm : TfrmConfig;
begin
  if FBoardManager.ActiveBoardIdx = BLANK_IDX then
  begin
    ShowMessage('Selecciona un tablero antes de abrir la configuración');
    Exit;
  end;

  frm := TfrmConfig.CreateForBoard(
           Application,
           FBoardManager,
           FBoardManager.ActiveBoardIdx);
  try
    frm.ShowModal;
    // Al cerrar: recargar coords en memoria por si se guardaron nuevas
    FBoardManager.LoadAll;
    ResetAvatarsToStart;
  finally
    frm.Free;
  end;
end;

procedure TfrmMain.btnTirarDadoClick(Sender: TObject);
begin
  if not FGameEngine.GameActive then
  begin
    ShowMessage('La partida no ha iniciado. Selecciona un tablero primero.');
    Exit;
  end;
  // Tirar dado para el jugador activo.
  // El GE ignora el input si no es su turno (guard interno).
  FGameEngine.TryRollDice(FGameEngine.GetCurrentPlayer);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  i   : Integer;
  idx : Integer;
  avatarImgs : array[0..3] of TImage;
begin
  Randomize;

  // Crear directorio de datos si no existe en esta máquina
  ForceDirectories(ExtractFilePath(DB_PATH));

  // Inicializar managers (DB_PATH viene de uConfig)
  FDB            := TDatabase.Create(DB_PATH);
  FBoardManager  := TBoardManager.Create(ilBoards, FDB);
  FPlayerManager := TPlayerManager.Create(ilAvatars);
  FDemoCell      := 0;
  FTotalPlayers  := 2;   // TODO: F3: 2 jugadores locales (configurable en F4)

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



  for i := 0 to 3 do
  begin
    if i < FTotalPlayers then   // ← solo los jugadores activos
    begin
      if FPlayerManager.AvailableCount > 0 then // Verificar que aún hay avatares disponibles antes de seleccionar
      begin
        idx := FPlayerManager.SelectRandomAvatar;
        FPlayerManager.LoadAvatarIntoImage(idx, avatarImgs[i]);
      end;
      avatarImgs[i].Visible := True;
    end
    else
      avatarImgs[i].Visible := False;  // ← ocultar slots sin jugador
  end;

  lblTurno.Text := 'Selecciona un tablero para iniciar';
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FGameEngine.Free;
  FBoardManager.Free;
  FPlayerManager.Free;
  FDB.Free;
end;

procedure TfrmMain.FormResize(Sender: TObject);
begin
  // Reposicionar avatares usando las nuevas dimensiones del imgBoard
  if FBoardManager.ActiveBoardHasCoords
  then ResetAvatarsToStart;
  // TODO Fase 5: reposicionar cada jugador en su casilla actual
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

// ── Callbacks del Game Engine ─────────────────────────────────────────────────
procedure TfrmMain.GE_OnDiceRolled(PlayerID, DiceValue: Integer);
const
  DICE_CHARS: array[1..6] of string = ('Cara1','Cara2','Cara3','Cara4','Cara5','Cara6');
begin
  lblDado.Text := Format('Jugador %d tiró: %s (%d)',
                          [PlayerID, DICE_CHARS[DiceValue], DiceValue]);
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
  ShowMessage(Format('¡Jugador %d ganó la partida!', [WinnerID]));
end;

// DblClick — graba casilla si está en modo captura
procedure TfrmMain.imgBoardDblClick(Sender: TObject);
begin
  if FBoardManager.IsCapturing then
  begin
    FBoardManager.RecordCell(FLastX, FLastY);
    lblCoords.Text := Format('Capturando: %d/%d  →  X:%.1f Y:%.1f',
      [FBoardManager.CaptureProgress, MAX_CELLS, FLastX, FLastY]);

    if FBoardManager.CaptureProgress >= MAX_CELLS then
    begin
      FBoardManager.FinishCapture;
      ShowMessage('¡Coordenadas del tablero guardadas correctamente!');
      lblCoords.Text := 'Listo';
    end;
  end
  else
  begin
    // Modo demo (lo que ya tenías)
    ShowMessage(Format('Casilla %d → X: %.1f  Y: %.1f',
                       [FCurrentCell, FLastX, FLastY]));
    Inc(FCurrentCell);
  end;
end;

procedure TfrmMain.imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
begin
// Atrapamos las coordenadas exactas del mouse justo antes del click/doble click
  FLastX := X;
  FLastY := Y;
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
  img.Visible    := True;
end;

procedure TfrmMain.ResetAvatarsToStart;
var
  basePos : TPointF;
  avatars : array[0..3] of TImage;
  i       : Integer;
begin
  // Definir el array PRIMERO para poder usarlo en el Exit temprano
  avatars[0] := imgAvatar1;
  avatars[1] := imgAvatar2;
  avatars[2] := imgAvatar3;
  avatars[3] := imgAvatar4;

  // Si el tablero activo no tiene coordenadas, ocultar avatares y salir
  if not FBoardManager.ActiveBoardHasCoords then
  begin
    for i := 0 to 3 do
      avatars[i].Visible := False;   // ← usar el array, no set literal
    Exit;
  end;

  // Posición base = casilla 0 del tablero activo (tu coordenada de inicio)
  basePos := FBoardManager.GetCellPosition(0, imgBoard.Width, imgBoard.Height);

  for i := 0 to 3 do
  begin
    if i < FTotalPlayers then   // ← solo jugadores activos
    begin
      avatars[i].Width      := 64;
      avatars[i].Height     := 64;
      avatars[i].Position.X := basePos.X + AVATAR_START_OFFSET[i].X;
      avatars[i].Position.Y := basePos.Y + AVATAR_START_OFFSET[i].Y;
      avatars[i].Visible    := True;
    end
    else
      avatars[i].Visible := False;  // ← ocultar slots vacíos
  end;
end;

procedure TfrmMain.AbrirSeleccionAvatar(const NombreJugador: string);
var
  frm : TfrmAvatarSelect;
  idx : Integer;
begin
  frm := TfrmAvatarSelect.CreateForPlayer(
           Application,
           ilAvatars,
           FPlayerManager.GetTakenArray,
           NombreJugador);
  try
    if frm.ShowModal = mrOk then
    begin
      idx := frm.SelectedIdx;
      FPlayerManager.MarkAvatarTaken(idx);
      // Aquí cargar la imagen del avatar seleccionado en imgAvatar1 (o el que corresponda)
      FPlayerManager.LoadAvatarIntoImage(idx, imgAvatar1);
      imgAvatar1.Visible := True;
    end;
  finally
    frm.Free;
  end;
end;

end.
