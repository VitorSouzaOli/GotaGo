import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class GotaGoLogo extends StatelessWidget {
  final double fontSize;
  final bool showSubtitle;

  const GotaGoLogo({super.key, this.fontSize = 56, this.showSubtitle = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              letterSpacing: -fontSize * 0.03,
              height: 1.0,
            ),
            children: [
              const TextSpan(text: 'GotaGo'),
              // Ponto redondo desenhado (o "." da fonte é quadrado),
              // apoiado na linha de base como um ponto final.
              // aboveBaseline (e não baseline) porque não precisa perguntar a
              // linha de base ao Container, o que quebra dentro de IntrinsicHeight.
              WidgetSpan(
                alignment: PlaceholderAlignment.aboveBaseline,
                baseline: TextBaseline.alphabetic,
                child: Container(
                  width: fontSize * 0.18,
                  height: fontSize * 0.18,
                  margin: EdgeInsets.only(left: fontSize * 0.05),
                  decoration: const BoxDecoration(
                    color: AppColors.tealPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showSubtitle) ...[
          SizedBox(height: fontSize * 0.14),
          Text(
            'HIDRATAÇÃO EM EQUIPE',
            style: TextStyle(
              fontSize: fontSize * 0.17,
              fontWeight: FontWeight.w700,
              letterSpacing: fontSize * 0.02,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
