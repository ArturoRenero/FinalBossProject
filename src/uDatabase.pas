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
  FireDAC.Comp.Client,
  System.JSON,
  System.Types,
  uTypes,
  FireDAC.Phys.SQLiteWrapper.Stat;

type
  TDatabase = class
  private
    FConn : TFDConnection;
    procedure CreateTables;
    function  CoordsToJSON(const Cells: TBoardCells): string;
    function  JSONToCoords(const JSON: string): TBoardCells;
  public
    constructor Create(const DBPath: string);
    destructor  Destroy; override;

    procedure SaveBoardCoords(BoardIdx: Integer; const Cells: TBoardCells);
    function  LoadBoardCoords(BoardIdx: Integer): TBoardCells;
    function  HasBoardCoords(BoardIdx: Integer): Boolean;
    function  LoadAllBoardCoords: TAllBoardCoords;

    // Partida guardada (Fase 8 del plan)
    procedure SaveGame(const StateJSON: string);
    function  LoadGame: string;           // devuelve '' si no hay partida
    function  HasSavedGame: Boolean;
    procedure DeleteSavedGame;
  end;

implementation

uses
  FireDAC.DApt;   // ← registra TFDQuery y otros componentes DApt en runtime

constructor TDatabase.Create(const DBPath: string);
begin
  inherited Create;
  FConn := TFDConnection.Create(nil);
  FConn.Params.DriverID := 'SQLite';
  FConn.Params.Database := DBPath;
  FConn.Connected := True;
  CreateTables;
end;

destructor TDatabase.Destroy;
begin
  FConn.Free;
  inherited;
end;

procedure TDatabase.CreateTables;
begin
  // Tabla de coordenadas: 1 registro por tablero, coordenadas en JSON
  FConn.ExecSQL(
    'CREATE TABLE IF NOT EXISTS BOARD_COORDS (' +
    '  board_index INTEGER PRIMARY KEY,' +
    '  coords_json TEXT NOT NULL,' +
    '  updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP' +
    ')'
  );

  // Tabla de partida guardada: máximo 1 slot (siempre id = 1)
  // INSERT OR REPLACE garantiza que solo exista 1 registro
  FConn.ExecSQL(
    'CREATE TABLE IF NOT EXISTS SAVED_GAME (' +
    '  id         INTEGER PRIMARY KEY,' +  // siempre será 1
    '  state_json TEXT NOT NULL,' +
    '  saved_at   DATETIME DEFAULT CURRENT_TIMESTAMP' +
    ')'
  );
end;

function TDatabase.CoordsToJSON(const Cells: TBoardCells): string;
var
  arr : TJSONArray;
  obj : TJSONObject;
  pt  : TPointF;
begin
  arr := TJSONArray.Create;
  try
    for pt in Cells do
    begin
      obj := TJSONObject.Create;
      obj.AddPair('x', TJSONNumber.Create(pt.X));
      obj.AddPair('y', TJSONNumber.Create(pt.Y));
      arr.Add(obj);
    end;
    Result := arr.ToJSON;
  finally
    arr.Free;
  end;
end;

function TDatabase.JSONToCoords(const JSON: string): TBoardCells;
var
  arr : TJSONArray;
  obj : TJSONObject;
  i   : Integer;
begin
  arr := TJSONObject.ParseJSONValue(JSON) as TJSONArray;
  if arr = nil then Exit;
  try
    SetLength(Result, arr.Count);
    for i := 0 to arr.Count - 1 do
    begin
      obj       := arr.Items[i] as TJSONObject;
      Result[i] := TPointF.Create(
        (obj.GetValue('x') as TJSONNumber).AsDouble,
        (obj.GetValue('y') as TJSONNumber).AsDouble
      );
    end;
  finally
    arr.Free;
  end;
end;

procedure TDatabase.SaveBoardCoords(BoardIdx: Integer; const Cells: TBoardCells);
begin
  // INSERT OR REPLACE = sobreescribe si ya existe (el único registro por tablero)
  FConn.ExecSQL(
    'INSERT OR REPLACE INTO BOARD_COORDS (board_index, coords_json, updated_at)' +
    ' VALUES (:idx, :json, CURRENT_TIMESTAMP)',
    [BoardIdx, CoordsToJSON(Cells)]
  );
end;

function TDatabase.LoadBoardCoords(BoardIdx: Integer): TBoardCells;
var
  qry : TFDQuery;
begin
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := FConn;
    qry.SQL.Text   := 'SELECT coords_json FROM BOARD_COORDS WHERE board_index = :idx';
    qry.ParamByName('idx').AsInteger := BoardIdx;
    qry.Open;
    if not qry.Eof then
      Result := JSONToCoords(qry.Fields[0].AsString)
    else
      SetLength(Result, 0);
  finally
    qry.Free;
  end;
end;

function TDatabase.HasBoardCoords(BoardIdx: Integer): Boolean;
var
  qry : TFDQuery;
begin
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := FConn;
    qry.SQL.Text   :=
      'SELECT COUNT(*) FROM BOARD_COORDS WHERE board_index = :idx';
    qry.ParamByName('idx').AsInteger := BoardIdx;
    qry.Open;
    Result := qry.Fields[0].AsInteger > 0;
  finally
    qry.Free;
  end;
end;

function TDatabase.LoadAllBoardCoords: TAllBoardCoords;
var
  qry      : TFDQuery;
  maxIdx   : Integer;
begin
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := FConn;
    // Cargar en orden para respetar los índices
    qry.SQL.Text := 'SELECT board_index, coords_json FROM BOARD_COORDS ORDER BY board_index';
    qry.Open;

    // Encontrar el índice máximo para dimensionar el array
    maxIdx := 0;
    while not qry.Eof do
    begin
      if qry.Fields[0].AsInteger > maxIdx then
        maxIdx := qry.Fields[0].AsInteger;
      qry.Next;
    end;

    SetLength(Result, maxIdx + 1); // índices 0..maxIdx

    qry.First;
    while not qry.Eof do
    begin
      Result[qry.Fields[0].AsInteger] := JSONToCoords(qry.Fields[1].AsString);
      qry.Next;
    end;
  finally
    qry.Free;
  end;
end;

procedure TDatabase.SaveGame(const StateJSON: string);
begin
  // INSERT OR REPLACE con id=1 garantiza slot único (sobreescribe)
  FConn.ExecSQL(
    'INSERT OR REPLACE INTO SAVED_GAME (id, state_json, saved_at)' +
    ' VALUES (1, :json, CURRENT_TIMESTAMP)',
    [StateJSON]
  );
end;

function TDatabase.LoadGame: string;
var qry: TFDQuery;
begin
  Result := '';
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := FConn;
    qry.SQL.Text   := 'SELECT state_json FROM SAVED_GAME WHERE id = 1';
    qry.Open;
    if not qry.Eof then
      Result := qry.Fields[0].AsString;
  finally
    qry.Free;
  end;
end;

function TDatabase.HasSavedGame: Boolean;
var qry: TFDQuery;
begin
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := FConn;
    qry.SQL.Text   := 'SELECT COUNT(*) FROM SAVED_GAME WHERE id = 1';
    qry.Open;
    Result := qry.Fields[0].AsInteger > 0;
  finally
    qry.Free;
  end;
end;

procedure TDatabase.DeleteSavedGame;
begin
  FConn.ExecSQL('DELETE FROM SAVED_GAME WHERE id = 1');
end;

end.
