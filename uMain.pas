unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects, FMX.Layouts,
  System.ImageList, FMX.ImgList;

type
  TfrmMain = class(TForm)
    il1: TImageList;
    lytBoard: TLayout;
    imgBoard: TImage;
    btn1: TButton;
    procedure btn1Click(Sender: TObject);
  private
    { Private declarations }
    FIndex: Integer; // La 'F' es convención de Delphi para 'Fields'
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

procedure TfrmMain.btn1Click(Sender: TObject);
begin
  // 1. Usar el valor actual de FIndex (empieza en 0 por defecto al crear el formulario)
  SetImageByIndex(il1, imgBoard, FIndex);

  // 2. Incrementar para el próximo clic
  Inc(FIndex);

  // 3. Reiniciar a 0 si llegamos al límite (asumiendo que tienes imágenes 0, 1 y 2)
  if FIndex >= 4 then
    FIndex := 0;
end;

end.
