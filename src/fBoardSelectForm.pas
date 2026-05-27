unit fBoardSelectForm;

// Galería de tableros disponibles usando TImageList. Muestra una grilla de miniaturas. Al seleccionar un tablero se dispara el evento para cargar sus coordenadas desde la base de datos.

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Objects, FMX.Layouts, FMX.StdCtrls, FMX.ScrollBox,
  System.ImageList, FMX.ImgList;

type
  TfrmBoardSelect = class(TForm)
  private
    { Componentes dinámicos }
    FLblTitle    : TLabel;
    FScrollBox   : TVertScrollBox;
    FFlowLayout  : TFlowLayout;
    FBtnConfirm  : TButton;
    FBtnCancel   : TButton;

    { Arrays para controlar el estado visual }
    FImgList     : TArray<TImage>;
    FBorderList  : TArray<TRectangle>;
    FLabelList   : TArray<TLabel>;

    { Datos }
    FBoardImages : TImageList;
    FSelectedIdx : Integer;

    procedure BuildUI;
    procedure BuildBoardGrid;
    procedure LoadBoardImg(Idx: Integer; Img: TImage);
    procedure OnBoardClick(Sender: TObject);
    procedure UpdateSelection(NewIdx: Integer);
    procedure OnConfirmClick(Sender: TObject);
    procedure OnCancelClick(Sender: TObject);
  public
    constructor CreateWithImages(AOwner: TComponent; AImages: TImageList); reintroduce;
    property SelectedIdx: Integer read FSelectedIdx;
  end;

implementation

constructor TfrmBoardSelect.CreateWithImages(AOwner: TComponent; AImages: TImageList);
begin
  inherited CreateNew(AOwner);
  FBoardImages := AImages;
  FSelectedIdx := -1;
  BuildUI;
  BuildBoardGrid;
end;

procedure TfrmBoardSelect.BuildUI;
var
  pnlBottom : TLayout;
begin
  Caption  := 'Seleccionar Tablero';
  Width    := 600; // Un poco más ancho para las miniaturas de tableros
  Height   := 500;
  Position := TFormPosition.ScreenCenter;

  // Título
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent  := Self;
  FLblTitle.Align   := TAlignLayout.Top;
  FLblTitle.Height  := 44;
  FLblTitle.Text    := 'Elige el tablero para jugar';
  FLblTitle.TextSettings.Font.Size  := 15;
  FLblTitle.TextSettings.HorzAlign  := TTextAlign.Center;
  FLblTitle.Margins.Top := 8;

  // Panel inferior
  pnlBottom := TLayout.Create(Self);
  pnlBottom.Parent := Self;
  pnlBottom.Align  := TAlignLayout.Bottom;
  pnlBottom.Height := 54;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent     := pnlBottom;
  FBtnCancel.Text       := 'Cancelar';
  FBtnCancel.Width      := 120;
  FBtnCancel.Position.X := 16;
  FBtnCancel.Position.Y := 12;
  FBtnCancel.OnClick    := OnCancelClick;

  FBtnConfirm := TButton.Create(Self);
  FBtnConfirm.Parent     := pnlBottom;
  FBtnConfirm.Text       := '✓  Confirmar';
  FBtnConfirm.Width      := 120;
  FBtnConfirm.Position.X := Width - 150; // Alinear a la derecha
  FBtnConfirm.Position.Y := 12;
  FBtnConfirm.Enabled    := False;
  FBtnConfirm.OnClick    := OnConfirmClick;

  // ScrollBox
  FScrollBox := TVertScrollBox.Create(Self);
  FScrollBox.Parent := Self;
  FScrollBox.Align  := TAlignLayout.Client;

  // FlowLayout
  FFlowLayout := TFlowLayout.Create(Self);
  FFlowLayout.Parent         := FScrollBox;
  FFlowLayout.Align          := TAlignLayout.Top;
  FFlowLayout.HorizontalGap  := 14;
  FFlowLayout.VerticalGap    := 14;
  FFlowLayout.Padding.Left   := 14;
  FFlowLayout.Padding.Top    := 14;
  FFlowLayout.Padding.Right  := 14;
  FFlowLayout.Padding.Bottom := 14;
