import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gotago/ui/screens/history/widgets/water_bar_chart.dart';

void main() {
  // Larguras de celular pequeno até janela de navegador
  for (final width in [280.0, 390.0, 1200.0]) {
    for (final compact in [false, true]) {
      testWidgets('gráfico em ${width.toInt()} px (compact: $compact)', (
        tester,
      ) async {
        final days = compact ? 30 : 7;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: WaterBarChart(
                    totals: List.generate(days, (i) => i.isEven ? 2500 : 1250),
                    goal: 2500,
                    compact: compact,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Hoje'), findsOneWidget);
      });
    }
  }
}
