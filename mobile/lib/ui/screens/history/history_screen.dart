import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/water_log_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/water_provider.dart';
import '../../painters/drop_painter.dart';
import '../../navigation/shell_controller.dart';
import '../../widgets/flow_page.dart';
import '../../widgets/footer_note.dart';
import '../../widgets/tab_header.dart';
import '../common/status_screens.dart';
import '../home/widgets/home_cards.dart';
import '../water/water_screens.dart';
import 'widgets/water_bar_chart.dart';

// Aba "Histórico": gráfico da semana/mês, constância e registos de hoje
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _showMonth = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    final water = context.watch<WaterProvider>();
    final goal = water.dailyGoal ?? user.dailyGoal;
    final days = _showMonth ? WaterProvider.historyDays : 7;
    final totals = water.dailyTotals(days);
    final todayDone = water.totalToday >= goal;

    if (water.isLoading) return const LoadingView();

    // Ninguém registrou nada ainda: "Seu primeiro gole começa aqui"
    if (!water.hasAnyLogs) {
      return FlowPage(
        embedded: true,
        showBack: false,
        title: 'Seu primeiro gole começa aqui',
        subtitle: 'Histórico · Nenhum registro ainda',
        illustration: const DropIllustration(),
        content: const [
          FlowCard(
            title: 'Ainda não há registros',
            body:
                'Quando você registrar água, seu consumo e sua evolução '
                'aparecerão aqui.',
          ),
          NoteCard(
            'Comece devagar. Um gole de cada vez já faz parte da sua rotina.',
          ),
        ],
        primary: FlowAction(
          'Registrar meu primeiro copo',
          () => pushPage(
            context,
            const RegisterWaterScreen(backLabel: 'Histórico'),
          ),
        ),
        secondary: FlowAction(
          'Voltar ao início',
          () => context.read<ShellController>().goTo(ShellTab.home),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const TabHeader(
            title: 'Histórico',
            subtitle: 'Cada gole conta para o seu hábito.',
          ),
          const SizedBox(height: 18),
          _PeriodToggle(
            showMonth: _showMonth,
            onChanged: (value) => setState(() => _showMonth = value),
          ),
          const SizedBox(height: 16),
          _ChartCard(totals: totals, goal: goal, compact: _showMonth),
          const SizedBox(height: 16),
          StreakCard(
            streak: user.currentStreak,
            subtitle: todayDone
                ? 'Meta de hoje batida. Sua sequência está em dia.'
                : 'Hoje ainda está em andamento. Sua sequência continua valendo.',
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Registros de hoje',
            actionLabel:
                '${water.todayLogs.length} '
                '${water.todayLogs.length == 1 ? 'registro' : 'registros'}',
            onAction: () => pushPage(context, const TodayLogsScreen()),
          ),
          const SizedBox(height: 12),
          _TodayCard(
            total: water.totalToday,
            goal: goal,
            logs: water.todayLogs,
          ),
          const SizedBox(height: 20),
          const FooterNote('Constância, não excesso. Respeite seu corpo.'),
        ],
      ),
    );
  }
}

// Alternância "Semana | Mês"
class _PeriodToggle extends StatelessWidget {
  final bool showMonth;
  final ValueChanged<bool> onChanged;

  const _PeriodToggle({required this.showMonth, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool isMonth) {
      final selected = showMonth == isMonth;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(isMonth),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ringTrack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [option('Semana', false), option('Mês', true)]),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<int> totals;
  final int goal;
  final bool compact;

  const _ChartCard({
    required this.totals,
    required this.goal,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final days = totals.length;
    // Dias anteriores a hoje que bateram a meta
    final pastDays = totals.sublist(0, days - 1);
    final completed = pastDays.where((total) => total >= goal).length;

    return HomeCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Últimos $days dias',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'De ${days - 1} dias atrás até hoje',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Filtro por data em breve.'),
                          ),
                        );
                    },
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: AppColors.tealDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(width: 14, height: 1, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Meta diária · ${formatMl(goal)} ml',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            WaterBarChart(totals: totals, goal: goal, compact: compact),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: AppColors.tealDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$completed de ${days - 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const TextSpan(
                          text: ' dias concluídos com a meta batida',
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Card "Registros de hoje": total do dia e a lista de registos
class _TodayCard extends StatelessWidget {
  final int total;
  final int goal;
  final List<WaterLogModel> logs;

  const _TodayCard({
    required this.total,
    required this.goal,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final percent = goal > 0 ? (total / goal * 100).round() : 0;
    final done = total >= goal;

    return HomeCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatMl(total),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ml',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$percent% da meta de ${formatMl(goal)} ml',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: done ? AppColors.limeAccent : AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    done ? 'Meta batida' : 'Em andamento',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: done ? AppColors.primaryDark : AppColors.tealDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Nenhum registro hoje. Que tal um gole agora?',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            for (int i = 0; i < logs.length; i++) ...[
              Divider(height: 1, color: AppColors.ringTrack),
              _LogRow(log: logs[i], isLatest: i == 0),
            ],
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final WaterLogModel log;
  final bool isLatest;

  const _LogRow({required this.log, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => pushPage(context, EditLogScreen(log: log)),
      onLongPress: () => deleteLogWithConfirmation(context, log),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                shape: BoxShape.circle,
              ),
              child: const CustomPaint(
                size: Size(13, 17),
                painter: DropPainter(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTime(log.createdAt),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (isLatest)
                    Text(
                      'Último registro',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${formatMl(log.amount)} ml',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
