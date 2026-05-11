unit uDatabase;

// Abstracción sobre SQLite (FireDAC o SQLite3 directo). Expone métodos genéricos: Connect, Execute, Query. El resto de módulos no tocan SQL directamente, solo llaman a este módulo.

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,          // ← Este es el correcto
  FireDAC.Phys.SQLiteDef,       // ← Definiciones del driver
  FireDAC.FMXUI.Wait,           // ← Para FMX (no VCL)
  FireDAC.Comp.Client;

implementation

end.
