unit uBoardManager;

interface

uses
  System.SysUtils,
  System.Types,
  System.ImageList,
  FMX.ImgList,
  FMX.Objects,
  FMX.Graphics,
  uTypes,
  uDatabase;

type
  TBoardManager = class
  private
    FBoardImages    : TImageList;
    FDB             : TDatabase;
    FAllCoords      : TAllBoardCoords;
    FActiveBoardIdx : Integer;
    FTempCoords     : TBoardCells;
    FCapturing      : Boolean;
    FCaptureW       : Single;  // ancho del imgBoard al momento de capturar
    FCaptureH       : Single;  // alto  del imgBoard al momento de capturar

  public
    constructor Create(ABoardImages: TImageList; ADB: TDatabase);

    // ── Carga de coordenadas ──────────────────────────────────────
    // Carga TODOS los tableros desde la BD al array en memoria.
    // Se llama automáticamente en Create, pero puede llamarse
    // manualmente para refrescar tras una captura externa.
    procedure LoadAll;

    // ── Visualización ─────────────────────────────────────────────
    procedure LoadBoardIntoImage(BoardIdx: Integer; TargetImg: TImage);
    procedure SetActiveBoard(BoardIdx: Integer);

    // ── Captura de coordenadas (modo admin) ───────────────────────
    // ImgWidth/ImgHeight = dimensiones actuales del imgBoard
    // (necesarias para normalizar al guardar y escalar al leer)
    procedure StartCapture(BoardIdx: Integer; ImgWidth, ImgHeight: Single);
    procedure RecordCell(X, Y: Single);
    procedure FinishCapture;

    // ── Consulta de posiciones ────────────────────────────────────
    // Devuelve posición en píxeles del imgBoard actual
    function GetCellPosition(CellIdx: Integer; ImgWidth, ImgHeight: Single): TPointF; overload;
    function GetCellPosition(BoardIdx, CellIdx: Integer; ImgWidth, ImgHeight: Single): TPointF; overload;
//    // Versión con tablero explícito (para uso desde el GE o red)
//    function GetCellPosition(BoardIdx, CellIdx: Integer): TPointF; overload;
//    // Versión corta: usa el tablero activo (para la UI)
//    function GetCellPosition(CellIdx: Integer): TPointF; overload;

    function ActiveBoardHasCoords: Boolean;
    function CaptureProgress: Integer;

    property ActiveBoardIdx : Integer read FActiveBoardIdx;
    property IsCapturing    : Boolean read FCapturing;
  end;

implementation

constructor TBoardManager.Create(ABoardImages: TImageList; ADB: TDatabase);
begin
  inherited Create;
  FBoardImages    := ABoardImages;
  FDB             := ADB;
  FActiveBoardIdx := BLANK_IDX;
  FCapturing      := False;
  FCaptureW       := 1;
  FCaptureH       := 1;
  LoadAll;  // carga al iniciar el juego (F2: "Al iniciar el juego, LoadAll()")
end;

// ── Carga de coordenadas ──────────────────────────────────────────────────────

procedure TBoardManager.LoadAll;
begin
  // Lee todos los registros de BOARD_COORDS y los pone en memoria.
  // FAllCoords[0] = blank (vacío), FAllCoords[1] = Tablero1, etc.
  FAllCoords := FDB.LoadAllBoardCoords;
end;

// ── Visualización ─────────────────────────────────────────────────────────────

procedure TBoardManager.LoadBoardIntoImage(BoardIdx: Integer; TargetImg: TImage);
var
  Bmp : TBitmap;
  Sz  : TSizeF;
begin
  Sz.Width  := TargetImg.Width;
  Sz.Height := TargetImg.Height;
  Bmp := FBoardImages.Bitmap(Sz, BoardIdx);
  if Bmp <> nil then
    TargetImg.Bitmap.Assign(Bmp);
end;

procedure TBoardManager.SetActiveBoard(BoardIdx: Integer);
begin
  FActiveBoardIdx := BoardIdx;
end;

// ── Captura de coordenadas ────────────────────────────────────────────────────

procedure TBoardManager.StartCapture(BoardIdx: Integer; ImgWidth, ImgHeight: Single);
begin
  FActiveBoardIdx := BoardIdx;
  FCaptureW       := ImgWidth;
  FCaptureH       := ImgHeight;
  SetLength(FTempCoords, 0);
  FCapturing := True;
end;

procedure TBoardManager.RecordCell(X, Y: Single);
// Las coordenadas X,Y vienen de OnMouseMove sobre imgBoard,
// por lo que ya son RELATIVAS al TImage del tablero.
// Si el tablero se escala en otra pantalla, se escalan proporcionalmente.
var
  pt : TPointF;
begin
  if not FCapturing then Exit;
  // Normalizar a 0..1 para que sea independiente del tamaño de pantalla
  pt.X := X / FCaptureW;
  pt.Y := Y / FCaptureH;
  FTempCoords := FTempCoords + [pt];
end;

procedure TBoardManager.FinishCapture;
begin
  if not FCapturing then Exit;

  // Guardar en BD con el índice correcto del tablero activo
  FDB.SaveBoardCoords(FActiveBoardIdx, FTempCoords);

  // Actualizar el array en memoria sin recargar todo desde la BD
  if FActiveBoardIdx >= Length(FAllCoords) then
    SetLength(FAllCoords, FActiveBoardIdx + 1);

  FAllCoords[FActiveBoardIdx] := FTempCoords;

  FCapturing := False;
  SetLength(FTempCoords, 0);
end;

// ── Consulta de posiciones ────────────────────────────────────────────────────

function TBoardManager.GetCellPosition(BoardIdx, CellIdx: Integer; ImgWidth, ImgHeight: Single): TPointF;
// Versión con tablero explícito — úsala desde el GE o cuando necesites
// acceder a las coords de un tablero distinto al activo (Ej. comparar, red)
var norm: TPointF;
begin
  Result := TPointF.Create(0, 0);
  if BoardIdx >= Length(FAllCoords) then Exit;
  if CellIdx  >= Length(FAllCoords[BoardIdx]) then Exit;
  norm     := FAllCoords[BoardIdx][CellIdx];
  // Escalar de 0..1 a los píxeles actuales del imgBoard
  Result.X := norm.X * ImgWidth;
  Result.Y := norm.Y * ImgHeight;
end;

function TBoardManager.GetCellPosition(CellIdx: Integer; ImgWidth, ImgHeight: Single): TPointF;
// Versión corta — delega al tablero activo
begin
  Result := GetCellPosition(FActiveBoardIdx, CellIdx, ImgWidth, ImgHeight);
end;

function TBoardManager.ActiveBoardHasCoords: Boolean;
begin
  Result := (FActiveBoardIdx < Length(FAllCoords)) and
            (Length(FAllCoords[FActiveBoardIdx]) > 0);
end;

function TBoardManager.CaptureProgress: Integer;
begin
  Result := Length(FTempCoords);
end;

end.
