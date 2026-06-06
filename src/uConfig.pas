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
//    Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'LaOCA.db');

    // ══════════════════════════════════════════════════════════════════════
    // MODO DESARROLLO (Para ti):
    // Como tu .exe compila en el RAM Disk (R:\), usamos la ruta absoluta
    // para que lea directamente la carpeta 'data' de tu proyecto original.

    // ↓↓↓ CAMBIA ESTA RUTA POR LA RUTA REAL DE TU CARPETA ↓↓↓
    Result := 'C:\Users\Cabre\OneDrive\Documentos\Embarcadero\Studio\Projects\LaOca\FinalBossProject\data\goose.db';

    // ══════════════════════════════════════════════════════════════════════
    // MODO PRODUCCIÓN (Para cuando le pases el juego a tus amigos):
    // Cuando les pases el juego, les darás un .zip con el .exe y la
    // carpeta "data" al lado. Comenta la línea de arriba y descomenta esta:
    // Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'data\goose.db');
    // ══════════════════════════════════════════════════════════════════════

  {$ELSE}
  // Android, iOS, Mac
    Result := TPath.Combine(TPath.GetDocumentsPath, 'LaOCA.db');

  {$ENDIF}
end;

end.
