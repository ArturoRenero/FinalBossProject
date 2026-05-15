unit fAvatarSelectForm;

// Selección de avatares para cada jugador. Implementa el método anti-repetición: una vez seleccionado un avatar queda "marcado" y no puede seleccionarse de nuevo. El Bot selecciona aleatoriamente de los disponibles.

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Objects, FMX.Layouts, FMX.StdCtrls, FMX.ScrollBox,
  System.ImageList, FMX.ImgList;

type
  TfrmAvatarSelect = class(TForm)
  private
    { Componentes dinámicos }
    FLblTitle    : TLabel;
    FScrollBox   : TVertScrollBox;
    FFlowLayout  : TFlowLayout;
    FBtnConfirm  : TButton;
    FBtnCancel   : TButton;

    { Arrays para controlar el estado visual de cada avatar }
    FImgList     : TArray<TImage>;
    FOverlayList : TArray<TRectangle>;
    FBorderList  : TArray<TRectangle>;
    FLabelList   : TArray<TLabel>;

    { Datos }
    FAvatarImages : TImageList;
    FTakenAvatars : TArray<Boolean>;
    FPlayerName   : string;
    FSelectedIdx  : Integer;

    procedure BuildUI;
    procedure BuildAvatarGrid;
    procedure LoadAvatarImg(Idx: Integer; Img: TImage);
    procedure OnAvatarClick(Sender: TObject);
    procedure UpdateSelection(NewIdx: Integer);
    procedure OnConfirmClick(Sender: TObject);
    procedure OnCancelClick(Sender: TObject);
  public
    // Constructor con todos los datos necesarios
    constructor CreateForPlayer(AOwner     : TComponent;
                                AImages    : TImageList;
                                ATaken     : TArray<Boolean>;
                                APlayerName: string); reintroduce;
    property SelectedIdx : Integer read FSelectedIdx;
  end;

implementation

uses
  System.Math;   // Max(), Ceil()

constructor TfrmAvatarSelect.CreateForPlayer(AOwner: TComponent;
  AImages: TImageList; ATaken: TArray<Boolean>; APlayerName: string);
begin
  inherited Create(AOwner);
  FAvatarImages := AImages;
  FTakenAvatars := ATaken;
  FPlayerName   := APlayerName;
  FSelectedIdx  := -1;
  BuildUI;
  BuildAvatarGrid;
end;

procedure TfrmAvatarSelect.BuildUI;
var
  pnlBottom : TLayout;
begin
  Caption  := 'Seleccionar Avatar';
  Width    := 520;
  Height   := 580;
  Position := TFormPosition.ScreenCenter;

  // Título
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent  := Self;
  FLblTitle.Align   := TAlignLayout.Top;
  FLblTitle.Height  := 44;
  FLblTitle.Text    := 'Elige tu avatar, ' + FPlayerName;
  FLblTitle.TextSettings.Font.Size  := 15;
  FLblTitle.TextSettings.HorzAlign  := TTextAlign.Center;
  FLblTitle.Margins.Top := 8;

  // Panel inferior con botones
  pnlBottom := TLayout.Create(Self);
  pnlBottom.Parent := Self;
  pnlBottom.Align  := TAlignLayout.Bottom;
  pnlBottom.Height := 54;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent    := pnlBottom;
  FBtnCancel.Text      := 'Cancelar';
  FBtnCancel.Width     := 120;
  FBtnCancel.Position.X := 16;
  FBtnCancel.Position.Y := 12;
  FBtnCancel.OnClick   := OnCancelClick;

  FBtnConfirm := TButton.Create(Self);
  FBtnConfirm.Parent    := pnlBottom;
  FBtnConfirm.Text      := '✓  Confirmar';
  FBtnConfirm.Width     := 120;
  FBtnConfirm.Position.X := 384;
  FBtnConfirm.Position.Y := 12;
  FBtnConfirm.Enabled   := False;  // se activa cuando hay selección
  FBtnConfirm.OnClick   := OnConfirmClick;

  // ScrollBox para el grid de avatares
  FScrollBox := TVertScrollBox.Create(Self);
  FScrollBox.Parent := Self;
  FScrollBox.Align  := TAlignLayout.Client;

  // FlowLayout dentro del ScrollBox (auto-crece según hijos)
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

procedure TfrmAvatarSelect.LoadAvatarImg(Idx: Integer; Img: TImage);
var
  Bmp : TBitmap;
  Sz  : TSizeF;
begin
  Sz.Width  := Img.Width;
  Sz.Height := Img.Height;
  Bmp := FAvatarImages.Bitmap(Sz, Idx);
  if Bmp <> nil then Img.Bitmap.Assign(Bmp);
end;

procedure TfrmAvatarSelect.BuildAvatarGrid;
var
  i       : Integer;
  isTaken : Boolean;
  lyt     : TLayout;
  img     : TImage;
  overlay : TRectangle;
  border  : TRectangle;
  lbl     : TLabel;
  // ── Al final, después del for, calcular altura del FlowLayout ──
  itemsPerRow : Integer;
  totalRows   : Integer;
