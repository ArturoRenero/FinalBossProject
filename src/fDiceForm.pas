unit fDiceForm;

// Formulario secundario que muestra la animación GIF del dado girando (TGifImage o TAnimatedImage) y luego el resultado numérico. Se muestra modal durante el turno activo y se cierra automáticamente.

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  System.ImageList, FMX.ImgList;

type
  TfrmDice = class(TForm)
    imgDice: TImage;
    tmrAnimation: TTimer;
    procedure tmrAnimationTimer(Sender: TObject);
  private
    FFinalValue: Integer;
    FAnimCount: Integer;
    FDiceImages: TImageList; // Puedes pasarle una lista con las 6 caras del dado
  public
    constructor CreateWithResult(AOwner: TComponent; AImages: TImageList; AFinalValue: Integer); reintroduce;
  end;

implementation

constructor TfrmDice.CreateWithResult(AOwner: TComponent; AImages: TImageList; AFinalValue: Integer);
begin
  inherited CreateNew(AOwner);
  // Configura el form (tamaño pequeño, sin bordes, centrado)
  Width := 200; Height := 200;
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.None;

  FDiceImages := AImages;
  FFinalValue := AFinalValue;
  FAnimCount := 0;

  // Inicia la animación al crearse
  tmrAnimation.Enabled := True;
end;

procedure TfrmDice.tmrAnimationTimer(Sender: TObject);
var
  randomFace, bmpIndex: Integer;
  Sz: TSizeF;
begin
  Inc(FAnimCount);

  Sz.Width := imgDice.Width;
  Sz.Height := imgDice.Height;

  if FAnimCount < 15 then
  begin
    // Animación: Mostrar caras aleatorias
    randomFace := Random(6);
    imgDice.Bitmap.Assign(FDiceImages.Bitmap(Sz, randomFace));
  end
  else if FAnimCount = 15 then
  begin
    // Detenerse en el valor real que dictó el Game Engine
    // (Asumiendo que el índice 0 es la cara 1, índice 1 es cara 2, etc.)
    bmpIndex := FFinalValue - 1;
    imgDice.Bitmap.Assign(FDiceImages.Bitmap(Sz, bmpIndex));
  end
  else if FAnimCount > 22 then
  begin
    // Darle al usuario un instante (unos 7 ticks) para ver el resultado antes de cerrar
    tmrAnimation.Enabled := False;
    ModalResult := mrOk; // Cierra el form
  end;
end;

end.
