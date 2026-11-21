import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/achievement_model.dart';
import '../../../providers/achievement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../painters/drop_painter.dart';
import '../../painters/medal_painter.dart';
import '../../widgets/footer_note.dart';
import '../../widgets/flow_page.dart';
import 'achievement_detail_screen.dart';
import '../../widgets/gotago_logo.dart';

// Dias seguidos exigidos pela conquista ("STREAK_7_DAYS" → 7); 0 nas demais
int requiredStreakDays(AchievementModel achievement) {
  final match = RegExp(r'STREAK_(\d+)_DAYS').firstMatch(achievement.code);
  return match != null ? int.parse(match.group(1)!) : 0;
}

// Conquistas em ordem de dificuldade
List<AchievementModel> sortByDifficulty(List<AchievementModel> achievements) {
  return [...achievements]
    ..sort((a, b) => requiredStreakDays(a).compareTo(requiredStreakDays(b)));
}

// A próxima conquista de sequência, que mostra o progresso ("6 de 7 dias")
AchievementModel? nextStreakAchievement(
  List<AchievementModel> sorted,
  int streak,
) {
  for (final achievement in sorted) {
    final days = requiredStreakDays(achievement);
    if (!achievement.isUnlocked && days > streak) return achievement;
  }
  return null;
}

// Subtela da aba Perfil com todas as medalhas
class AchievementsScreen extends StatelessWidget {
  final VoidCallback onBack;

  const AchievementsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    final provider = context.watch<AchievementProvider>();
    final sorted = sortByDifficulty(provider.achievements);
    final next = nextStreakAchievement(sorted, user.currentStreak);
    final unlocked = provider.unlockedCount;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                label: const Text('Perfil'),
              ),
              const Spacer(),
              const GotaGoLogo(fontSize: 24, showSubtitle: false),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Conquistas',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pequenos hábitos. Grandes motivos pra sorrir.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _ProgressHeader(unlocked: unlocked, total: provider.total),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            const _EmptyAchievements()
          else
            for (final achievement in sorted) ...[
              GestureDetector(
                onTap: () => pushPage(
                  context,
                  AchievementDetailScreen(
                    achievement: achievement,
                    isNext: achievement == next,
                  ),
                ),
                child: _AchievementTile(
                  achievement: achievement,
                  streak: user.currentStreak,
                  showProgress: achievement == next,
                ),
              ),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 6),
          const FooterNote(
            'Medalhas celebram hábitos, não excesso de água. Respeite seu corpo.',
          ),
        ],
      ),
    );
  }
}

// "1 de 3 desbloqueada" + barra dividida em segmentos
class _ProgressHeader extends StatelessWidget {
  final int unlocked;
  final int total;

  const _ProgressHeader({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$unlocked de $total',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              unlocked == 1 ? 'desbloqueada' : 'desbloqueadas',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const Spacer(),
            Icon(
              Icons.workspace_premium_outlined,
              size: 22,
              color: AppColors.tealDark,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 0; i < max(total, 1); i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < unlocked
                        ? AppColors.dropDark
                        : AppColors.ringTrack,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementModel achievement;
  final int streak;
  // Só a próxima conquista de sequência mostra os dias concluídos
  final bool showProgress;

  const _AchievementTile({
    required this.achievement,
    required this.streak,
    required this.showProgress,
  });

  // Textos do app (o backend devolve descrições em pt-PT)
  String get _description {
    final days = requiredStreakDays(achievement);
    switch (achievement.code) {
      case 'FIRST_DROP':
        return 'Seu primeiro registro. O começo de um bom hábito!';
      case 'STREAK_30_DAYS':
        return achievement.isUnlocked
            ? 'Trinta dias seguidos cuidando de você.'
            : 'Sua jornada de cuidado continua, um dia de cada vez.';
    }
    if (days > 0) return 'Cumpra sua meta por $days dias consecutivos.';
    return achievement.description;
  }

  String get _celebration {
    switch (achievement.code) {
      case 'FIRST_DROP':
        return 'Todo hábito começa com uma gota.';
      case 'STREAK_7_DAYS':
        return 'Uma semana inteira de cuidado.';
      case 'STREAK_30_DAYS':
        return 'Um mês de constância. Que orgulho!';
    }
    return 'Conquista desbloqueada. Continue no seu ritmo.';
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;
    // Bloqueadas sem progresso ficam com o card "apagado"
    final faded = !unlocked && !showProgress;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: faded ? AppColors.lockedSurface : AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Medal(achievement: achievement),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(unlocked: unlocked),
                    const SizedBox(height: 6),
                    Text(
                      achievement.name,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: faded
                            ? AppColors.textSecondary
                            : AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (unlocked) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.limeAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 16, color: AppColors.onLime),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _celebration,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onLime,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showProgress) ...[
            const SizedBox(height: 14),
            _StreakProgress(
              done: min(streak, requiredStreakDays(achievement)),
              total: requiredStreakDays(achievement),
            ),
          ],
        ],
      ),
    );
  }
}

