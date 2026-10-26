import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../painters/drop_painter.dart';
import '../../../painters/hydration_ring_painter.dart';

// Card "Sua hidratação hoje": anel de progresso + botões rápidos
class HydrationCard extends StatelessWidget {
  final int total;
  final int goal;
  final int selectedAmount;
  final bool isAdding;
  final ValueChanged<int> onAdd;
  final VoidCallback onCustomAmount;
  final VoidCallback onEditGoal;

  const HydrationCard({
    super.key,
    required this.total,
    required this.goal,
    required this.selectedAmount,
    required this.isAdding,
    required this.onAdd,
    required this.onCustomAmount,
    required this.onEditGoal,
  });

  static const _quickAmounts = [250, 500, 750];

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? total / goal : 0.0;
    final percent = (progress * 100).round();
    final remaining = goal - total;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sua hidratação hoje',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              InkWell(
                onTap: onEditGoal,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Editar meta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.tealDark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anel anima suavemente até o novo progresso
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CustomPaint(
                      painter: HydrationRingPainter(progress: value),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CustomPaint(
                        size: Size(20, 26),
                        painter: DropPainter(),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatMl(total),
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                letterSpacing: -1.5,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'ml',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'de ${formatMl(goal)} ml',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tealSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$percent% da meta',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            remaining > 0
                ? 'Faltam ${formatMl(remaining)} ml. Um gole de cada vez.'
                : 'Meta de hoje batida! Constância é tudo.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (int i = 0; i < _quickAmounts.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _QuickAddButton(
                    amount: _quickAmounts[i],
                    selected: _quickAmounts[i] == selectedAmount,
                    onTap: isAdding ? null : () => onAdd(_quickAmounts[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: isAdding ? null : onCustomAmount,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Outra quantidade'),
          ),
        ],
      ),
    );
  }
}

// Botão "+ 250 ml": o último valor usado fica em destaque (fundo escuro)
class _QuickAddButton extends StatelessWidget {
  final int amount;
  final bool selected;
  final VoidCallback? onTap;

  const _QuickAddButton({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryDark : AppColors.tealSoft,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 20,
                color: selected ? AppColors.limeAccent : AppColors.tealDark,
              ),
              const SizedBox(width: 6),
              Text(
                '$amount ml',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.white : AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bottom sheet de "Outra quantidade"; devolve os ml digitados ou null
Future<int?> showCustomAmountSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CustomAmountSheet(),
  );
}

class _CustomAmountSheet extends StatefulWidget {
  const _CustomAmountSheet();

  @override
  State<_CustomAmountSheet> createState() => _CustomAmountSheetState();
}

class _CustomAmountSheetState extends State<_CustomAmountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, int.parse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Outra quantidade',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 16, color: AppColors.primaryDark),
              decoration: const InputDecoration(
                hintText: 'Quantidade em ml',
                suffixText: 'ml',
              ),
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Informe uma quantidade válida';
                }
                if (amount > 2000) return 'Registre no máximo 2.000 ml por vez';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Adicionar')),
          ],
        ),
      ),
    );
  }
}
