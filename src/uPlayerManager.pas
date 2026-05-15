unit uPlayerManager;

interface

uses
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  System.ImageList,
  FMX.ImgList,
  FMX.Objects,
  FMX.Graphics;

type
  TPlayerManager = class
  private
    FAvatarImages     : TImageList;
    FAvailableAvatars : TList<Integer>;
  public
    constructor Create(AAvatarImages: TImageList);
    destructor  Destroy; override;
    procedure   LoadAvatarIntoImage(AvatarIdx: Integer; TargetImg: TImage);
    function    SelectRandomAvatar: Integer;
    procedure   MarkAvatarTaken(AvatarIdx: Integer);
    function GetTakenArray: TArray<Boolean>;
    function AvailableCount: Integer;
  end;

implementation

constructor TPlayerManager.Create(AAvatarImages: TImageList);
var
  i : Integer;
begin
  inherited Create;
  FAvatarImages     := AAvatarImages;
  FAvailableAvatars := TList<Integer>.Create;
  for i := 0 to FAvatarImages.Count - 1 do
    FAvailableAvatars.Add(i);
end;

destructor TPlayerManager.Destroy;
begin
  FAvailableAvatars.Free;
  inherited;
end;

procedure TPlayerManager.LoadAvatarIntoImage(AvatarIdx: Integer; TargetImg: TImage);
var
  Bmp : TBitmap;
  Sz  : TSizeF;
begin
  Sz.Width  := TargetImg.Width;
  Sz.Height := TargetImg.Height;
  Bmp := FAvatarImages.Bitmap(Sz, AvatarIdx);
  if Bmp <> nil then
    TargetImg.Bitmap.Assign(Bmp);
end;

function TPlayerManager.SelectRandomAvatar: Integer;
var
  rnd : Integer;
begin
  if FAvailableAvatars.Count = 0 then
    raise Exception.Create('No hay avatares disponibles');
  rnd    := Random(FAvailableAvatars.Count);
  Result := FAvailableAvatars[rnd];
  FAvailableAvatars.Delete(rnd);
end;

procedure TPlayerManager.MarkAvatarTaken(AvatarIdx: Integer);
begin
  FAvailableAvatars.Remove(AvatarIdx);
end;

function TPlayerManager.GetTakenArray: TArray<Boolean>;
var i : Integer;
begin
  SetLength(Result, FAvatarImages.Count);
  // Asumir todos tomados; desmarcar los que aún están disponibles
  for i := 0 to High(Result) do Result[i] := True;
  for i := 0 to FAvailableAvatars.Count - 1 do
    Result[FAvailableAvatars[i]] := False;
end;

function TPlayerManager.AvailableCount: Integer;
begin
  Result := FAvailableAvatars.Count;
end;

end.
