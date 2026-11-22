import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/flow_page.dart';

// "Aparência": claro, escuro ou igual ao aparelho, com prévia dos dois temas
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late String _selected = context.read<SettingsProvider>().settings.appearance;

  static const _options = [
    ('light', 'Claro', 'Superfícies claras e cores aquáticas.'),
    ('dark', 'Escuro', 'Menos luminosidade, com contraste confortável.'),
    ('system', 'Sistema', 'Acompanha a aparência do aparelho.'),
  ];

  Future<void> _save() async {
    final provider = context.read<SettingsProvider>();
    await provider.update(provider.settings.copyWith(appearance: _selected));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      backLabel: 'Preferências',
      title: 'Aparência',
      subtitle: 'Seu GotaGo, na luz que você preferir.',
      content: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ThemePreview(dark: false)),
            SizedBox(width: 14),
            Expanded(child: _ThemePreview(dark: true)),
          ],
        ),
        for (final (value, label, description) in _options)
          _AppearanceOption(
            label: label,
            description: description,
            selected: _selected == value,
            onTap: () => setState(() => _selected = value),
          ),
        const NoteCard(
          'Seu tema não muda as metas, os registros nem a classificação nas '
          'ligas.',
        ),
      ],
      primary: FlowAction('Salvar aparência', _save),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _AppearanceOption({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 30,
                  color: selected
                      ? AppColors.dropDark
                      : AppColors.outlineBorder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Miniatura do card "Sua hidratação hoje" com as cores fixas de cada tema
class _ThemePreview extends StatelessWidget {
  final bool dark;

  const _ThemePreview({required this.dark});

  @override
  Widget build(BuildContext context) {
    final card = dark ? const Color(0xFF16383E) : Colors.white;
    final text = dark ? const Color(0xFFE8F5F3) : const Color(0xFF0B3B3C);
    final muted = dark ? const Color(0xFF9DB9B6) : const Color(0xFF5E6F6C);
    final link = dark ? const Color(0xFF5FD8DC) : const Color(0xFF0E8496);
    final soft = dark ? const Color(0xFF1F4A50) : const Color(0xFFE4F3F2);
    final track = dark ? const Color(0xFF27505A) : const Color(0xFFE1EFEB);
    final arc = dark ? const Color(0xFF5FD8DC) : AppColors.dropDark;

    TextStyle style(double size, Color color, [FontWeight? weight]) =>
        TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1.2,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dark ? 'Escuro' : 'Claro',
          style: style(16, AppColors.primaryDark, FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sua hidratação hoje',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style(8, text, FontWeight.w800),
                    ),
                  ),
                  Text('Editar meta', style: style(6, link, FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 78,
                height: 78,
                child: CustomPaint(
                  painter: _MiniRingPainter(track: track, arc: arc),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('1.250', style: style(15, text, FontWeight.w800)),
                        Text('de 2.500 ml', style: style(6, muted)),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: soft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '50% da meta',
                            style: style(5, link, FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? (dark ? arc : const Color(0xFF0B3B3C))
                              : soft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+ ${[250, 500, 750][i]} ml',
                          style: style(
                            6,
                            i == 0
                                ? (dark
                                      ? const Color(0xFF0B3B3C)
                                      : Colors.white)
                                : text,
                            FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final Color track;
  final Color arc;

  const _MiniRingPainter({required this.track, required this.arc});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius, paint..color = track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      pi,
      false,
      paint..color = arc,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter oldDelegate) =>
      oldDelegate.track != track || oldDelegate.arc != arc;
}
