{unit uBoardManager;

// Administra el TArray<TPointF> de coordenadas de casillas para cada tablero. Carga las coordenadas desde la base de datos al iniciar. Expone el método GetPosition(boardIdx, cellIdx): TPointF a la UI.

interface

uses
  System.SysUtils,
  System.Types,          // TSizeF
  FMX.Objects,           // TImage
  FMX.Graphics,          // TBitmap
  FMX.ImgList,           // TImageList
  System.ImageList;      // TCustomImageList (base de TImageList)

type
  TBoardManager = class
  private
    FBoardImages : TImageList;  // referencia, no dueño
  public
    constructor Create(ABoardImages: TImageList);
    procedure LoadBoardIntoImage(BoardIdx: Integer; TargetImg: TImage);
  end;

implementation

constructor TBoardManager.Create(ABoardImages: TImageList);
begin
  inherited Create;
  FBoardImages := ABoardImages;  // solo guarda la referencia
end;

procedure TBoardManager.LoadBoardIntoImage(BoardIdx: Integer; TargetImg: TImage);
var
  Bmp : TBitmap;
  Sz  : TSizeF;
begin
  Sz.Width  := TargetImg.Width;    // ← así, sin .Create()
  Sz.Height := TargetImg.Height;   // TSizeF es un record, se asigna directo
  Bmp := FBoardImages.Bitmap(Sz, BoardIdx);
  if Bmp <> nil then
    TargetImg.Bitmap.Assign(Bmp);
end;

end.}

unit uBoardManager;

interface

uses
  System.SysUtils,
  System.Types,
  System.ImageList,
  FMX.ImgList,
  FMX.Objects,
  FMX.Graphics;

type
  TBoardManager = class
  private
    FBoardImages : TImageList;
  public
    constructor Create(ABoardImages: TImageList);
    procedure   LoadBoardIntoImage(BoardIdx: Integer; TargetImg: TImage);
  end;

implementation

constructor TBoardManager.Create(ABoardImages: TImageList);
begin
  inherited Create;
  FBoardImages := ABoardImages;
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

end.
