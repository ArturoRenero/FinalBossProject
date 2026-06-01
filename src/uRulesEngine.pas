unit uRulesEngine;

interface

type
  TRuleResult = record
    RuleType: string;
    NewCell: Integer;
    TurnsToSkip: Integer;
    RollAgain: Boolean;
    Message: string;
  end;

  TRulesEngine = class
  public
    class function EvaluateCell(BoardIdx, CurrentCell: Integer): TRuleResult;
  end;

implementation

class function TRulesEngine.EvaluateCell(BoardIdx, CurrentCell: Integer): TRuleResult;
var
  VisualCell: Integer;
begin
  // Valores por defecto
  Result.RuleType := '';
  Result.NewCell := -1;
  Result.TurnsToSkip := 0;
  Result.RollAgain := False;
  Result.Message := '';

  // Trabajaremos con la casilla visual (1 a 63) para que coincida con el tablero real
  VisualCell := CurrentCell + 1;

  case VisualCell of
    5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59: // 1. Ocas
      begin
        Result.RuleType := 'GOOSE';
        Result.RollAgain := True;
        // Al NO modificar Result.NewCell, se queda en -1.
        // El jugador se queda en la casilla actual y solo recibe el turno extra.
        Result.Message := '¡Casilla de Oca! Ganas un turno extra.';
      end;
    6, 12: // 2. Puentes
      begin
        Result.RuleType := 'BRIDGE';
        Result.RollAgain := True;
        if VisualCell = 6 then Result.NewCell := 12 - 1
        else Result.NewCell := 6 - 1;
        Result.Message := '¡De puente a puente y tiro porque me lleva la corriente!';
      end;
    19: // 3. Posada
      begin
        Result.RuleType := 'INN';
        Result.TurnsToSkip := 1;
        Result.Message := 'Caíste en la Posada. Pierdes 1 turno.';
      end;
    26, 53: // 7. Dados
      begin
        Result.RuleType := 'DICE';
        Result.RollAgain := True;
        if VisualCell = 26 then Result.NewCell := 53 - 1
        else Result.NewCell := 26 - 1;
        Result.Message := '¡De dado a dado y tiro porque me ha tocado!';
      end;
    31: // 4. Pozo
      begin
        Result.RuleType := 'WELL';
        Result.TurnsToSkip := 2;
        Result.Message := '¡Caíste al pozo! Pierdes 2 turnos.';
      end;
    42: // 5. El Laberinto
      begin
        Result.RuleType := 'MAZE';
        Result.NewCell := 30 - 1; // 29 en índice
        Result.Message := 'Te perdiste en el Laberinto. Retrocedes a la casilla 30.';
      end;
    56: // 6. La Cárcel
      begin
        Result.RuleType := 'PRISON';
        Result.TurnsToSkip := 3;
        Result.Message := '¡A la cárcel! Pierdes 3 turnos.';
      end;
    58: // 8. La Calavera (Muerte)
      begin
        Result.RuleType := 'DEATH';
        Result.NewCell := 1 - 1; // Índice 0 (Salida)
        Result.Message := '¡La Calavera! Regresas a la casilla de inicio.';
      end;
  end;
end;

end.
