import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

// Círculo com as iniciais. `highlighted` (o próprio utilizador) usa o fundo
// verde-petróleo com letras verde-amareladas; os outros, o teal claro.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool highlighted;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryDark : AppColors.ringTrack,
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: highlighted ? AppColors.limeAccent : AppColors.textSecondary,
        ),
      ),
    );
  }
}
