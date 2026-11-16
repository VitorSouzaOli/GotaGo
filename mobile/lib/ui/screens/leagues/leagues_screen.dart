import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/league_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/league_provider.dart';
import '../../widgets/footer_note.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/tab_header.dart';
import '../home/widgets/home_cards.dart';
import 'widgets/league_form_sheet.dart';

// Aba "Ligas": criar/entrar, ligas do utilizador e ranking da liga selecionada
class LeaguesScreen extends StatelessWidget {
  final VoidCallback onAvatarTap;

  const LeaguesScreen({super.key, required this.onAvatarTap});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createLeague(BuildContext context, UserModel user) async {
    final result = await showLeagueFormSheet(context, LeagueFormMode.create);
    if (result == null || !context.mounted) return;

    final leagueProvider = context.read<LeagueProvider>();
    final success = await leagueProvider.create(
      userId: user.id,
      name: result.name,
      description: result.description,
    );
    if (!context.mounted) return;

    _showMessage(
      context,
      success
          ? 'Liga "${result.name}" criada! Convide seus amigos.'
          : leagueProvider.errorMessage ?? 'Não foi possível criar a liga.',
    );
  }

  Future<void> _joinLeague(BuildContext context, UserModel user) async {
    final result = await showLeagueFormSheet(context, LeagueFormMode.join);
    if (result == null || !context.mounted) return;

    final leagueProvider = context.read<LeagueProvider>();
    final success = await leagueProvider.join(
      userId: user.id,
      code: result.code,
    );
    if (!context.mounted) return;

    _showMessage(
      context,
      success
          ? 'Você entrou na liga "${leagueProvider.selected?.name}"!'
          : leagueProvider.errorMessage ?? 'Não foi possível entrar na liga.',
    );
  }

  Future<void> _invite(BuildContext context, LeagueModel league) async {
    await Clipboard.setData(ClipboardData(text: league.code));
    if (!context.mounted) return;
    _showMessage(
      context,
      'Código ${league.code} copiado. Envie para seus amigos!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    // Durante o logout o utilizador some antes da navegação
    if (user == null) return const SizedBox.shrink();

    final leagueProvider = context.watch<LeagueProvider>();
    final leagues = leagueProvider.leagues;
    final selected = leagueProvider.selected;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.tealDark,
        onRefresh: () => leagueProvider.load(user.id, force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            TabHeader(
              title: 'Ligas',
              subtitle: 'Juntos, fica mais fácil manter o hábito.',
              trailing: GestureDetector(
                onTap: onAvatarTap,
                child: InitialsAvatar(
                  name: user.name,
                  size: 40,
                  highlighted: true,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _ActionButtons(
              isBusy: leagueProvider.isSubmitting,
              onCreate: () => _createLeague(context, user),
              onJoin: () => _joinLeague(context, user),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Suas ligas',
              actionLabel: leagues.isEmpty
                  ? null
                  : '${leagues.length} ${leagues.length == 1 ? 'liga' : 'ligas'}',
            ),
            const SizedBox(height: 12),
            if (leagueProvider.isLoading && leagues.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.tealDark),
                ),
              )
            else if (selected == null)
              const _EmptyLeagues()
            else ...[
              _LeagueSelector(
                leagues: leagues,
                selectedId: selected.id,
                onSelect: leagueProvider.select,
              ),
              const SizedBox(height: 16),
              _RankingCard(
                league: selected,
                user: user,
                onInvite: () => _invite(context, selected),
              ),
            ],
            const SizedBox(height: 20),
            const FooterNote(
              'Cada registro conta em todas as suas ligas. O que vale é a '
              'constância, não beber mais.',
            ),
          ],
        ),
      ),
    );
  }
}

// "+ Criar liga" e "Entrar com código"
class _ActionButtons extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _ActionButtons({
    required this.isBusy,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isBusy ? null : onCreate,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            icon: const Icon(
              Icons.add_rounded,
              size: 20,
              color: AppColors.limeAccent,
            ),
            label: const Text('Criar liga'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : onJoin,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.tealDark,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.confirmation_number_outlined, size: 18),
            label: const FittedBox(child: Text('Entrar com código')),
          ),
        ),
      ],
    );
  }
}