end;

procedure TfrmBoardSelect.LoadBoardImg(Idx: Integer; Img: TImage);
var
  Bmp : TBitmap;
  Sz  : TSizeF;
begin
  Sz.Width  := Img.Width;
  Sz.Height := Img.Height;
  Bmp := FBoardImages.Bitmap(Sz, Idx);
  if Assigned(Bmp) then Img.Bitmap.Assign(Bmp);
end;

procedure TfrmBoardSelect.BuildBoardGrid;
var
  i, itemsPerRow, totalRows: Integer;
  lyt    : TLayout;
  img    : TImage;
  border : TRectangle;
  lbl    : TLabel;
begin
  SetLength(FImgList,    FBoardImages.Count);
  SetLength(FBorderList, FBoardImages.Count);
  SetLength(FLabelList,  FBoardImages.Count);

  // ¡Iniciamos en 1 para omitir el Blank_Idx (0)!
  for i := 1 to FBoardImages.Count - 1 do
  begin
    // Contenedor principal: 160x140 px
    lyt        := TLayout.Create(Self);
    lyt.Parent := FFlowLayout;
    lyt.Width  := 160;
    lyt.Height := 140;
    lyt.Tag    := i;
    lyt.OnClick := OnBoardClick;

    // Borde de selección
    border           := TRectangle.Create(Self);
    border.Parent    := lyt;
    border.Align     := TAlignLayout.Client;
    border.Fill.Kind := TBrushKind.None;
    border.Stroke.Color     := TAlphaColorRec.Lime;
    border.Stroke.Thickness := 3;
    border.Visible   := False;
    border.HitTest   := False;
    FBorderList[i]   := border;

    // Imagen del tablero
    img        := TImage.Create(Self);
    img.Parent := lyt;
    img.Width  := 128;
    img.Height := 96;
    img.Position.X := 16;
    img.Position.Y := 10;
    img.Tag        := i;
    img.WrapMode   := TImageWrapMode.Fit; // Ajustar manteniendo proporción
    img.OnClick    := OnBoardClick;
    LoadBoardImg(i, img);
    FImgList[i] := img;

    // Etiqueta del tablero
    lbl        := TLabel.Create(Self);
    lbl.Parent := lyt;
    lbl.Width  := 160;
    lbl.Height := 22;
    lbl.Position.X := 0;
    lbl.Position.Y := 115;
    lbl.TextSettings.HorzAlign := TTextAlign.Center;
    lbl.TextSettings.Font.Size := 12;
    lbl.Text := 'Tablero ' + IntToStr(i);
    lbl.Tag  := i;
    lbl.OnClick := OnBoardClick;
    FLabelList[i] := lbl;
  end;

  itemsPerRow := Max(1, Trunc((Width - 28) / (160 + 14)));
  totalRows   := Ceil((FBoardImages.Count - 1) / itemsPerRow);
  FFlowLayout.Height := (totalRows * (140 + 14)) + 28;
end;

procedure TfrmBoardSelect.OnBoardClick(Sender: TObject);
begin
  UpdateSelection((Sender as TFmxObject).Tag);
end;

procedure TfrmBoardSelect.UpdateSelection(NewIdx: Integer);
begin
  if FSelectedIdx = NewIdx then Exit;

  // Restaurar selección anterior
  if FSelectedIdx > 0 then
  begin
    FBorderList[FSelectedIdx].Visible := False;
    FLabelList[FSelectedIdx].TextSettings.FontColor := TAlphaColorRec.Black;
  end;

  FSelectedIdx := NewIdx;

  // Aplicar nueva selección
  FBorderList[NewIdx].Visible := True;
  FLabelList[NewIdx].TextSettings.FontColor := TAlphaColorRec.Lime;
  FBtnConfirm.Enabled := True;
end;

procedure TfrmBoardSelect.OnConfirmClick(Sender: TObject);
begin
  if FSelectedIdx > 0 then ModalResult := mrOk;
end;

procedure TfrmBoardSelect.OnCancelClick(Sender: TObject);
begin
  FSelectedIdx := -1;
  ModalResult  := mrCancel;
end;

end.
