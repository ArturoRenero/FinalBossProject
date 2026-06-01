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
  Height := 550; // Aumentamos un poco la altura para que luzca mejor
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
  FMemRules.WordWrap := True; // ¡VITAL! Para que los textos largos bajen a la siguiente línea
  FMemRules.TextSettings.Font.Size := 13;
end;

procedure TfrmRules.CargarReglas(BoardIndex: Integer);
begin
  FMemRules.Lines.Clear;

  // 1. Ocas
  FMemRules.Lines.Add('🦆 De Oca a Oca (Casillas 5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59):');
  FMemRules.Lines.Add('   Ganas un turno extra. (¡De Oca a Oca y tiro porque me toca!).');
  FMemRules.Lines.Add('');

  // 2. Puentes
  FMemRules.Lines.Add('🌉 Los Puentes (Casillas 6 y 12):');
  FMemRules.Lines.Add('   Avanzas o retrocedes al otro puente y vuelves a tirar.');
  FMemRules.Lines.Add('');

  // 3. Posada
  FMemRules.Lines.Add('🏨 La Posada (Casilla 19):');
  FMemRules.Lines.Add('   Pierdes 1 turno descansando.');
  FMemRules.Lines.Add('');

  // 7. Dados
  FMemRules.Lines.Add('🎲 Los Dados (Casillas 26 y 53):');
  FMemRules.Lines.Add('   Avanzas o retrocedes a la otra casilla de dados y vuelves a tirar.');
  FMemRules.Lines.Add('');

  // 4. Pozo
  FMemRules.Lines.Add('🕳 El Pozo (Casilla 31):');
  FMemRules.Lines.Add('   ¡Caíste al pozo! Pierdes 2 turnos.');
  FMemRules.Lines.Add('');

  // 5. Laberinto
  FMemRules.Lines.Add('🗺 El Laberinto (Casilla 42):');
  FMemRules.Lines.Add('   Te perdiste en el Laberinto. Retrocedes a la casilla 30.');
  FMemRules.Lines.Add('');

  // 6. Cárcel
  FMemRules.Lines.Add('⛓ La Cárcel (Casilla 56):');
  FMemRules.Lines.Add('   ¡A la cárcel! Pierdes 3 turnos.');
  FMemRules.Lines.Add('');

  // 8. Calavera
  FMemRules.Lines.Add('💀 La Calavera (Casilla 58):');
  FMemRules.Lines.Add('   ¡Muerte! Regresas a la casilla de salida (1).');
  FMemRules.Lines.Add('');

  // Victoria
  FMemRules.Lines.Add('🏆 Victoria:');
  FMemRules.Lines.Add('   Debes caer exactamente en la casilla 63. Si sacas de más, rebotas hacia atrás la cantidad sobrante.');

  // Reglas exclusivas por tablero
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
