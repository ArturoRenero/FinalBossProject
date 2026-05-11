unit uTypes;

// Unit de tipos compartidos entre todos los módulos: TPlayerType (Human/Bot), TGameState, TBoardCoord, TPlayer record, TGameConfig. Importada por todos, no importa nada más.

interface

const
 MAX_PLAYERS = 4;
 TOTAL_CELLS = 63;
 WINNING_CELL = 63;
 BOT_THINK_DELAY_MS = 1500; // Esto se usara para simular la "espera" que le tomaria a un humano tirar los dados

implementation


type
    TPlayerType = (ptHuman, ptBot); TPlayer = record ID : Integer; // 1..4
    Name : String; PlayerType : TPlayerType; AvatarIndex : Integer; // índice en TImageList
    Position : Integer; // casilla actual (0..63)
    IsActive : Boolean; // es su turno?
    IsBlocked : Boolean; // bloqueado por regla (pozo, cárcel)
    TurnsToWait : Integer; // turnos que debe esperar bloqueado
  end;

type
    TBoardCoord = record CellIndex : Integer; X : Single; // posición en el tablero (TPointF)
    Y : Single;
  end;

TBoardCoordsArray = TArray<TBoardCoord>; TAllBoardCoords = array[0..9] of TBoardCoordsArray; // índice 0..9 = hasta 10 tableros distintos

type
    TGameState = record BoardIndex : Integer; ActiveTurn : Integer; // ID del jugador activo
    Players : array[0..3] of TPlayer; TotalPlayers : Integer; GameActive : Boolean;
  end;



end.
