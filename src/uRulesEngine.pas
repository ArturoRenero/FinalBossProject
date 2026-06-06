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
begin
  // Valores por defecto.
  Result.RuleType := '';
  Result.NewCell := -1;
  Result.TurnsToSkip := 0;
  Result.RollAgain := False;
  Result.Message := '';

  case CurrentCell of
    5, 9, 14, 18, 23, 27, 32, 36, 41, 45, 50, 54, 59: // Ocas
      begin
        Result.RuleType := 'GOOSE';
        Result.RollAgain := True;
        // La ficha se queda en la misma casilla y solo conserva el turno.
        Result.Message := 'Casilla de Oca: ganas un turno extra.';
      end;

    6, 12: // Puentes
      begin
        Result.RuleType := 'BRIDGE';
        Result.RollAgain := True;
        if CurrentCell = 6 then
          Result.NewCell := 12
        else
          Result.NewCell := 6;
        Result.Message := 'De puente a puente: vuelves a tirar.';
      end;

    19: // Posada
      begin
        Result.RuleType := 'INN';
        Result.TurnsToSkip := 1;
        Result.Message := 'Caiste en la Posada. Pierdes 1 turno.';
      end;

    26, 53: // Dados
      begin
        Result.RuleType := 'DICE';
        Result.RollAgain := True;
        if CurrentCell = 26 then
          Result.NewCell := 53
        else
          Result.NewCell := 26;
        Result.Message := 'De dado a dado: vuelves a tirar.';
      end;

    31: // Pozo
      begin
        Result.RuleType := 'WELL';
        Result.TurnsToSkip := 2;
        Result.Message := 'Caiste al pozo. Pierdes 2 turnos.';
      end;

    42: // Laberinto
      begin
        Result.RuleType := 'MAZE';
        Result.NewCell := 30;
        Result.Message := 'Te perdiste en el Laberinto. Retrocedes a la casilla 30.';
      end;

    56: // Carcel
      begin
        Result.RuleType := 'PRISON';
        Result.TurnsToSkip := 3;
        Result.Message := 'A la carcel. Pierdes 3 turnos.';
      end;

    58: // Calavera / muerte
      begin
        Result.RuleType := 'DEATH';
        Result.NewCell := 0; // Inicio.
        Result.Message := 'La Calavera: regresas al inicio.';
      end;
  end;
end;

end.
