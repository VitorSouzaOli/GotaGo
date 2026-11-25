import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/achievement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/league_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/water_provider.dart';
import '../achievements/achievements_screen.dart';
import '../history/history_screen.dart';
import '../leagues/leagues_screen.dart';
import '../profile/profile_page.dart';
import '../profile/profile_screen.dart';
import '../settings/help_screen.dart';
import '../settings/preferences_screen.dart';
import '../settings/privacy_screen.dart';
import '../settings/reminders_screen.dart';
import '../../navigation/shell_controller.dart';
import 'home_tab.dart';

// Tela principal com a barra de navegação inferior
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Aba e subtela do Perfil ficam no ShellController (ver shell_controller.dart)
  ShellController get _shell => context.read<ShellController>();

  @override
  void initState() {
    super.initState();

    // Carrega os dados do utilizador logado depois do primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user == null) return;
      context.read<WaterProvider>().load(user.id);
      context.read<AchievementProvider>().load(user.id);
      context.read<LeagueProvider>().load(user.id);
      context.read<SettingsProvider>().load();
    });
  }

  void _goTo(int index) {
    _shell.goTo(index);
    // O ranking muda com os registros de todos: atualiza ao abrir a aba Ligas
    final user = context.read<AuthProvider>().user;
    if (index == ShellTab.leagues && user != null) {
      context.read<LeagueProvider>().load(user.id, force: true);
    }
  }

  void _openProfilePage(ProfilePage page) => _shell.openProfilePage(page);

  void _backToProfile() => _openProfilePage(ProfilePage.main);

  Widget _buildProfileTab(ProfilePage profilePage) {
    // Key por subtela: cada uma começa do topo e com estado novo
    return KeyedSubtree(
      key: ValueKey(profilePage),
      child: switch (profilePage) {
        ProfilePage.main => ProfileScreen(onOpenPage: _openProfilePage),
        ProfilePage.achievements => AchievementsScreen(onBack: _backToProfile),
        ProfilePage.reminders => RemindersScreen(onBack: _backToProfile),
        ProfilePage.preferences => PreferencesScreen(
          onBack: _backToProfile,
          onOpenReminders: () => _openProfilePage(ProfilePage.reminders),
        ),
        ProfilePage.help => HelpScreen(onBack: _backToProfile),
        ProfilePage.privacy => PrivacyScreen(onBack: _backToProfile),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final inSubpage = shell.profilePage != ProfilePage.main;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayStyle,
      // O "voltar" do Android fecha a subtela do Perfil antes de sair do app
      child: PopScope(
        canPop: !inSubpage,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _backToProfile();
        },
        child: Scaffold(
          body: IndexedStack(
            index: shell.tab,
            children: [
              HomeTab(
                onNavigate: _goTo,
                onOpenAchievements: () =>
                    _openProfilePage(ProfilePage.achievements),
              ),
              LeaguesScreen(onAvatarTap: () => _goTo(ShellTab.profile)),
              const HistoryScreen(),
              _buildProfileTab(shell.profilePage),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.tab,
            onDestinationSelected: _goTo,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Início',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group_rounded),
                label: 'Ligas',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_rounded),
                label: 'Histórico',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
