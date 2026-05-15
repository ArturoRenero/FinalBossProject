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
  uConfig;

type
  TfrmMain = class(TForm)
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
    btnAvanzar: TButton;
    btnCapturar: TButton;
    btnChangeBoard: TButton;
    lytButtons: TLayout;
    rctngl1: TRectangle;
    btnAvatarSelector: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnCapturarClick(Sender: TObject);
    procedure imgBoardDblClick(Sender: TObject);
    procedure btnAvanzarClick(Sender: TObject);
    procedure btnChangeBoardClick(Sender: TObject);
    procedure imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure AbrirSeleccionAvatar(const NombreJugador: string);
    procedure btnAvatarSelectorClick(Sender: TObject);
  private
    { Private declarations }
    FIndex: Integer; // <-- Declarada aquí para que persista. La 'F' es convención de Delphi para 'Fields' (Campos).
    FLastX  : Single;   // ← última posición X del mouse sobre el tablero
    FLastY  : Single;   // ← última posición Y del mouse sobre el tablero
    FCurrentCell : Integer;  // ← índice de la casilla que se está definiendo

    FBoardManager  : TBoardManager;
    FPlayerManager : TPlayerManager;

    FDemoCell    : Integer;   // casilla actual de la demo
    FDB          : TDatabase; // referencia a la base de datos

    procedure ResetAvatarsToStart;
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

procedure SetImageByIndex(AImageList: TImageList; AImage: TImage; const Index: Integer);
var Bmp: TBitmap; Sz: TSizeF;
begin
  Sz := TSizeF.Create(AImage.Width, AImage.Height);
  Bmp := AImageList.Bitmap(Sz, Index);
  if Bmp <> nil then AImage.Bitmap.Assign(Bmp);
end;

// Botón avance manual — mueve imgAvatar1 casilla por casilla
procedure TfrmMain.btnAvanzarClick(Sender: TObject);
var
  pt : TPointF;
begin
  if not FBoardManager.ActiveBoardHasCoords then
  begin
    ShowMessage('Este tablero no tiene coordenadas definidas aún');
    Exit;
  end;

  Inc(FDemoCell);
  if FDemoCell >= MAX_CELLS then FDemoCell := 0;

  pt := FBoardManager.GetCellPosition(FDemoCell);

  // Mover avatar 1 a la casilla
  imgAvatar1.Position.X := pt.X;
  imgAvatar1.Position.Y := pt.Y;
  imgAvatar1.Visible    := True;

  lblCoords.Text := Format('Avatar en casilla %d  →  X:%.1f  Y:%.1f',
                           [FDemoCell, pt.X, pt.Y]);
end;

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
  FBoardManager.StartCapture(FBoardManager.ActiveBoardIdx);
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

  // Asignar avatares aleatorios a los 4 jugadores
  // (solo para demo — será reemplazado por fAvatarSelectForm)
  avatarImgs[0] := imgAvatar1;
  avatarImgs[1] := imgAvatar2;
  avatarImgs[2] := imgAvatar3;
  avatarImgs[3] := imgAvatar4;

  for i := 0 to 3 do
  begin
    // Verificar que aún hay avatares disponibles antes de seleccionar
    if FPlayerManager.AvailableCount > 0 then
    begin
      idx := FPlayerManager.SelectRandomAvatar;
      FPlayerManager.LoadAvatarIntoImage(idx, avatarImgs[i]);
      avatarImgs[i].Visible := True;
    end
    else
      avatarImgs[i].Visible := False;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FBoardManager.Free;
  FPlayerManager.Free;
  FDB.Free;
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

procedure TfrmMain.ResetAvatarsToStart;
var
  basePos : TPointF;
  avatars : array[0..3] of TImage;
  i       : Integer;
begin
  // Si el tablero activo no tiene coordenadas, ocultar avatares y salir
  if not FBoardManager.ActiveBoardHasCoords then
  begin
    imgAvatar1.Visible := False;
    imgAvatar2.Visible := False;
    imgAvatar3.Visible := False;
    imgAvatar4.Visible := False;
    Exit;
  end;

  // Posición base = casilla 0 del tablero activo (tu coordenada de inicio)
  basePos := FBoardManager.GetCellPosition(0);

  avatars[0] := imgAvatar1;
  avatars[1] := imgAvatar2;
  avatars[2] := imgAvatar3;
  avatars[3] := imgAvatar4;

  for i := 0 to 3 do
  begin
    avatars[i].Width      := 128;
    avatars[i].Height     := 128;
    avatars[i].Position.X := basePos.X + AVATAR_START_OFFSET[i].X;
    avatars[i].Position.Y := basePos.Y + AVATAR_START_OFFSET[i].Y;
    avatars[i].Visible    := True;
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
