import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/user_model.dart';
import '../../../providers/achievement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/league_provider.dart';
import '../../../providers/water_provider.dart';
import '../../widgets/flow_page.dart';
import '../../widgets/footer_note.dart';
import '../../widgets/gotago_logo.dart';
import '../common/status_screens.dart';
import '../goal/goal_screens.dart';
import '../water/water_screens.dart';
import 'widgets/home_cards.dart';
import 'widgets/hydration_card.dart';

// Aba "Início"
class HomeTab extends StatelessWidget {
  // Troca a aba da barra de navegação (1 = Ligas, 2 = Histórico, 3 = Perfil)
  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenAchievements;

  const HomeTab({
    super.key,
    required this.onNavigate,
    required this.onOpenAchievements,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    // Durante o logout o utilizador some antes da navegação
    if (user == null) return const SizedBox.shrink();

    final water = context.watch<WaterProvider>();
    final achievements = context.watch<AchievementProvider>();
    final leagueProvider = context.watch<LeagueProvider>();
    final leagues = leagueProvider.leagues;
    final selectedLeague = leagueProvider.selected;

    final lastLogAt = water.lastLogAt;
    final historySubtitle = lastLogAt != null
        ? 'Último: ${water.lastAmount} ml · ${formatTime(lastLogAt)}'
        : 'Nenhum registro hoje';

    final latest = achievements.latestUnlocked;
    final achievementsSubtitle = achievements.total == 0
        ? 'Nenhuma ainda'
        : '${achievements.unlockedCount} de ${achievements.total}'
              '${latest != null ? ' · ${latest.name}' : ''}';

    if (water.isLoading || leagueProvider.isLoading && leagues.isEmpty) {
      return const LoadingView();
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _Header(user: user, onAvatarTap: () => onNavigate(3)),
          const SizedBox(height: 20),
          HydrationCard(
            total: water.totalToday,
            goal: water.dailyGoal ?? user.dailyGoal,
            selectedAmount: water.selectedAmount,
            isAdding: water.isAdding,
            onAdd: (amount) => registerWater(context, amount),
            onCustomAmount: () =>
                pushPage(context, const RegisterWaterScreen()),
            onEditGoal: () => pushPage(context, const EditGoalScreen()),
          ),
          const SizedBox(height: 16),
          StreakCard(streak: user.currentStreak),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Suas ligas',
            actionLabel: leagues.isEmpty
                ? 'Ver ligas'
                : 'Ver ${leagues.length} ${leagues.length == 1 ? 'liga' : 'ligas'}',
            onAction: () => onNavigate(1),
          ),
          const SizedBox(height: 12),
          if (selectedLeague != null)
            LeagueSummaryCard(
              league: selectedLeague,
              userId: user.id,
              onTap: () => onNavigate(1),
            )
          else
            LeagueEmptyCard(onTap: () => onNavigate(1)),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ShortcutCard(
                    icon: Icons.history_rounded,
                    title: 'Histórico',
                    subtitle: historySubtitle,
                    onTap: () => onNavigate(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShortcutCard(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Conquistas',
                    subtitle: achievementsSubtitle,
                    onTap: onOpenAchievements,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const FooterNote('Constância, não excesso. Respeite seu corpo.'),
        ],
      ),
    );
  }
}

// Logo + "Bom dia, Vitor!" + avatar com as iniciais
class _Header extends StatelessWidget {
  final UserModel user;
  final VoidCallback onAvatarTap;

  const _Header({required this.user, required this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final firstName = user.name.trim().split(RegExp(r'\s+')).first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GotaGoLogo(fontSize: 24, showSubtitle: false),
              const SizedBox(height: 6),
              Text(
                '${greetingFor(DateTime.now())}, $firstName!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.6,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: AppColors.primaryDark,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onAvatarTap,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Center(
                child: Text(
                  initialsOf(user.name),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimaryAccent,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
