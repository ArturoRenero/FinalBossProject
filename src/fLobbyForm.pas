unit fLobbyForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Edit, FMX.Layouts, FMX.Objects;

type
  TfrmLobby = class(TForm)
  private
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;

    // Inputs
    FEdtName: TEdit;
    FEdtIP: TEdit;

    // Botones
    FBtnHost: TButton;
    FBtnJoin: TButton;
    FBtnCancel: TButton;

    // Resultados que leeremos desde fMain
    FIsHost: Boolean;
    FPlayerName: string;
    FHostIP: string;

    procedure BuildUI;
    procedure btnHostClick(Sender: TObject);
    procedure btnJoinClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;

    // Propiedades de solo lectura para acceder desde fuera
    property IsHost: Boolean read FIsHost;
    property PlayerName: string read FPlayerName;
    property HostIP: string read FHostIP;
  end;

implementation

constructor TfrmLobby.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner); // Ignorar archivo .fmx
  FIsHost := False;
  FPlayerName := '';
  FHostIP := '';
  BuildUI;
end;

procedure TfrmLobby.BuildUI;
var
  lytName, lytNetwork, lytButtons: TLayout;
  lblInfoName, lblInfoIP: TLabel;
  rectBG: TRectangle;
begin
  Caption := 'Lobby Multijugador';
  Width := 400;
  Height := 450;
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.Single;

  rectBG := TRectangle.Create(Self);
  with rectBG do
  begin
    Parent := Self;
    Align := TAlignLayout.Client;
    Fill.Color := $FFFFAE1D; // usan 8 caracteres porque incluyen el canal Alfa (Transparencia) al principio (ARGB)
    Stroke.Kind := TBrushKind.None;
  end;

  // Título
  FLblTitle := TLabel.Create(Self);
  with FLblTitle do
  begin
    Parent := rectBG;
    Align := TAlignLayout.Top;
    Height := 50;
    Margins.Top := 20;
    Text := 'Multijugador LAN / WiFi';
    TextSettings.Font.Size := 20;
    TextSettings.Font.Style := [TFontStyle.fsBold];
    TextSettings.HorzAlign := TTextAlign.Center;
    TextSettings.FontColor := TAlphaColorRec.White;
  end;

  // Sección 1: Nombre del Jugador
  lytName := TLayout.Create(Self);
  with lytName do
  begin
    Parent := rectBG;
    Align := TAlignLayout.Top;
    Height := 80;
    Margins.Top := 10;
  end;

  lblInfoName := TLabel.Create(Self);
  with lblInfoName do
  begin
    Parent := lytName;
    Position.Point := TPointF.Create(40, 10);
    Width := 300; // ¡SOLUCIÓN AL TEXTO CORTADO!
    Text := 'Tu Nombre de Jugador:';
    TextSettings.FontColor := TAlphaColorRec.White;
  end;

  FEdtName := TEdit.Create(Self);
  with FEdtName do
  begin
    Parent := lytName;
    Position.Point := TPointF.Create(40, 35);
    Width := 300;
    Height := 32;
    Text := 'Jugador ' + IntToStr(Random(99) + 1);
  end;

  // Sección 2: Conexión
  lytNetwork := TLayout.Create(Self);
  with lytNetwork do
  begin
    Parent := rectBG;
    Align := TAlignLayout.Top;
    Height := 100;
    Margins.Top := 20;
  end;

  lblInfoIP := TLabel.Create(Self);
  with lblInfoIP do
  begin
    Parent := lytNetwork;
    Position.Point := TPointF.Create(40, 10);
    Width := 300; // ¡SOLUCIÓN AL TEXTO CORTADO!
    Text := 'Si vas a unirte, escribe la IP del Host:';
    TextSettings.FontColor := TAlphaColorRec.White;
  end;

  FEdtIP := TEdit.Create(Self);
  with FEdtIP do
  begin
    Parent := lytNetwork;
    Position.Point := TPointF.Create(40, 35);
    Width := 300;
    Height := 32;
    TextPrompt := 'Ej. 192.168.1.100';
  end;

  // Sección 3: Botones
  lytButtons := TLayout.Create(Self);
  with lytButtons do
  begin
    Parent := rectBG;
    Align := TAlignLayout.Bottom;
    Height := 120;
  end;

  FBtnHost := TButton.Create(Self);
  with FBtnHost do
  begin
    Parent := lytButtons;
    Position.Point := TPointF.Create(40, 10);
    Width := 145;
    Height := 40;
    Text := 'Crear Partida (Host)';
    OnClick := btnHostClick;
  end;

  FBtnJoin := TButton.Create(Self);
  with FBtnJoin do
  begin
    Parent := lytButtons;
    Position.Point := TPointF.Create(195, 10);
    Width := 145;
    Height := 40;
    Text := 'Unirse (Cliente)';
    OnClick := btnJoinClick;
  end;

  FBtnCancel := TButton.Create(Self);
  with FBtnCancel do
  begin
    Parent := lytButtons;
    Position.Point := TPointF.Create(120, 60);
    Width := 145;
    Height := 35;
    Text := 'Cancelar';
    OnClick := btnCancelClick;
  end;
end; // BuildUI()

procedure TfrmLobby.btnHostClick(Sender: TObject);
begin
  if Trim(FEdtName.Text) = '' then
  begin
    ShowMessage('Por favor escribe un nombre.');
    Exit;
  end;

  FIsHost := True;
  FPlayerName := Trim(FEdtName.Text);
  ModalResult := mrOk; // Cerramos el form indicando éxito
end;

procedure TfrmLobby.btnJoinClick(Sender: TObject);
begin
  if Trim(FEdtName.Text) = '' then
  begin
    ShowMessage('Por favor escribe un nombre.');
    Exit;
  end;

  if Trim(FEdtIP.Text) = '' then
  begin
    ShowMessage('Debes escribir la IP de la computadora Host para unirte.');
    Exit;
  end;

  FIsHost := False;
  FPlayerName := Trim(FEdtName.Text);
  FHostIP := Trim(FEdtIP.Text);
  ModalResult := mrOk; // Cerramos el form indicando éxito
end;

procedure TfrmLobby.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
