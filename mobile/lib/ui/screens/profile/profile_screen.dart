import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/achievement_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/achievement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/league_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/water_provider.dart';
import '../../painters/drop_painter.dart';
import '../../widgets/tab_header.dart';
import '../achievements/achievements_screen.dart';
import '../home/widgets/home_cards.dart';
import '../welcome/welcome_screen.dart';
import 'profile_page.dart';

// Aba "Perfil": resumo, meta diária, conquistas, configurações e sair
class ProfileScreen extends StatelessWidget {
  // Abre Conquistas ou uma das telas de "Do seu jeito"
  final OpenProfilePage onOpenPage;

  const ProfileScreen({super.key, required this.onOpenPage});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;

    context.read<WaterProvider>().clear();
    context.read<AchievementProvider>().clear();
    context.read<LeagueProvider>().clear();
    context.read<SettingsProvider>().clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    // Durante o logout o utilizador some antes da navegação
    if (user == null) return const SizedBox.shrink();

    final achievements = context.watch<AchievementProvider>();
    final goal = context.watch<WaterProvider>().dailyGoal ?? user.dailyGoal;
    final leaguesCount = context.watch<LeagueProvider>().leagues.length;
    final achievementsLabel =
        '${achievements.unlockedCount} de ${achievements.total}';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const TabHeader(
            title: 'Perfil',
            subtitle: 'Seu ritmo. Suas metas. Sua jornada.',
          ),
          const SizedBox(height: 18),
          _SummaryCard(
            user: user,
            achievementsLabel: achievementsLabel,
            leaguesCount: leaguesCount,
            onEditProfile: () =>
                _showMessage(context, 'Edição de perfil em breve.'),
          ),
          const SizedBox(height: 16),
          _GoalCard(
            goal: goal,
            onAdjust: () => _showMessage(context, 'Ajuste de meta em breve.'),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Suas conquistas',
            actionLabel: 'Ver todas',
            onAction: () => onOpenPage(ProfilePage.achievements),
          ),
          const SizedBox(height: 12),
          _AchievementsRow(
            achievements: achievements.achievements,
            streak: user.currentStreak,
            onTap: () => onOpenPage(ProfilePage.achievements),
          ),
          const SizedBox(height: 10),
          const Text(
            'Um dia de cada vez. Medalhas celebram hábitos, não excesso de água.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Do seu jeito'),
          const SizedBox(height: 12),
          _SettingsCard(onOpen: onOpenPage),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => _logout(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sair da conta'),
            ),
          ),
        ],
      ),
    );
  }
}

// Avatar, nome e os números de constância, ligas e conquistas
class _SummaryCard extends StatelessWidget {
  final UserModel user;
  final String achievementsLabel;
  final int leaguesCount;
  final VoidCallback onEditProfile;

  const _SummaryCard({
    required this.user,
    required this.achievementsLabel,
    required this.leaguesCount,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = user.name.trim().split(RegExp(r'\s+')).first;
    final streak = user.currentStreak;

    return HomeCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initialsOf(user.name),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.limeAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      InkWell(
                        onTap: onEditProfile,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Editar perfil',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.tealDark,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: AppColors.tealDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.ringTrack),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  value: '$streak ${streak == 1 ? 'dia' : 'dias'}',
                  label: 'de constância',
                ),
                _Stat(
                  value: '$leaguesCount',
                  label: leaguesCount == 1 ? 'liga' : 'ligas',
                ),
                _Stat(value: achievementsLabel, label: 'conquistas'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final int goal;
  final VoidCallback onAdjust;

  const _GoalCard({required this.goal, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sua meta diária',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onAdjust,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Row(
                      children: [
                        Text(
                          'Ajustar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealDark,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: AppColors.tealDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CustomPaint(size: Size(20, 26), painter: DropPainter()),
                const SizedBox(width: 10),
                Text(
                  formatMl(goal),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'ml por dia',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Necessidades variam. Sua meta não substitui orientação '
                    'profissional.',
                    style: TextStyle(
                      fontSize: 12,
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

// Medalhas lado a lado: 3 por tela, rolando na horizontal se houver mais
class _AchievementsRow extends StatelessWidget {
  final List<AchievementModel> achievements;
  final int streak;
  final VoidCallback onTap;

  const _AchievementsRow({
    required this.achievements,
    required this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const HomeCard(
        child: Text(
          'Registre seu primeiro gole para começar a colecionar medalhas.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    final sorted = sortByDifficulty(achievements);
    // Só a próxima conquista de sequência mostra o progresso ("6 de 7 dias")
    final next = nextStreakAchievement(sorted, streak);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final cardWidth = (constraints.maxWidth - 2 * gap) / 3;

        return SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: gap),
            itemBuilder: (context, index) {
              final achievement = sorted[index];
              final requiredDays = requiredStreakDays(achievement);
              return SizedBox(
                width: cardWidth,
                child: _AchievementCard(
                  onTap: onTap,
                  achievement: achievement,
                  progress: achievement == next
                      ? '${min(streak, requiredDays)} de $requiredDays dias'
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementModel achievement;
  // Texto de progresso da próxima conquista; nas outras bloqueadas: "Bloqueada"
  final String? progress;
  final VoidCallback onTap;

  const _AchievementCard({
    required this.achievement,
    required this.onTap,
    this.progress,
  });

  Widget _icon(bool unlocked) {
    final color = unlocked ? AppColors.primaryDark : AppColors.textSecondary;
    if (achievement.code == 'FIRST_DROP') {
      return unlocked
          ? const CustomPaint(size: Size(16, 21), painter: DropPainter())
          : Icon(Icons.water_drop_outlined, size: 22, color: color);
    }
    final icon = achievement.code.contains('30')
        ? Icons.workspace_premium_outlined
        : Icons.local_fire_department_outlined;
    return Icon(icon, size: 22, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;

    return Material(
      color: unlocked ? AppColors.white : AppColors.lockedSurface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlocked
                      ? AppColors.limeAccent
                      : AppColors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: _icon(unlocked),
              ),
              const Spacer(),
              Text(
                achievement.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: unlocked
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              if (unlocked)
                const Text(
                  'Desbloqueada',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealDark,
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        progress ?? 'Bloqueada',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Lista "Do seu jeito": cada item abre a sua subtela
class _SettingsCard extends StatelessWidget {
  final OpenProfilePage onOpen;

  const _SettingsCard({required this.onOpen});

  static const _items = [
    (
      Icons.notifications_none_rounded,
      'Lembretes de hidratação',
      'Configure seus horários',
      ProfilePage.reminders,
    ),
    (
      Icons.tune_rounded,
      'Preferências e notificações',
      null,
      ProfilePage.preferences,
    ),
    (Icons.help_outline_rounded, 'Ajuda e suporte', null, ProfilePage.help),
    (
      Icons.verified_user_outlined,
      'Privacidade e segurança',
      null,
      ProfilePage.privacy,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < _items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.ringTrack,
              ),
            _settingsTile(
              _items[i].$1,
              _items[i].$2,
              _items[i].$3,
              _items[i].$4,
            ),
          ],
        ],
      ),
    );
  }

  Widget _settingsTile(
    IconData icon,
    String title,
    String? subtitle,
    ProfilePage page,
  ) {
    return InkWell(
      onTap: () => onOpen(page),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primaryDark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primaryDark,
            ),
          ],
        ),
      ),
    );
  }
}
