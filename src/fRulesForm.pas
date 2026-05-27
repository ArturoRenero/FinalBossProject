unit fRulesForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, FMX.Layouts;

type
  TfrmRules = class(TForm)
  private
    FMemRules: TMemo;
    FLblTitle: TLabel;
    FBtnClose: TButton;
    procedure BuildUI;
    procedure btnCloseClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure CargarReglas(BoardIndex: Integer);
  end;

var
  frmRules: TfrmRules; // Instancia global para evitar crear múltiples copias

implementation

constructor TfrmRules.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner); // CreateNew evita que Delphi busque el archivo .fmx
  BuildUI;
end;

procedure TfrmRules.BuildUI;
var
  pnlBottom: TLayout;
begin
  Caption := 'Reglas del Juego';
  Width := 400;
  Height := 500;
  Position := TFormPosition.ScreenCenter;

  // Título
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := Self;
  FLblTitle.Align := TAlignLayout.Top;
  FLblTitle.Height := 44;
  FLblTitle.Text := 'Reglas Oficiales';
  FLblTitle.TextSettings.Font.Size := 15;
  FLblTitle.TextSettings.HorzAlign := TTextAlign.Center;
  FLblTitle.Margins.Top := 8;

  // Contenedor inferior
  pnlBottom := TLayout.Create(Self);
  pnlBottom.Parent := Self;
  pnlBottom.Align := TAlignLayout.Bottom;
  pnlBottom.Height := 54;

  // Botón cerrar
  FBtnClose := TButton.Create(Self);
  FBtnClose.Parent := pnlBottom;
  FBtnClose.Text := 'Cerrar';
  FBtnClose.Width := 120;
  FBtnClose.Position.X := (Width - 120) / 2; // Centrado
  FBtnClose.Position.Y := 12;
  FBtnClose.OnClick := btnCloseClick;

  // Memo de texto
  FMemRules := TMemo.Create(Self);
  FMemRules.Parent := Self;
  FMemRules.Align := TAlignLayout.Client;
  FMemRules.Margins.Left := 16;
  FMemRules.Margins.Right := 16;
  FMemRules.Margins.Bottom := 8;
  FMemRules.ReadOnly := True;
  FMemRules.TextSettings.Font.Size := 13;
end;

procedure TfrmRules.CargarReglas(BoardIndex: Integer);
begin
  FMemRules.Lines.Clear;
  FMemRules.Lines.Add('🦆 De Oca a Oca: Avanzas a la siguiente Oca y vuelves a tirar.');
  FMemRules.Lines.Add('🌉 El Puente (Casillas 6 y 12): Avanzas o retrocedes al otro puente.');
  FMemRules.Lines.Add('🏨 La Posada (Casilla 19): Pierdes 1 turno descansando.');
  FMemRules.Lines.Add('🕳 El Pozo (Casilla 31): No puedes jugar hasta que otro jugador caiga en el pozo y te rescate.');
  FMemRules.Lines.Add('💀 La Calavera (Casilla 58): Regresas a la casilla 1.');
  FMemRules.Lines.Add('🏆 Victoria: Debes caer exactamente en la casilla 63.');

  if BoardIndex = 1 then
  begin
    FMemRules.Lines.Add('');
    FMemRules.Lines.Add('🔥 Regla Especial Tablero 2: Las ocas son de lava...');
  end;
end;

procedure TfrmRules.btnCloseClick(Sender: TObject);
begin
  Hide;
end;

end.
