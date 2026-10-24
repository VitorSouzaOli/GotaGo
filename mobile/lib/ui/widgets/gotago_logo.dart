import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              letterSpacing: -fontSize * 0.03,
              height: 1.0,
            ),
            children: const [
              TextSpan(text: 'GotaGo'),
              TextSpan(
                text: '.',
                style: TextStyle(color: AppColors.tealPrimary),
              ),
            ],
          ),
        ),
        if (showSubtitle) ...[
          SizedBox(height: fontSize * 0.14),
          Text(
            'HIDRATAÇÃO EM EQUIPE',
            style: GoogleFonts.plusJakartaSans(
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
