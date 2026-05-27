unit uRulesEngine;

// Evalúa las reglas del tablero activo al finalizar el movimiento de una ficha. Usa condicionales por índice de tablero (similar a directivas {$IF}) para aplicar reglas específicas: gansos, puente, posada, pozo, cárcel, muerte.

interface

type
  TRuleResult = record
    NewCell: Integer;       // A dónde debe moverse (si es -1, se queda donde está)
    TurnsToSkip: Integer;   // Cuántos turnos pierde (0 por defecto)
    Message: string;        // Mensaje para la UI (Ej. "De oca a oca...")
  end;

  TRulesEngine = class
  public
    // Le pasamos la casilla a la que acaba de llegar el jugador
    class function EvaluateCell(BoardIdx, CurrentCell: Integer): TRuleResult;
  end;

implementation

class function TRulesEngine.EvaluateCell(BoardIdx, CurrentCell: Integer): TRuleResult;
begin
  // Valores por defecto: no moverse, no perder turnos, sin mensaje
  Result.NewCell := -1;
  Result.TurnsToSkip := 0;
  Result.Message := '';

  // Reglas clásicas de la Oca
  case CurrentCell of
    5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59:
      begin
        // Ejemplo de regla: Avanza al siguiente ganso (simplificado)
        Result.NewCell := CurrentCell + 4; // Lógica temporal
        Result.Message := '¡De Oca a Oca y tiro porque me toca!';
      end;
    19: // La Posada
      begin
        Result.TurnsToSkip := 1;
        Result.Message := 'Caíste en la Posada. Pierdes 1 turno.';
      end;
    58: // La Calavera (Muerte)
      begin
        Result.NewCell := 0; // Regresa al inicio
        Result.Message := '¡La Calavera! Regresas a la casilla de inicio.';
      end;
  end;
end;

end.
