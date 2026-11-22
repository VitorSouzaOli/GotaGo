import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/league_model.dart';

// Card branco arredondado e clicável, base dos cards da Home
class HomeCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const HomeCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

// Card verde-amarelado "6 dias de constância"
class StreakCard extends StatelessWidget {
  final int streak;
  // Substitui o subtítulo padrão (o Histórico fala do dia em andamento)
  final String? subtitle;

  const StreakCard({super.key, required this.streak, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final title = streak == 0
        ? 'Comece sua constância'
        : '$streak ${streak == 1 ? 'dia' : 'dias'} de constância';
    final subtitle =
        this.subtitle ??
        (streak == 0
            ? 'Bata a meta de hoje para começar.'
            : '$streak ${streak == 1 ? 'meta seguida' : 'metas seguidas'}. '
                  'Continue no seu ritmo.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.limeAccent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            size: 30,
            color: AppColors.onLime,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onLime,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onLime.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Título de seção com link à direita ("Suas ligas · Ver ligas >").
// Sem `onAction`, o texto da direita é só informativo ("4 registros").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        if (actionLabel != null && onAction == null)
          Text(
            actionLabel,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        if (actionLabel != null && onAction != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tealDark,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.tealDark,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Resumo da liga em destaque: líder do ranking e a posição do utilizador
class LeagueSummaryCard extends StatelessWidget {
  final LeagueModel league;
  final String userId;
  final VoidCallback onTap;

  const LeagueSummaryCard({
    super.key,
    required this.league,
    required this.userId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leader = league.ranking.isEmpty ? null : league.ranking.first;
    final position = league.positionOf(userId);
    final me = position != null ? league.ranking[position - 1] : null;
    final people =
        '${league.memberCount} ${league.memberCount == 1 ? 'pessoa' : 'pessoas'}';

    String days(int count) => '$count ${count == 1 ? 'dia' : 'dias'}';

    return HomeCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.group_outlined,
                  size: 24,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      league.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      '$people · ranking por dias seguidos',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (leader != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                // Líder (se o líder for o próprio utilizador, só aparece o destaque)
                if (position != 1)
                  Expanded(
                    child: _rankingText(
                      '1º',
                      leader.name.trim().split(RegExp(r'\s+')).first,
                      days(leader.currentStreak),
                    ),
                  ),
                if (me != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tealSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _rankingText(
                        '$positionº',
                        'Você',
                        days(me.currentStreak),
                        highlighted: true,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _rankingText(
    String position,
    String name,
    String days, {
    bool highlighted = false,
  }) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$position  ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: highlighted ? AppColors.tealDark : AppColors.primaryDark,
            ),
          ),
          TextSpan(
            text: name,
            style: TextStyle(
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          TextSpan(text: ' · $days'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );
  }
}

// Estado vazio de "Suas ligas"
class LeagueEmptyCard extends StatelessWidget {
  final VoidCallback onTap;

  const LeagueEmptyCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tealSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.group_outlined,
              size: 24,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhuma liga ainda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Crie uma liga ou entre com um código.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

// Atalhos "Histórico" e "Conquistas"
class ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ShortcutCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: AppColors.tealDark),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
