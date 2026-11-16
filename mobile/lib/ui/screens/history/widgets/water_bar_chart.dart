import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../painters/dashed_line_painter.dart';

// Gráfico de barras do consumo diário com a linha tracejada da meta.
// `totals` vai do dia mais antigo até hoje (último item).
class WaterBarChart extends StatelessWidget {
  final List<int> totals;
  final int goal;
  // Visão "Mês": barras finas, sem valores em cima e rótulos semanais
  final bool compact;

  const WaterBarChart({
    super.key,
    required this.totals,
    required this.goal,
    this.compact = false,
  });

  static const _chartHeight = 170.0;
  // Espaço reservado acima da barra mais alta para o valor
  static const _valueSpace = 20.0;

  String? _labelFor(int daysAgo) {
    if (daysAgo == 0) return 'Hoje';
    if (compact) return daysAgo % 7 == 0 ? '−${daysAgo}d' : null;
    if (daysAgo == 1) return 'Ontem';
    return '−${daysAgo}d';
  }

  Color _barColor(int value, bool isToday) {
    if (isToday) return AppColors.primaryDark;
    if (value >= goal) return AppColors.dropDark;
    return AppColors.barPartial;
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = max(goal, totals.fold(0, max)).toDouble();
    final barMaxHeight = _chartHeight - _valueSpace;
    final goalTop = _chartHeight - goal / maxValue * barMaxHeight;

    return Column(
      children: [
        SizedBox(
          height: _chartHeight,
          child: Stack(
            children: [
              // Linha da meta passa por trás das barras
              Positioned(
                left: 0,
                right: 0,
                top: goalTop,
                height: 1,
                child: CustomPaint(
                  painter: DashedLinePainter(
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < totals.length; i++)
                      Expanded(child: _buildBar(i, barMaxHeight, maxValue)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 16,
          child: Row(
            children: [
              for (int i = 0; i < totals.length; i++)
                Expanded(child: _buildLabel(totals.length - 1 - i)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(int index, double barMaxHeight, double maxValue) {
    final value = totals[index];
    final isToday = index == totals.length - 1;
    final height = value == 0 ? 3.0 : max(value / maxValue * barMaxHeight, 6.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 1.5 : 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!compact && value > 0) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMl(value),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Container(
            height: height,
            decoration: BoxDecoration(
              color: value == 0
                  ? AppColors.ringTrack
                  : _barColor(value, isToday),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(compact ? 3 : 7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(int daysAgo) {
    final label = _labelFor(daysAgo);
    if (label == null) return const SizedBox.shrink();

    // OverflowBox deixa o rótulo maior que a coluna estreita da visão "Mês".
    // minWidth: 0 evita restrição inválida quando a coluna passa de 48 px
    // (telas largas, como o navegador).
    return OverflowBox(
      minWidth: 0,
      maxWidth: 48,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: daysAgo == 0 ? FontWeight.w800 : FontWeight.w500,
          color: daysAgo == 0 ? AppColors.primaryDark : AppColors.textSecondary,
        ),
      ),
    );
  }
}
