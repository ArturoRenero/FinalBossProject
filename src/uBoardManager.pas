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
    FAllCoords      : TAllBoardCoords;  // array de arrays en memoria
    FActiveBoardIdx : Integer;
    FTempCoords     : TBoardCells;      // coordenadas siendo capturadas ahora
    FCapturing      : Boolean;          // modo captura activo?
  public
    constructor Create(ABoardImages: TImageList; ADB: TDatabase);

    // Visualización
    procedure LoadBoardIntoImage(BoardIdx: Integer; TargetImg: TImage);
    procedure SetActiveBoard(BoardIdx: Integer);

    // Captura de coordenadas (modo admin)
    procedure StartCapture(BoardIdx: Integer);
    procedure RecordCell(X, Y: Single);  // llamado desde OnDblClick
    procedure FinishCapture;             // guarda en DB cuando terminan las 63

    // Consulta de posiciones
    function  GetCellPosition(CellIdx: Integer): TPointF;
    function  ActiveBoardHasCoords: Boolean;
    function  CaptureProgress: Integer; // cuántas casillas van

    property  ActiveBoardIdx : Integer  read FActiveBoardIdx;
    property  IsCapturing    : Boolean  read FCapturing;
  end;

implementation

constructor TBoardManager.Create(ABoardImages: TImageList; ADB: TDatabase);
begin
  inherited Create;
  FBoardImages    := ABoardImages;
  FDB             := ADB;
  FActiveBoardIdx := BLANK_IDX;
  FCapturing      := False;

  // Cargar todas las coordenadas guardadas en memoria al iniciar
  FAllCoords := FDB.LoadAllBoardCoords;
end;

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

procedure TBoardManager.StartCapture(BoardIdx: Integer);
begin
  FActiveBoardIdx := BoardIdx;
  SetLength(FTempCoords, 0); // limpiar coords temporales
  FCapturing := True;
end;

procedure TBoardManager.RecordCell(X, Y: Single);
var
  pt : TPointF;
begin
  if not FCapturing then Exit;
  pt := TPointF.Create(X, Y);
  FTempCoords := FTempCoords + [pt]; // agregar al array dinámico
end;

procedure TBoardManager.FinishCapture;
begin
  if not FCapturing then Exit;

  // Guardar en DB (sobreescribe si ya existía)
  FDB.SaveBoardCoords(FActiveBoardIdx, FTempCoords);

  // Actualizar el array en memoria
  if FActiveBoardIdx >= Length(FAllCoords) then
    SetLength(FAllCoords, FActiveBoardIdx + 1);

  FAllCoords[FActiveBoardIdx] := FTempCoords;
  FCapturing := False;
  SetLength(FTempCoords, 0);
end;

function TBoardManager.GetCellPosition(CellIdx: Integer): TPointF;
begin
  Result := TPointF.Create(0, 0); // default si no hay coords
  if FActiveBoardIdx >= Length(FAllCoords) then Exit;
  if CellIdx >= Length(FAllCoords[FActiveBoardIdx]) then Exit;
  Result := FAllCoords[FActiveBoardIdx][CellIdx];
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
