import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/profile/profile_page.dart';

// Abas da tela principal
class ShellTab {
  static const home = 0;
  static const leagues = 1;
  static const history = 2;
  static const profile = 3;
}

// Aba e subtela do Perfil abertas no HomeShell. Fica acima do Navigator para
// que telas de fluxo abertas por cima ("Voltar ao início", "Ver histórico")
// consigam trocar a aba ao fechar.
class ShellController extends ChangeNotifier {
  int _tab = ShellTab.home;
  ProfilePage _profilePage = ProfilePage.main;

  int get tab => _tab;
  ProfilePage get profilePage => _profilePage;

  void goTo(int tab) {
    _tab = tab;
    // Tocar numa aba volta para a tela principal do Perfil
    _profilePage = ProfilePage.main;
    notifyListeners();
  }

  void openProfilePage(ProfilePage page) {
    _tab = ShellTab.profile;
    _profilePage = page;
    notifyListeners();
  }

  void reset() => goTo(ShellTab.home);
}

// Fecha as telas de fluxo abertas e mostra a aba (ou subtela do Perfil) pedida
void backToShell(BuildContext context, int tab, {ProfilePage? profilePage}) {
  final shell = context.read<ShellController>();
  if (profilePage != null) {
    shell.openProfilePage(profilePage);
  } else {
    shell.goTo(tab);
  }
  Navigator.of(context).popUntil((route) => route.isFirst);
}
