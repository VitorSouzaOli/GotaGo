import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/water_goal.dart';
import '../../../widgets/app_text_field.dart';

// Texto que explica de onde veio a meta calculada
String estimateExplanation(double? weightKg) {
  if (weightKg == null) {
    return 'Preencha o peso para uma estimativa personalizada. Sem ele, o '
        'ponto de partida é 2.000 ml.';
  }
  return 'Para ${formatDecimal(weightKg)} kg: 35 ml por kg, nunca abaixo de '
      '2.000 ml.';
}

// Escolha entre a meta calculada (pelo peso) e uma meta própria.
// A própria tem sempre no mínimo 2.000 ml.
class GoalChoice extends StatelessWidget {
  final int estimate;
  final String estimateBody;
  final bool useEstimate;
  final ValueChanged<bool> onChanged;
  final TextEditingController customController;
  final VoidCallback? onCustomChanged;
  // Sem peso no perfil, a meta calculada leva a "Editar perfil"
  final VoidCallback? onEstimateUnavailable;

  const GoalChoice({
    super.key,
    required this.estimate,
    required this.estimateBody,
    required this.useEstimate,
    required this.onChanged,
    required this.customController,
    this.onCustomChanged,
    this.onEstimateUnavailable,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceCard(
          selected: useEstimate,
          eyebrow: 'Meta calculada',
          headline: '${formatMl(estimate)} ml',
          body: estimateBody,
          onTap: onEstimateUnavailable ?? () => onChanged(true),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          selected: !useEstimate,
          eyebrow: 'Meta própria',
          body: 'Você define o volume, a partir de 2.000 ml por dia.',
          onTap: () => onChanged(false),
          child: useEstimate
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: AppTextField(
                    label: 'Sua meta diária',
                    hint: 'Ex.: 2500',
                    controller: customController,
                    suffixText: 'ml',
                    keyboardType: TextInputType.number,
                    validator: validateDailyGoal,
                    onChanged: (_) => onCustomChanged?.call(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final String eyebrow;
  final String? headline;
  final String body;
  final VoidCallback onTap;
  final Widget? child;

  const _ChoiceCard({
    required this.selected,
    required this.eyebrow,
    required this.body,
    required this.onTap,
    this.headline,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final headline = this.headline;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: selected ? AppColors.dropDark : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        eyebrow,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 26,
                      color: selected
                          ? AppColors.dropDark
                          : AppColors.outlineBorder,
                    ),
                  ],
                ),
                if (headline != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    headline,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                ?child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
