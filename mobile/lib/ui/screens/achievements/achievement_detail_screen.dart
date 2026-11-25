import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/achievement_model.dart';
import '../../../providers/achievement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../navigation/shell_controller.dart';
import '../../widgets/flow_page.dart';
import '../profile/profile_page.dart';
import 'achievements_screen.dart';

// Textos de cada conquista (o backend devolve descrições em pt-PT)
({String subtitle, String unlockedBody, String journey}) _copyFor(
  AchievementModel achievement,
) {
  final days = requiredStreakDays(achievement);
  return switch (achievement.code) {
    'FIRST_DROP' => (
      subtitle: 'Todo hábito começa com um primeiro passo.',
      unlockedBody: 'Você registrou seu primeiro copo de água.',
      journey:
          'Continue registrando aos poucos e respeitando suas necessidades.',
    ),
    'STREAK_7_DAYS' => (
      subtitle: 'Sete dias construindo um hábito saudável.',
      unlockedBody: '7 metas cumpridas em dias consecutivos.',
      journey: 'Siga no seu ritmo, sem buscar quantidades extras.',
    ),
    'STREAK_30_DAYS' => (
      subtitle: 'Uma jornada construída dia após dia.',
      unlockedBody: '30 metas cumpridas em dias consecutivos.',
      journey: 'Um mês de cuidado. Continue no seu ritmo.',
    ),
    _ => (
      subtitle: 'Mais um marco na sua jornada.',
      unlockedBody: days > 0
          ? '$days metas cumpridas em dias consecutivos.'
          : achievement.description,
      journey: 'Siga no seu ritmo, sem buscar quantidades extras.',
    ),
  };
}

// Detalhe de uma conquista: desbloqueada, próxima (com progresso) ou bloqueada
class AchievementDetailScreen extends StatelessWidget {
  final AchievementModel achievement;
  // É a próxima conquista de sequência (mostra "6 de 7 dias")
  final bool isNext;

  const AchievementDetailScreen({
    super.key,
    required this.achievement,
    this.isNext = false,
  });

  @override
  Widget build(BuildContext context) {
    final streak = context.watch<AuthProvider>().user?.currentStreak ?? 0;
    final copy = _copyFor(achievement);
    final days = requiredStreakDays(achievement);
    final back = FlowAction(
      achievement.isUnlocked
          ? 'Ver todas as conquistas'
          : 'Voltar às conquistas',
      () => Navigator.pop(context),
    );

    if (achievement.isUnlocked) {
      return FlowPage(
        title: achievement.name,
        subtitle: copy.subtitle,
        illustration: const TrophyIllustration(),
        content: [
          FlowCard(
            eyebrow: days == 0
                ? 'Sua primeira conquista'
                : 'Conquista de constância',
            headline: 'Desbloqueada',
            body: copy.unlockedBody,
          ),
          FlowCard(
            title: days == 0
                ? 'O começo da sua jornada'
                : 'Sua jornada continua',
            body: copy.journey,
          ),
          const NoteCard(
            'Conquistas celebram hábitos. Quantidades extras não aceleram sua '
            'evolução.',
          ),
        ],
        primary: back,
      );
    }

    if (isNext && days > 0) {
      final done = min(streak, days);
      final remaining = days - done;
      return FlowPage(
        title: achievement.name,
        subtitle: days == 7
            ? 'Uma semana de constância está chegando.'
            : 'Sua constância está chegando lá.',
        illustration: const TrophyIllustration(faded: true),
        content: [
          FlowCard(
            eyebrow: 'Conquista bloqueada',
            headline: '$done de $days dias',
            body: 'Complete sua meta por $days dias seguidos.',
          ),
          FlowProgressBar(done / days),
          FlowCard(
            title: remaining == 1 ? 'Falta um dia!' : 'Faltam $remaining dias',
            body:
                'Hoje ainda está em andamento. Mantenha seu ritmo para '
                'completar a sequência.',
          ),
        ],
        primary: back,
      );
    }

    return FlowPage(
      title: achievement.name,
      subtitle: 'Uma jornada construída dia após dia.',
      illustration: const TrophyIllustration(faded: true),
      content: const [
        FlowCard(
          eyebrow: 'Conquista de constância',
          headline: 'Bloqueada',
          body: 'Sua rotina de hidratação ainda está evoluindo.',
        ),
        FlowCard(
          title: 'O foco é o hábito',
          body:
              'Continue acompanhando sua evolução. Beber além da meta não '
              'acelera esta conquista.',
        ),
        NoteCard(
          'Este marco valoriza uma rotina consistente, não grandes volumes em '
          'um só dia.',
        ),
      ],
      primary: back,
    );
  }
}

// Celebração logo após desbloquear ("Uma Semana Perfeita!")
class AchievementUnlockedScreen extends StatelessWidget {
  // Nome da conquista, como o backend devolve em newAchievements
  final String name;

  const AchievementUnlockedScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AchievementProvider>();
    AchievementModel? achievement;
    for (final a in provider.achievements) {
      if (a.name == name) achievement = a;
    }
    final copy = achievement != null ? _copyFor(achievement) : null;

    return FlowPage(
      title: name == 'Semana Perfeita' ? 'Uma Semana Perfeita!' : '$name!',
      subtitle: copy?.subtitle ?? 'Mais um marco na sua jornada.',
      illustration: const TrophyIllustration(),
      content: [
        FlowCard(
          eyebrow: 'Nova conquista',
          headline: 'Desbloqueada',
          body: copy?.unlockedBody ?? 'Você conquistou uma nova medalha.',
        ),
        FlowCard(
          title: 'Sua jornada continua',
          body:
              '${provider.unlockedCount} de ${provider.total} conquistas · '
              'Siga no seu ritmo, sem buscar quantidades extras.',
        ),
      ],
      primary: FlowAction(
        'Ver minhas conquistas',
        () => backToShell(
          context,
          ShellTab.profile,
          profilePage: ProfilePage.achievements,
        ),
      ),
      secondary: FlowAction(
        'Voltar ao início',
        () => backToShell(context, ShellTab.home),
      ),
    );
  }
}
