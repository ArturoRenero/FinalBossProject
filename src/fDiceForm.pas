unit fDiceForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  System.ImageList, FMX.ImgList;

type
  TfrmDice = class(TForm)
  private
    FImgDice: TImage;
    FTmrAnimation: TTimer;

    FFinalValue: Integer;
    FAnimCount: Integer;
    FDiceImages: TImageList;

    procedure tmrAnimationTimer(Sender: TObject);
  public
    constructor CreateWithResult(AOwner: TComponent; AImages: TImageList; AFinalValue: Integer); reintroduce;
  end;

implementation

constructor TfrmDice.CreateWithResult(AOwner: TComponent; AImages: TImageList; AFinalValue: Integer);
begin
  inherited CreateNew(AOwner); // Evitamos el archivo .fmx intencionalmente

  // 1. Configuración de la ventana transparente
  Width := 150;
  Height := 150;
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.None;
  Transparency := True; // ¡Hace que el fondo sea completamente invisible!
  Fill.Color := TAlphaColorRec.Null;

  FDiceImages := AImages;
  FFinalValue := AFinalValue;
  FAnimCount := 0;

  // 2. Crear el TImage por código
  FImgDice := TImage.Create(Self);
  FImgDice.Parent := Self;
  FImgDice.Align := TAlignLayout.Client;
  FImgDice.WrapMode := TImageWrapMode.Fit;

  // 3. Crear el TTimer por código
  FTmrAnimation := TTimer.Create(Self);
  FTmrAnimation.Interval := 100; // 100 milisegundos = 10 frames por segundo
  FTmrAnimation.OnTimer := tmrAnimationTimer;

  // ¡Arrancar la animación!
  FTmrAnimation.Enabled := True;
end;

procedure TfrmDice.tmrAnimationTimer(Sender: TObject);
var
  randomFace, bmpIndex: Integer;
  Sz: TSizeF;
begin
  Inc(FAnimCount);

  // Tamaño recomendado para extraer las imágenes del ImageList
  Sz.Width := 128;
  Sz.Height := 128;

  if FAnimCount < 15 then
  begin
    // Animación: Mostrar caras aleatorias para simular que está girando
    randomFace := Random(6); // 0 a 5
    FImgDice.Bitmap.Assign(FDiceImages.Bitmap(Sz, randomFace));
  end
  else if FAnimCount = 15 then
  begin
    // Detenerse en el valor real que dictó el Game Engine
    // (Asegúrate de que la cara 1 esté en el índice 0, cara 2 en índice 1, etc.)
    bmpIndex := FFinalValue - 1;
    FImgDice.Bitmap.Assign(FDiceImages.Bitmap(Sz, bmpIndex));
  end
  else if FAnimCount > 22 then
  begin
    // Darle al usuario un instante para ver el resultado antes de cerrar
    FTmrAnimation.Enabled := False;
    ModalResult := mrOk; // Cierra el form y devuelve el control a fMain
  end;
end;

end.
