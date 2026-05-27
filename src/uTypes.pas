unit uTypes;

// Unit de tipos compartidos entre todos los módulos: TPlayerType (Human/Bot),
// TGameState, TBoardCoord, TPlayer record, TGameConfig.
// Importada por todos, no importa nada más.

interface

uses
  System.Types;   // ← Necesario para TPointF

type
  // ── 1. Tipos de Tablero y Coordenadas ─────────────────────────
  TBoardCells       = TArray<TPointF>;      // coordenadas de las casillas de 1 tablero
  TAllBoardCoords   = TArray<TBoardCells>;  // todos los tableros (dinámico)

  TBoardCoord = record
    CellIndex : Integer;
    X : Single; // posición en el tablero (TPointF)
    Y : Single;
  end;

  TBoardCoordsArray = TArray<TBoardCoord>;

  // ── 2. Tipos de Jugador ───────────────────────────────────────
  TPlayerType = (ptHuman, ptBot);

  TPlayer = record
    ID          : Integer; // 1..4
    Name        : String;
    PlayerType  : TPlayerType;
    AvatarIndex : Integer; // índice en TImageList
    Position    : Integer; // casilla actual (0..63)
    IsActive    : Boolean; // es su turno?
    IsBlocked   : Boolean; // bloqueado por regla (pozo, cárcel)
    TurnsToWait : Integer; // turnos que debe esperar bloqueado
  end;

  // ── 3. Tipos de Estado del Juego ──────────────────────────────
  TGameState = record
    BoardIndex   : Integer;
    ActiveTurn   : Integer; // ID del jugador activo, util para jugabilidad remota
    Players      : array[0..3] of TPlayer;
    TotalPlayers : Integer;
    GameActive   : Boolean;
  end;

const
  // ── Constantes Globales ───────────────────────────────────────
  MAX_PLAYERS        = 4;
  TOTAL_CELLS        = 63;
  MAX_CELLS          = 63;
  WINNING_CELL       = 63;
  BOT_THINK_DELAY_MS = 1500; // "espera" que le tomaría a un humano tirar los dados
  BLANK_IDX          = 0;    // índice 0 = blank en la ImageList

implementation

// (Aquí no va nada de código por ahora porque uTypes solo declara estructuras de datos)

end.
