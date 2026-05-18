unit fConfigForm;

// Panel de configuración: Pausar / Reanudar / Guardar / Reiniciar / Menú principal. También incluye la herramienta de definición de coordenadas de casillas (OnMouseMove + DoubleClick sobre el tablero).

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics,
  FMX.Objects, FMX.Layouts, FMX.StdCtrls,
  FMX.Dialogs,      // ← ShowMessage vive aquí
  uTypes, uBoardManager;

type
  TfrmConfig = class(TForm)
  private
    FBoardManager : TBoardManager;
    FBoardIdx     : Integer;
    FLastX, FLastY: Single;

    // Componentes (creados en BuildUI)
    FImgBoard   : TImage;
    FLblMouse   : TLabel;   // coordenadas en tiempo real
    FLblProgress: TLabel;   // "Casilla N/63 definida"
    FBtnStart   : TButton;
    FBtnSave    : TButton;
    FBtnClose   : TButton;

    procedure BuildUI;
    procedure OnBoardMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure OnBoardDblClick(Sender: TObject);
    procedure OnStartClick(Sender: TObject);
    procedure OnSaveClick(Sender: TObject);
    procedure OnCloseClick(Sender: TObject);
  public
    constructor CreateForBoard(AOwner: TComponent; ABoardManager: TBoardManager; ABoardIdx: Integer); reintroduce;
  end;

implementation

constructor TfrmConfig.CreateForBoard(AOwner: TComponent;
  ABoardManager: TBoardManager; ABoardIdx: Integer);
begin
  inherited CreateNew(AOwner);
  FBoardManager := ABoardManager;
  FBoardIdx     := ABoardIdx;
  FLastX        := 0;
  FLastY        := 0;
  BuildUI;

  // Cargar la imagen del tablero seleccionado
  FBoardManager.LoadBoardIntoImage(FBoardIdx, FImgBoard);
end;

procedure TfrmConfig.BuildUI;
var
  pnlBottom : TLayout;
  pnlTop    : TLayout;
begin
  Caption  := Format('Admin — Coordenadas Tablero %d', [FBoardIdx]);
  Width    := 900;
  Height   := 700;
  Position := TFormPosition.ScreenCenter;

  // ── Panel superior: info ──────────────────────────────────────
  pnlTop := TLayout.Create(Self);
  pnlTop.Parent := Self;
  pnlTop.Align  := TAlignLayout.Top;
  pnlTop.Height := 36;

  FLblMouse := TLabel.Create(Self);
  FLblMouse.Parent := pnlTop;
  FLblMouse.Align  := TAlignLayout.Left;
  FLblMouse.Width  := 240;
  FLblMouse.Text   := 'Mouse: (0, 0)';
  FLblMouse.Margins.Left := 8;

  FLblProgress := TLabel.Create(Self);
  FLblProgress.Parent := pnlTop;
  FLblProgress.Align  := TAlignLayout.Client;
  FLblProgress.Text   := 'Presiona "Iniciar Captura" y haz doble click en cada casilla';
  FLblProgress.TextSettings.HorzAlign := TTextAlign.Center;

  // ── Imagen del tablero (centro) ───────────────────────────────
  FImgBoard := TImage.Create(Self);
  FImgBoard.Parent    := Self;
  FImgBoard.Align     := TAlignLayout.Client;
  FImgBoard.WrapMode  := TImageWrapMode.Fit;
  FImgBoard.HitTest   := True;
  FImgBoard.OnMouseMove := OnBoardMouseMove;
  FImgBoard.OnDblClick  := OnBoardDblClick;

  // ── Panel inferior: botones ───────────────────────────────────
  pnlBottom := TLayout.Create(Self);
  pnlBottom.Parent := Self;
  pnlBottom.Align  := TAlignLayout.Bottom;
  pnlBottom.Height := 52;

  FBtnStart := TButton.Create(Self);
  FBtnStart.Parent    := pnlBottom;
  FBtnStart.Text      := '►  Iniciar Captura';
  FBtnStart.Width     := 160;
  FBtnStart.Position.X := 16;
  FBtnStart.Position.Y := 10;
  FBtnStart.OnClick   := OnStartClick;

  FBtnSave := TButton.Create(Self);
  FBtnSave.Parent    := pnlBottom;
  FBtnSave.Text      := '💾  Guardar';
  FBtnSave.Width     := 140;
  FBtnSave.Position.X := 192;
  FBtnSave.Position.Y := 10;
  FBtnSave.Enabled   := False;
  FBtnSave.OnClick   := OnSaveClick;

  FBtnClose := TButton.Create(Self);
  FBtnClose.Parent    := pnlBottom;
  FBtnClose.Text      := 'Cerrar';
  FBtnClose.Width     := 100;
  FBtnClose.Position.X := 784;
  FBtnClose.Position.Y := 10;
  FBtnClose.OnClick   := OnCloseClick;
end; // BuildUI

procedure TfrmConfig.OnBoardMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  FLastX := X;
  FLastY := Y;
  // X, Y ya son locales al FImgBoard — relativas, no absolutas
  FLblMouse.Text := Format('Mouse: (%.1f, %.1f)', [X, Y]);
end;

procedure TfrmConfig.OnBoardDblClick(Sender: TObject);
begin
  if not FBoardManager.IsCapturing then Exit;

  // RecordCell recibe X,Y locales al imgBoard y los normaliza internamente
  FBoardManager.RecordCell(FLastX, FLastY);

  FLblProgress.Text := Format('Casilla %d/%d definida: (%.1f, %.1f)', [FBoardManager.CaptureProgress, MAX_CELLS, FLastX, FLastY]);

  // Al llegar a 63 casillas, habilitar el botón Guardar (NOTA: Guarda las coordenadas de cada casilla, no el estado del juego)
  if FBoardManager.CaptureProgress >= MAX_CELLS then
  begin
    FBtnSave.Enabled  := True;
    FBtnStart.Enabled := False;
    FLblProgress.Text := Format('✓ %d casillas capturadas. Presiona Guardar.', [MAX_CELLS]);
  end;
end;

procedure TfrmConfig.OnStartClick(Sender: TObject);
begin
  // Pasar las dimensiones ACTUALES del imgBoard para normalización
  FBoardManager.StartCapture(FBoardIdx, FImgBoard.Width, FImgBoard.Height);
  FLblProgress.Text := Format('Capturando Tablero %d — doble click en casilla 1/%d', [FBoardIdx, MAX_CELLS]);
  FBtnSave.Enabled  := False;
  FBtnStart.Enabled := False;  // evitar re-iniciar durante la captura
end;

procedure TfrmConfig.OnSaveClick(Sender: TObject);
begin
  FBoardManager.FinishCapture;
  ShowMessage(Format('Tablero %d guardado correctamente (%d casillas).', [FBoardIdx, MAX_CELLS]));
  FBtnSave.Enabled  := False;
  FBtnStart.Enabled := True;
  FLblProgress.Text := 'Guardado. Puedes iniciar otra captura.';
end;

procedure TfrmConfig.OnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
