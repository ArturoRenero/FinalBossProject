unit uConfig;

// ============================================================
//  CONFIGURACIÓN LOCAL DEL PROYECTO
//  Cada desarrollador/usuario ajusta estas constantes
//  según la estructura de carpetas de su equipo.
// ============================================================

interface

uses
  System.IOUtils, System.SysUtils;

function GetDBPath: string;

implementation

function GetDBPath: string;
begin
  // Ubicacion de la BD
  {$IF DEFINED (MSWINDOWS)}
  // Windows
    // Ruta absoluta a la base de datos del juego.
    // Cambia esta línea a la ruta correspondiente en tu equipo.
    Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'LaOCA.db');

  // Si compilamos para Windows
  {$ELSE}
  // Android, iOS, Mac
    Result := TPath.Combine(TPath.GetDocumentsPath, 'LaOCA.db');

  {$ENDIF}
end;

end.
