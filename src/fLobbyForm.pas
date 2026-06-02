unit fLobbyForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Edit, FMX.Layouts, FMX.Objects,
  System.Bluetooth, FMX.Listbox; // Listbox añadido para el ComboBox

type
  TfrmLobby = class(TForm)
  private
    FLblTitle: TLabel;

    FRbLAN: TRadioButton;
    FRbBT: TRadioButton;

    FEdtName: TEdit;
    FEdtIP: TEdit;
    FCboDevices: TComboBox;
    FCboPlayers: TComboBox; // <-- NUEVO: Selector de Jugadores/Asiento

    FBtnHost: TButton;
    FBtnJoin: TButton;
    FBtnCancel: TButton;

    FIsHost: Boolean;
    FUseBluetooth: Boolean;
    FPlayerName: string;
    FHostIP: string;
    FBluetoothDeviceName: string;
    FSelectedNumber: Integer; // <-- NUEVO: Guardará si eligieron 2, 3 o 4

    procedure BuildUI;
    procedure LoadBluetoothDevices;
    procedure OnNetworkTypeChange(Sender: TObject);

    procedure btnHostClick(Sender: TObject);
    procedure btnJoinClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;

    property IsHost: Boolean read FIsHost;
    property UseBluetooth: Boolean read FUseBluetooth;
    property PlayerName: string read FPlayerName;
    property HostIP: string read FHostIP;
    property BluetoothDeviceName: string read FBluetoothDeviceName;
    property SelectedNumber: Integer read FSelectedNumber; // Exponemos el valor
  end;

implementation

constructor TfrmLobby.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  FIsHost := False;
  FUseBluetooth := False;
  FPlayerName := '';
  FHostIP := '';
  FBluetoothDeviceName := '';
  FSelectedNumber := 2;
  BuildUI;
end;

procedure TfrmLobby.BuildUI;
var
  lytName, lytNetworkType, lytConnection, lytPlayers, lytButtons: TLayout;
  lblInfoName, lblInfoConn, lblInfoPlayers: TLabel;
  rectBG: TRectangle;
begin
  Caption := 'Lobby Multijugador';
  Width := 400;
  Height := 560; // Aumentamos la altura para que quepa el nuevo combo
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.Single;

  rectBG := TRectangle.Create(Self);
  with rectBG do
  begin
    Parent := Self;
    Align := TAlignLayout.Client;
    Fill.Color := $FFFFAE1D; // quiero usar este color, no el azul anterior
    Stroke.Kind := TBrushKind.None;
  end;

  FLblTitle := TLabel.Create(Self);
  with FLblTitle do
  begin
    Parent := rectBG;
    Align := TAlignLayout.Top;
    Height := 50;
    Margins.Top := 15;
    Text := 'Multijugador';
    TextSettings.Font.Size := 22;
    TextSettings.Font.Style := [TFontStyle.fsBold];
    TextSettings.HorzAlign := TTextAlign.Center;
    TextSettings.FontColor := TAlphaColorRec.White;
  end;

  // ── 1. Selector de Tipo de Red ──
  lytNetworkType := TLayout.Create(Self);
  with lytNetworkType do
  begin
    Parent := rectBG;
    Align := TAlignLayout.Top;
    Height := 40;
    Margins.Top := 10;
  end;

  FRbLAN := TRadioButton.Create(Self);
  with FRbLAN do
  begin
    Parent := lytNetworkType;
    Position.Point := TPointF.Create(80, 10);
    Text := 'LAN / WiFi';
    IsChecked := True;
    TextSettings.FontColor := TAlphaColorRec.White;
    OnChange := OnNetworkTypeChange;
  end;

  FRbBT := TRadioButton.Create(Self);
  with FRbBT do
  begin
    Parent := lytNetworkType;
    Position.Point := TPointF.Create(220, 10);
    Text := 'Bluetooth';
    TextSettings.FontColor := TAlphaColorRec.White;
    OnChange := OnNetworkTypeChange;
  end;

  // ── 2. Nombre del Jugador ──
  lytName := TLayout.Create(Self);
  with lytName do
  begin
    Parent := rectBG;
    Align := TAlignLayout.Top;
    Height := 75;
  end;

  lblInfoName := TLabel.Create(Self);
  with lblInfoName do
  begin
    Parent := lytName;
    Position.Point := TPointF.Create(40, 10);
    Width := 300;
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

  // ── NUEVO: 3. Selector de Jugadores / Asientos ──
  lytPlayers := TLayout.Create(Self);
  with lytPlayers do
  begin
    Parent := rectBG;
    Align := TAlignLayout.Top;
    Height := 75;
  end;

  lblInfoPlayers := TLabel.Create(Self);
  with lblInfoPlayers do
  begin
    Parent := lytPlayers;
    Position.Point := TPointF.Create(40, 10);
    Width := 300;
    Text := 'Total Jugadores (Host) / Tu Asiento (Cliente):';
    TextSettings.FontColor := TAlphaColorRec.White;
  end;

  FCboPlayers := TComboBox.Create(Self);
  with FCboPlayers do
  begin
    Parent := lytPlayers;
    Position.Point := TPointF.Create(40, 35);
    Width := 300;
    Height := 32;
    Items.Add('2 Jugadores / Asiento 2');
    Items.Add('3 Jugadores / Asiento 3');
    Items.Add('4 Jugadores / Asiento 4');
    ItemIndex := 0; // Por defecto es 2
  end;

  // ── 4. Datos de Conexión ──
  lytConnection := TLayout.Create(Self);
  with lytConnection do
  begin
    Parent := rectBG;
    Align := TAlignLayout.Top;
    Height := 80;
    Margins.Top := 10;
  end;

  lblInfoConn := TLabel.Create(Self);
  with lblInfoConn do
  begin
    Parent := lytConnection;
    Position.Point := TPointF.Create(40, 10);
    Width := 300;
    Text := 'Si vas a unirte (Cliente), ingresa los datos:';
    TextSettings.FontColor := TAlphaColorRec.White;
  end;

  FEdtIP := TEdit.Create(Self);
  with FEdtIP do
  begin
    Parent := lytConnection;
    Position.Point := TPointF.Create(40, 35);
    Width := 300;
    Height := 32;
    TextPrompt := 'IP del Host (Ej. 192.168.1.100 o 127.0.0.1)';
  end;

  FCboDevices := TComboBox.Create(Self);
  with FCboDevices do
  begin
    Parent := lytConnection;
    Position.Point := TPointF.Create(40, 35);
    Width := 300;
    Height := 32;
    Visible := False;
  end;

  // ── 5. Botones ──
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
end;

