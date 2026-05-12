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
  uPlayerManager;

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
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnCapturarClick(Sender: TObject);
    procedure imgBoardDblClick(Sender: TObject);
    procedure btnAvanzarClick(Sender: TObject);
    procedure btnChangeBoardClick(Sender: TObject);
    procedure imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
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
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

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

procedure TfrmMain.btnCapturarClick(Sender: TObject);
begin
  if FIndex = BLANK_IDX then
  begin
    ShowMessage('Selecciona un tablero primero');
    Exit;
  end;
  FBoardManager.StartCapture(FIndex);
  lblCoords.Text := 'Modo captura: haz doble click en cada casilla (0/' +
                    IntToStr(MAX_CELLS) + ')';
end;

procedure TfrmMain.btnChangeBoardClick(Sender: TObject);
begin
  // Metodo para cambiar los boards
  // 1. Usar el valor actual de FIndex (empieza en 0 por defecto al crear el formulario)
  SetImageByIndex(ilBoards, imgBoard, FIndex);
  ShowMessage('valor del index: ' + IntToStr(FIndex));

  // 2. Incrementar para el próximo clic
  Inc(FIndex);

  // 3. Reiniciar a 0 si llegamos al límite (asumiendo que tienes imágenes 0, 1 y 2)
  if FIndex >= 4 then
    FIndex := 0;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  DBPath : string;
  DataDir : string;
begin
  // Inicializar la semilla de números aleatorios
  Randomize;

  DataDir := ExtractFilePath(ParamStr(0)) + 'data';
  // Crear la carpeta si no existe (ForceDirectories crea también subdirectorios)
  ForceDirectories(DataDir);

  // ExtractFilePath(ParamStr(0)) = carpeta donde está el .exe
  // Al correr desde el IDE = Win32\Debug\ del proyecto
  DBPath := DataDir + PathDelim + 'goose.db';

  // Le pasa SU ImageList a cada manager
  FDB            := TDatabase.Create(DBPath);
  FBoardManager  := TBoardManager.Create(ilBoards, FDB);
  FPlayerManager := TPlayerManager.Create(ilAvatars);
  FDemoCell      := 0;

// Asignar avatares aleatorios a cada uno de los 4 ImageControls
  FPlayerManager.LoadAvatarIntoImage(FPlayerManager.SelectRandomAvatar, imgAvatar1);
  FPlayerManager.LoadAvatarIntoImage(FPlayerManager.SelectRandomAvatar, imgAvatar2);
  FPlayerManager.LoadAvatarIntoImage(FPlayerManager.SelectRandomAvatar, imgAvatar3);
  FPlayerManager.LoadAvatarIntoImage(FPlayerManager.SelectRandomAvatar, imgAvatar4);
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

end.
