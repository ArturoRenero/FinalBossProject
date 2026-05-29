unit uRulesEngine;

interface

type
  TRuleResult = record
    RuleType: string;       // <-- ¡NUEVO! Etiqueta para la animación
    NewCell: Integer;
    TurnsToSkip: Integer;
    Message: string;
  end;

  TRulesEngine = class
  public
    class function EvaluateCell(BoardIdx, CurrentCell: Integer): TRuleResult;
  end;

implementation

class function TRulesEngine.EvaluateCell(BoardIdx, CurrentCell: Integer): TRuleResult;
begin
  // Valores por defecto
  Result.RuleType := '';
  Result.NewCell := -1;
  Result.TurnsToSkip := 0;
  Result.Message := '';

  case CurrentCell of
    5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59:
      begin
        Result.RuleType := 'GOOSE';
        Result.NewCell := CurrentCell + 4; // Lógica temporal (avanza 4 casillas)
        Result.Message := '¡De Oca a Oca y tiro porque me toca!';
      end;
    19: // La Posada
      begin
        Result.RuleType := 'INN';
        Result.TurnsToSkip := 1;
        Result.Message := 'Caíste en la Posada. Pierdes 1 turno.';
      end;
    31: // El Pozo
      begin
        Result.RuleType := 'WELL';
        Result.TurnsToSkip := 999; // 999 = Atrapado hasta ser rescatado
        Result.Message := '¡Caíste al pozo! Necesitas rescate.';
      end;
    42: // El Laberinto
      begin
        Result.RuleType := 'MAZE';
        Result.NewCell := 30; // Retrocede a la 30
        Result.Message := 'Te perdiste en el Laberinto. Vuelves a la casilla 30.';
      end;
    58: // La Calavera (Muerte)
      begin
        Result.RuleType := 'DEATH';
        Result.NewCell := 0; // Regresa al inicio
        Result.Message := '¡La Calavera! Regresas al inicio.';
      end;
  end;
end;

end.
