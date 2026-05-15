program LaOCA;

uses
  System.StartUpCopy,
  FMX.Forms,
  fMain in 'fMain.pas' {frmMain},
  uTypes in 'src\uTypes.pas',
  uDatabase in 'src\uDatabase.pas',
  uBoardManager in 'src\uBoardManager.pas',
  uDiceForm in 'src\uDiceForm.pas',
  uBoardSelectForm in 'src\uBoardSelectForm.pas',
  fRulesForm in 'src\fRulesForm.pas',
  uConfigForm in 'src\uConfigForm.pas',
  uGameEngine in 'src\uGameEngine.pas',
  uTurnManager in 'src\uTurnManager.pas',
  uPlayerManager in 'src\uPlayerManager.pas',
  uRulesEngine in 'src\uRulesEngine.pas',
  uBotAI in 'src\uBotAI.pas',
  uSaveManager in 'src\uSaveManager.pas',
  uNetworkManager in 'src\uNetworkManager.pas',
  uBluetoothManager in 'src\uBluetoothManager.pas',
  fAvatarSelectForm in 'src\fAvatarSelectForm.pas' {frmAvatarSelect};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
//  Application.CreateForm(TfrmAvatarSelect, frmAvatarSelect); // Ya se crea el form desde fMain "frm := TfrmAvatarSelect.CreateForPlayer(...)"
  Application.Run;
end.