// Cards das ligas lado a lado; o selecionado fica escuro
class _LeagueSelector extends StatelessWidget {
  final List<LeagueModel> leagues;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _LeagueSelector({
    required this.leagues,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        // Duas ligas por tela; com mais, a linha rola na horizontal
        final cardWidth = (constraints.maxWidth - gap) / 2;

        return SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: leagues.length,
            separatorBuilder: (_, _) => const SizedBox(width: gap),
            itemBuilder: (context, index) {
              final league = leagues[index];
              return SizedBox(
                width: cardWidth,
                child: _LeagueChip(
                  league: league,
                  selected: league.id == selectedId,
                  onTap: () => onSelect(league.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LeagueChip extends StatelessWidget {
  final LeagueModel league;
  final bool selected;
  final VoidCallback onTap;

  const _LeagueChip({
    required this.league,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final participants =
        '${league.memberCount} '
        '${league.memberCount == 1 ? 'participante' : 'participantes'}';

    return Material(
      color: selected ? AppColors.primaryDark : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      league.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? AppColors.white
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: AppColors.limeAccent,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                participants,
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? AppColors.limeAccent
                      : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                selected ? 'Liga selecionada' : 'Ver classificação →',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.white : AppColors.tealDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Ranking de constância da liga selecionada
class _RankingCard extends StatelessWidget {
  final LeagueModel league;
  final UserModel user;
  final VoidCallback onInvite;

  const _RankingCard({
    required this.league,
    required this.user,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final position = league.positionOf(user.id);
    final people =
        '${league.memberCount} ${league.memberCount == 1 ? 'pessoa' : 'pessoas'}';

    return HomeCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  child: const Icon(
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        position != null
                            ? '$people · você está em $positionº'
                            : people,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.ringTrack),
            const SizedBox(height: 14),
            const Text(
              'Ranking de constância',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const Text(
              'Dias consecutivos de meta cumprida',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            // Key por liga: ao trocar de liga, o ranking volta a ficar recolhido
            _RankingList(
              key: ValueKey(league.id),
              league: league,
              userId: user.id,
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.tealSoft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onInvite,
                borderRadius: BorderRadius.circular(14),
                child: const SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.share_outlined,
                        size: 18,
                        color: AppColors.tealDark,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Convidar amigos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Compartilhe o código de convite único da liga: ${league.code}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Top 3 do ranking (mais a posição do utilizador, se estiver abaixo),
// com a opção de expandir para todos os membros
class _RankingList extends StatefulWidget {
  final LeagueModel league;
  final String userId;

  const _RankingList({super.key, required this.league, required this.userId});

  @override
  State<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<_RankingList> {
  static const _collapsedCount = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ranking = widget.league.ranking;
    final myPosition = widget.league.positionOf(widget.userId);
    final canExpand = ranking.length > _collapsedCount;

    // Índices (0-based) das linhas visíveis
    final visible = <int>[
      for (int i = 0; i < ranking.length; i++)
        if (_expanded || i < _collapsedCount || i + 1 == myPosition) i,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in visible)
          _RankingRow(
            position: i + 1,
            member: ranking[i],
            isMe: ranking[i].id == widget.userId,
          ),
        if (canExpand)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? 'Mostrar menos'
                    : 'Ver ranking completo (${ranking.length})',
              ),
            ),
          ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int position;
  final LeagueMember member;
  final bool isMe;

  const _RankingRow({
    required this.position,
    required this.member,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = member.name.trim().split(RegExp(r'\s+')).first;
    final days = member.currentStreak;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? AppColors.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$positionº',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isMe ? AppColors.tealDark : AppColors.textSecondary,
              ),
            ),
          ),
          InitialsAvatar(name: member.name, size: 34, highlighted: isMe),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? 'Você' : firstName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                if (isMe)
                  Text(
                    '$firstName · sua posição',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$days ${days == 1 ? 'dia' : 'dias'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLeagues extends StatelessWidget {
  const _EmptyLeagues();

  @override
  Widget build(BuildContext context) {
    return const HomeCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Icon(Icons.groups_outlined, size: 40, color: AppColors.tealDark),
            SizedBox(height: 10),
            Text(
              'Você ainda não está em nenhuma liga',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Crie uma liga e convide seus amigos, ou entre com o código '
              'que alguém compartilhou com você.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
