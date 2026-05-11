unit uMain;

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
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects, FMX.Layouts,
  System.ImageList, FMX.ImgList,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper.Stat,  // ← SQLite embebido, sin DLL externa
  uBoardManager, uPlayerManager;

type
  TfrmMain = class(TForm)
    ilBoards: TImageList;
    lytBoard: TLayout;
    imgBoard: TImage;
    btn1: TButton;
    stat1: TStatusBar;
    lblCoords: TLabel;
    ilAvatars: TImageList;
    procedure btn1Click(Sender: TObject);
    procedure imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure imgBoardDblClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    FIndex: Integer; // La 'F' es convención de Delphi para 'Fields'
    FLastX  : Single;   // ← última posición X del mouse sobre el tablero
    FLastY  : Single;   // ← última posición Y del mouse sobre el tablero
    FCurrentCell : Integer;  // ← índice de la casilla que se está definiendo

    FBoardManager  : TBoardManager;
    FPlayerManager : TPlayerManager;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation
 {
uses
  uBoardManager, uPlayerManager;
  }

{$R *.fmx}

procedure SetImageByIndex(AImageList: TImageList; AImage: TImage; const Index: Integer);
var Bmp: TBitmap; Sz: TSizeF;
begin
  Sz := TSizeF.Create(AImage.Width, AImage.Height);
  Bmp := AImageList.Bitmap(Sz, Index);
  if Bmp <> nil then AImage.Bitmap.Assign(Bmp);
end;

procedure TfrmMain.btn1Click(Sender: TObject);
begin
{
  // 1. Usar el valor actual de FIndex (empieza en 0 por defecto al crear el formulario)
  SetImageByIndex(ilBoards, imgBoard, FIndex);

  // 2. Incrementar para el próximo clic
  Inc(FIndex);

  // 3. Reiniciar a 0 si llegamos al límite (asumiendo que tienes imágenes 0, 1 y 2)
  if FIndex >= 4 then
    FIndex := 0;
}

  FBoardManager.LoadBoardIntoImage(FIndex, imgBoard);
  Inc(FIndex);
  if FIndex >= ilBoards.Count then FIndex := 0;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  // Le pasa SU ImageList a cada manager
  FBoardManager  := TBoardManager.Create(ilBoards);
  FPlayerManager := TPlayerManager.Create(ilAvatars);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FBoardManager.Free;
  FPlayerManager.Free;
end;

procedure TfrmMain.imgBoardDblClick(Sender: TObject);
begin
  // Guardar coordenada de la casilla actual
  // X, Y ya los tienes del último MouseMove
  // imgAvatar1.Position.X := FLastX;
  // imgAvatar1.Position.Y := FLastY;

  // Aquí registrarás la casilla FCurrentCell con (FLastX, FLastY)
  // y harás Inc(FCurrentCell)
  ShowMessage(Format('Casilla %d → X: %.1f  Y: %.1f',
                     [FCurrentCell, FLastX, FLastY]));
  Inc(FCurrentCell);
end;

procedure TfrmMain.imgBoardMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
begin
  // X, Y son locales a imgBoard.
  // Si imgBoard está en (0,0) dentro de lytBoard,
  // puedes usar X, Y directamente para posicionar avatares.
  FLastX := X;
  FLastY := Y;
  lblCoords.Text := Format('X: %.1f  Y: %.1f', [X, Y]);
end;

end.
