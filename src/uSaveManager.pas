unit uSaveManager;

 // Serializa y deserializa el estado completo de la partida (posiciones, turno actual, tablero, avatares) hacia/desde SQLite. Verifica al arrancar si hay una partida guardada. Solo existe 1 slot de guardado (sobreescribe).

interface

uses
  System.SysUtils, System.JSON, uDatabase, uGameEngine;

type
  TSaveManager = class
  public
    // Métodos de clase (no requieren ser instanciados)
    class procedure GuardarPartida(Engine: TGameEngine; DB: TDatabase);
    class function CargarPartida(Engine: TGameEngine; DB: TDatabase): Boolean;
    class procedure BorrarPartida(DB: TDatabase);
    class function HayPartidaGuardada(DB: TDatabase): Boolean;
  end;

implementation

class procedure TSaveManager.GuardarPartida(Engine: TGameEngine; DB: TDatabase);
begin
  if Assigned(Engine) and Assigned(DB) then
    // Usamos el ExportStateToJSON que creamos para la red, ¡sirve perfecto para el disco!
    DB.SaveGame(Engine.ExportStateToJSON);
end;

class function TSaveManager.CargarPartida(Engine: TGameEngine; DB: TDatabase): Boolean;
var
  jsonStr: string;
begin
  Result := False;
  if Assigned(Engine) and Assigned(DB) then
  begin
    jsonStr := DB.LoadGame;
    if jsonStr <> '' then
    begin
      Engine.ImportStateFromJSON(jsonStr);
      Result := True;
    end;
  end;
end;

class procedure TSaveManager.BorrarPartida(DB: TDatabase);
begin
  if Assigned(DB) then DB.DeleteSavedGame;
end;

class function TSaveManager.HayPartidaGuardada(DB: TDatabase): Boolean;
begin
  Result := False;
  if Assigned(DB) then Result := DB.HasSavedGame;
end;

end.
