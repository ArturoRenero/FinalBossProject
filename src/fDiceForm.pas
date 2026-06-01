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
  inherited CreateNew(AOwner);

  Width := 150;
  Height := 150;
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.None;
  Transparency := True;
  Fill.Color := TAlphaColorRec.Null;

  FDiceImages := AImages;
  FFinalValue := AFinalValue;
  FAnimCount := 0;

  FImgDice := TImage.Create(Self);
  FImgDice.Parent := Self;
  FImgDice.Align := TAlignLayout.Client;
  FImgDice.WrapMode := TImageWrapMode.Fit;

  FTmrAnimation := TTimer.Create(Self);
  FTmrAnimation.Interval := 100;
  FTmrAnimation.OnTimer := tmrAnimationTimer;
  FTmrAnimation.Enabled := True;
end;

procedure TfrmDice.tmrAnimationTimer(Sender: TObject);
var
  randomFace, bmpIndex: Integer;
  Sz: TSizeF;
begin
  Inc(FAnimCount);
  Sz.Width := 128;
  Sz.Height := 128;

  if FAnimCount < 15 then
  begin
    randomFace := Random(6);
    FImgDice.Bitmap.Assign(FDiceImages.Bitmap(Sz, randomFace));
  end
  else if FAnimCount = 15 then
  begin
    bmpIndex := FFinalValue - 1;
    FImgDice.Bitmap.Assign(FDiceImages.Bitmap(Sz, bmpIndex));
  end
  else if FAnimCount > 22 then
  begin
    FTmrAnimation.Enabled := False;
    Close; // ¡CAMBIO CLAVE! Usar Close dispara el evento OnClose en fMain
  end;
end;

end.
