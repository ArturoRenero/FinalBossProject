{unit uPlayerManager;

// Mantiene el estado de cada jugador: posición actual en el tablero, avatar seleccionado, tipo (Human/Bot), si está bloqueado por una regla, turnos a esperar, etc.

interface

uses
  System.SysUtils,
  System.Types,
  System.Generics.Collections,   // TList<Integer>  ← este era el otro problema
  FMX.Objects,                   // TImage
  FMX.Graphics,
  FMX.ImgList,
  System.ImageList;

type
  TPlayerManager = class
  private
    FAvatarImages    : TImageList;
    FAvailableAvatars: TList<Integer>;
  public
    constructor Create(AAvatarImages: TImageList);
    destructor  Destroy; override;
    procedure   LoadAvatarIntoImage(AvatarIdx: Integer; TargetImg: TImage);
    function    SelectRandomAvatar: Integer;
    procedure   MarkAvatarTaken(AvatarIdx: Integer);
  end;

implementation

constructor TPlayerManager.Create(AAvatarImages: TImageList);
var i: Integer;
begin
  inherited Create;
  FAvatarImages     := AAvatarImages;
  FAvailableAvatars := TList<Integer>.Create;
  // Cargar todos los índices como disponibles al inicio
  for i := 0 to FAvatarImages.Count - 1 do
    FAvailableAvatars.Add(i);
end;

destructor TPlayerManager.Destroy;
begin
  FAvailableAvatars.Free;    // ← importante: TList sí es dueño, hay que liberarlo
  inherited;
end;

procedure TPlayerManager.MarkAvatarTaken(AvatarIdx: Integer);
begin
  FAvailableAvatars.Remove(AvatarIdx);  // ya no disponible
end;

function TPlayerManager.SelectRandomAvatar: Integer;
var rnd: Integer;
begin
  rnd    := Random(FAvailableAvatars.Count);
  Result := FAvailableAvatars[rnd];
  FAvailableAvatars.Delete(rnd);
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

end.}

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

end.
