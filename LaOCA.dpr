program LaOCA;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMain in 'uMain.pas' {frmMain},
  uTypes in 'src\uTypes.pas',
  uDatabase in 'src\uDatabase.pas',
  uBoardManager in 'src\uBoardManager.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
