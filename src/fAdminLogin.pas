unit fAdminLogin;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Edit, FMX.Layouts, FMX.Objects;

type
  TfrmAdminLogin = class(TForm)
  private
    FLblTitle: TLabel;
    FEdtUser: TEdit;
    FEdtPass: TEdit;
    FBtnLogin: TButton;
    FBtnCancel: TButton;

    procedure BuildUI;
    procedure btnLoginClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

constructor TfrmAdminLogin.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  BuildUI;
end;

procedure TfrmAdminLogin.BuildUI;
var
  rectBG: TRectangle;
  lblUser, lblPass: TLabel;
begin
  Caption := 'Acceso de Desarrollador';
  Width := 350;
  Height := 350;
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.Single;

  // Fondo Naranja
  rectBG := TRectangle.Create(Self);
  with rectBG do
  begin
    Parent := Self; Align := TAlignLayout.Client;
    Fill.Color := $FFFFAE1D; Stroke.Kind := TBrushKind.None;
  end;

  // Título
  FLblTitle := TLabel.Create(Self);
  with FLblTitle do
  begin
    Parent := rectBG; Align := TAlignLayout.Top; Height := 50; Margins.Top := 20;
    Text := 'Modo Administrador';
    TextSettings.Font.Size := 20; TextSettings.Font.Style := [TFontStyle.fsBold];
    TextSettings.HorzAlign := TTextAlign.Center;
  end;

  // Usuario
  lblUser := TLabel.Create(Self);
  with lblUser do
  begin
    Parent := rectBG; Position.Point := TPointF.Create(40, 80);
    Text := 'Usuario:'; TextSettings.Font.Style := [TFontStyle.fsBold];
  end;

  FEdtUser := TEdit.Create(Self);
  with FEdtUser do
  begin
    Parent := rectBG; Position.Point := TPointF.Create(40, 105);
    Width := 250; Height := 32;
  end;

  // Contraseña
  lblPass := TLabel.Create(Self);
  with lblPass do
  begin
    Parent := rectBG; Position.Point := TPointF.Create(40, 150);
    Text := 'Contraseña:'; TextSettings.Font.Style := [TFontStyle.fsBold];
  end;

  FEdtPass := TEdit.Create(Self);
  with FEdtPass do
  begin
    Parent := rectBG; Position.Point := TPointF.Create(40, 175);
    Width := 250; Height := 32;
    Password := True; // ¡Oculta los caracteres!
  end;

  // Botones
  FBtnLogin := TButton.Create(Self);
  with FBtnLogin do
  begin
    Parent := rectBG; Position.Point := TPointF.Create(40, 230);
    Width := 115; Height := 40; Text := 'Acceder';
    OnClick := btnLoginClick;
  end;

  FBtnCancel := TButton.Create(Self);
  with FBtnCancel do
  begin
    Parent := rectBG; Position.Point := TPointF.Create(175, 230);
    Width := 115; Height := 40; Text := 'Cancelar';
    OnClick := btnCancelClick;
  end;
end;

procedure TfrmAdminLogin.btnLoginClick(Sender: TObject);
begin
  // ── CREDENCIALES DE ACCESO ──
  if (Trim(FEdtUser.Text) = 'admin') and (Trim(FEdtPass.Text) = '1234') then
  begin
    ModalResult := mrOk;
  end
  else
  begin
    ShowMessage('Credenciales incorrectas. Acceso denegado.');
    FEdtPass.Text := '';
  end;
end;

procedure TfrmAdminLogin.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