begin
  SetLength(FImgList,     FAvatarImages.Count);
  SetLength(FOverlayList, FAvatarImages.Count);
  SetLength(FBorderList,  FAvatarImages.Count);
  SetLength(FLabelList,   FAvatarImages.Count);

  for i := 0 to FAvatarImages.Count - 1 do
  begin
    isTaken := (i < Length(FTakenAvatars)) and FTakenAvatars[i];

    // ── Contenedor de 110x130 px por avatar ──
    lyt        := TLayout.Create(Self);
    lyt.Parent := FFlowLayout;
    lyt.Width  := 110;
    lyt.Height := 130;
    lyt.Tag    := i;
    if not isTaken then
      lyt.OnClick := OnAvatarClick;

    // ── Borde verde de "seleccionado" (oculto por defecto) ──
    border           := TRectangle.Create(Self);
    border.Parent    := lyt;
    border.Align     := TAlignLayout.Client;
    border.Fill.Kind := TBrushKind.None;
    border.Stroke.Color     := TAlphaColorRec.Lime;
    border.Stroke.Thickness := 3;
    border.Visible   := False;
    border.HitTest   := False;
    FBorderList[i]   := border;

    // ── Imagen del avatar ──
    img            := TImage.Create(Self);
    img.Parent     := lyt;
    img.Width      := 86;
    img.Height     := 86;
    img.Position.X := 12;
    img.Position.Y := 8;
    img.Tag        := i;
    img.HitTest    := not isTaken; // si está tomado no captura clicks
    if not isTaken then
      img.OnClick := OnAvatarClick;
    LoadAvatarImg(i, img);
    FImgList[i] := img;

    // ── Overlay oscuro (visible solo si está tomado) ──
    overlay            := TRectangle.Create(Self);
    overlay.Parent     := lyt;
    overlay.Width      := 86;
    overlay.Height     := 86;
    overlay.Position.X := 12;
    overlay.Position.Y := 8;
    overlay.Fill.Color := TAlphaColorRec.Black;
    overlay.Opacity    := 0.62;
    overlay.Visible    := isTaken;
    overlay.HitTest    := False;
    overlay.Stroke.Kind := TBrushKind.None;
    FOverlayList[i]    := overlay;

    // ── Label de estado ──
    lbl            := TLabel.Create(Self);
    lbl.Parent     := lyt;
    lbl.Width      := 110;
    lbl.Height     := 22;
    lbl.Position.X := 0;
    lbl.Position.Y := 100;
    lbl.TextSettings.HorzAlign := TTextAlign.Center;
    lbl.TextSettings.Font.Size := 10;
    lbl.Tag        := i;
    if isTaken then
    begin
      lbl.Text := 'No disponible';
      lbl.TextSettings.FontColor := TAlphaColorRec.Red;
    end
    else
    begin
      lbl.Text := 'Avatar ' + IntToStr(i + 1);
      lbl.TextSettings.FontColor := TAlphaColorRec.Silver;
      lbl.OnClick := OnAvatarClick;
    end;
    FLabelList[i] := lbl;
  end;
  // Calcular cuántos ítems caben por fila y el alto total necesario
  // Ancho disponible = ancho del form - padding izquierdo - padding derecho
  itemsPerRow := Max(1, Trunc((Width - 28) / (110 + 14)));
  totalRows   := Ceil(FAvatarImages.Count / itemsPerRow);

  // Alto total = filas * (alto ítem + gap) + padding top + bottom
  FFlowLayout.Height := (totalRows * (130 + 14)) + 28;
end;

procedure TfrmAvatarSelect.OnAvatarClick(Sender: TObject);
var
  idx : Integer;
begin
  idx := (Sender as TFmxObject).Tag;
  if (idx < Length(FTakenAvatars)) and FTakenAvatars[idx] then Exit;
  UpdateSelection(idx);
end;

procedure TfrmAvatarSelect.UpdateSelection(NewIdx: Integer);
begin
  // Quitar selección anterior
  if FSelectedIdx >= 0 then
  begin
    FBorderList[FSelectedIdx].Visible := False;
    FLabelList[FSelectedIdx].Text     := 'Avatar ' + IntToStr(FSelectedIdx + 1);
    FLabelList[FSelectedIdx].TextSettings.FontColor := TAlphaColorRec.Silver;
  end;

  FSelectedIdx := NewIdx;

  // Aplicar selección nueva
  FBorderList[NewIdx].Visible := True;
  FLabelList[NewIdx].Text     := '✓ Seleccionado';
  FLabelList[NewIdx].TextSettings.FontColor := TAlphaColorRec.Lime;

  FBtnConfirm.Enabled := True;
end;

procedure TfrmAvatarSelect.OnConfirmClick(Sender: TObject);
begin
  if FSelectedIdx >= 0 then ModalResult := mrOk;
end;

procedure TfrmAvatarSelect.OnCancelClick(Sender: TObject);
begin
  FSelectedIdx := -1;
  ModalResult  := mrCancel;
end;

end.