// Medalha desenhada + ícone no centro + selo de check/cadeado
class _Medal extends StatelessWidget {
  final AchievementModel achievement;

  const _Medal({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;
    final iconColor = unlocked
        ? AppColors.primaryDark
        : AppColors.outlineBorder;

    final Widget icon;
    if (achievement.code == 'FIRST_DROP') {
      icon = unlocked
          ? const CustomPaint(size: Size(20, 26), painter: DropPainter())
          : Icon(Icons.water_drop_outlined, size: 24, color: iconColor);
    } else if (requiredStreakDays(achievement) >= 30) {
      icon = Icon(Icons.workspace_premium_outlined, size: 26, color: iconColor);
    } else {
      icon = Icon(
        Icons.local_fire_department_outlined,
        size: 26,
        color: iconColor,
      );
    }

    return SizedBox(
      width: 72,
      height: 84,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(72, 84),
            painter: MedalPainter(unlocked: unlocked),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 72,
            child: Center(child: icon),
          ),
          Positioned(
            right: 2,
            top: 48,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: unlocked ? AppColors.primaryDark : AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              child: Icon(
                unlocked ? Icons.check_rounded : Icons.lock_outline_rounded,
                size: 12,
                color: unlocked
                    ? AppColors.limeAccent
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool unlocked;

  const _StatusChip({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.limeLight : AppColors.ringTrack,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.check_rounded : Icons.lock_outline_rounded,
            size: 12,
            color: unlocked ? AppColors.onLime : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            unlocked ? 'Desbloqueada' : 'Bloqueada',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: unlocked ? AppColors.onLime : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// "6 de 7 dias · Falta só 1 dia!" e um quadradinho por dia
class _StreakProgress extends StatelessWidget {
  final int done;
  final int total;

  const _StreakProgress({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final remaining = total - done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '$done de $total dias',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.tealDark,
              ),
            ),
            const Spacer(),
            Text(
              remaining == 1 ? 'Falta só 1 dia!' : 'Faltam $remaining dias',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Até 10 dias cabem como quadradinhos; acima disso, uma barra
        if (total <= 10)
          Row(
            children: [
              for (int i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _DayBox(done: i < done)),
              ],
            ],
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              color: AppColors.dropDark,
              backgroundColor: AppColors.ringTrack,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Hoje ainda está em andamento. No seu ritmo.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DayBox extends StatelessWidget {
  final bool done;

  const _DayBox({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: done ? AppColors.tealSoft : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: done ? null : Border.all(color: AppColors.outlineBorder),
      ),
      child: Icon(
        done ? Icons.check_rounded : Icons.circle,
        size: done ? 14 : 5,
        color: done ? AppColors.tealDark : AppColors.textSecondary,
      ),
    );
  }
}

class _EmptyAchievements extends StatelessWidget {
  const _EmptyAchievements();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Registre seu primeiro gole para começar a colecionar medalhas.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