procedure TfrmLobby.OnNetworkTypeChange(Sender: TObject);
begin
  FEdtIP.Visible := FRbLAN.IsChecked;
  FCboDevices.Visible := FRbBT.IsChecked;
  if FRbBT.IsChecked then LoadBluetoothDevices;
end;

procedure TfrmLobby.LoadBluetoothDevices;
var
  BTManager: TBluetoothManager;
  Devices: TBluetoothDeviceList;
  i: Integer;
begin
  FCboDevices.Items.Clear;
  try
    BTManager := TBluetoothManager.Current;
    if Assigned(BTManager) and (BTManager.ConnectionState = TBluetoothConnectionState.Connected) then
    begin
      Devices := BTManager.GetPairedDevices;
      for i := 0 to Devices.Count - 1 do
        FCboDevices.Items.Add(Devices[i].DeviceName);

      if FCboDevices.Items.Count > 0 then
        FCboDevices.ItemIndex := 0
      else
        FCboDevices.Items.Add('No hay dispositivos emparejados');
    end
    else
      FCboDevices.Items.Add('Bluetooth apagado o bloqueado');
  except
    on E: Exception do
      FCboDevices.Items.Add('Sin permisos de Android');
  end;

  FCboDevices.ItemIndex := 0;
end;

procedure TfrmLobby.btnHostClick(Sender: TObject);
begin
  if Trim(FEdtName.Text) = '' then Exit;

  FIsHost := True;
  FUseBluetooth := FRbBT.IsChecked;
  FPlayerName := Trim(FEdtName.Text);
  // +2 porque el ItemIndex 0 corresponde a "2 Jugadores"
  FSelectedNumber := FCboPlayers.ItemIndex + 2;
  ModalResult := mrOk;
end;

procedure TfrmLobby.btnJoinClick(Sender: TObject);
begin
  if Trim(FEdtName.Text) = '' then Exit;

  FIsHost := False;
  FUseBluetooth := FRbBT.IsChecked;
  FPlayerName := Trim(FEdtName.Text);
  FSelectedNumber := FCboPlayers.ItemIndex + 2;

  if FUseBluetooth then
    FBluetoothDeviceName := FCboDevices.Selected.Text
  else
    FHostIP := Trim(FEdtIP.Text);

  ModalResult := mrOk;
end;

procedure TfrmLobby.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
