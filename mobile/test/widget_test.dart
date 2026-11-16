import 'package:flutter_test/flutter_test.dart';

import 'package:gotago/core/utils/formatters.dart';

void main() {
  group('formatMl', () {
    test('não usa separador abaixo de mil', () {
      expect(formatMl(0), '0');
      expect(formatMl(250), '250');
    });

    test('separa os milhares com ponto', () {
      expect(formatMl(1250), '1.250');
      expect(formatMl(2500), '2.500');
      expect(formatMl(10000), '10.000');
    });
  });

  test('formatTime preenche com zero à esquerda', () {
    expect(formatTime(DateTime(2026, 1, 1, 9, 5)), '09:05');
  });

  test('greetingFor muda conforme o horário', () {
    expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Bom dia');
    expect(greetingFor(DateTime(2026, 1, 1, 14)), 'Boa tarde');
    expect(greetingFor(DateTime(2026, 1, 1, 20)), 'Boa noite');
  });

  test('initialsOf usa o primeiro e o último nome', () {
    expect(initialsOf('Vitor Souza'), 'VS');
    expect(initialsOf('Vitor Souza Oliveira'), 'VO');
    expect(initialsOf('Vitor'), 'V');
  });

  test('formatClock e formatInterval', () {
    expect(formatClock(480), '08:00');
    expect(formatClock(1260), '21:00');
    expect(formatInterval(120), 'A cada 2 h');
    expect(formatInterval(90), 'A cada 1h30');
  });
}
