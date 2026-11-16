import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gotago/core/theme/app_theme.dart';
import 'package:gotago/models/user_model.dart';
import 'package:gotago/providers/achievement_provider.dart';
import 'package:gotago/providers/auth_provider.dart';
import 'package:gotago/providers/league_provider.dart';
import 'package:gotago/providers/settings_provider.dart';
import 'package:gotago/providers/water_provider.dart';
import 'package:gotago/services/api_service.dart';
import 'package:gotago/ui/screens/home/home_shell.dart';

// Storage em memória no lugar do flutter_secure_storage (indisponível em testes)
class _FakeApi extends ApiService {
  final storage = <String, String>{};

  @override
  Future<UserModel?> getUser() async => UserModel(
    id: ApiService.mockUserId,
    name: 'Vitor Souza',
    username: 'vitor',
    email: 'vitor@gotago.com',
    dailyGoal: 2500,
    currentStreak: 6,
  );

  @override
  Future<String?> readValue(String key) async => storage[key];

  @override
  Future<void> writeValue(String key, String value) async {
    storage[key] = value;
  }
}

// As outras abas ficam montadas (IndexedStack): rola só a lista visível
final _visibleList = find.byType(Scrollable).hitTestable().first;

void main() {
  // Fonte real do app, para o layout ser o mesmo do aparelho
  setUpAll(() async {
    final loader = FontLoader(AppTheme.fontFamily);
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      final bytes = File('assets/fonts/PlusJakartaSans-$weight.ttf')
          .readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  late SettingsProvider settings;

  Future<void> openProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = _FakeApi();
    final auth = AuthProvider(api);
    await auth.checkAuthStatus();
    settings = SettingsProvider(api);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => WaterProvider(api)),
          ChangeNotifierProvider(create: (_) => AchievementProvider(api)),
          ChangeNotifierProvider(create: (_) => LeagueProvider(api)),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const HomeShell()),
      ),
    );
    // Espera as respostas do modo demo (~0,4 s cada)
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
  }

  Future<void> openItem(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: _visibleList,
    );
    // Garante o item inteiro na tela (e não só a borda) antes de tocar
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  for (final (item, title) in [
    ('Lembretes de hidratação', 'Sua rotina'),
    ('Preferências e notificações', 'Fique por dentro'),
    ('Ajuda e suporte', 'Dúvidas frequentes'),
    ('Privacidade e segurança', 'Acesso à conta'),
  ]) {
    testWidgets('Perfil abre "$item" e volta', (tester) async {
      await openProfile(tester);
      await openItem(tester, item);
      expect(find.text(title), findsOneWidget);

      await tester.tap(find.text('Perfil').first);
      await tester.pumpAndSettle();
      expect(find.text('Do seu jeito'), findsOneWidget);
    });
  }

  testWidgets('Lembretes: desmarcar um dia e salvar', (tester) async {
    await openProfile(tester);
    await openItem(tester, 'Lembretes de hidratação');

    // "D" (domingo) é a única letra que não se repete
    await tester.tap(find.text('D'));
    await tester.pump();
    expect(find.text('6 dias selecionados'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Salvar lembretes'),
      200,
      scrollable: _visibleList,
    );
    await tester.ensureVisible(find.text('Salvar lembretes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar lembretes'));
    await tester.pumpAndSettle();

    expect(settings.settings.weekdays.last, isFalse);
    expect(find.text('Do seu jeito'), findsOneWidget);
  });

  testWidgets('Ajuda: a busca filtra as dúvidas', (tester) async {
    await openProfile(tester);
    await openItem(tester, 'Ajuda e suporte');

    await tester.enterText(find.byType(TextField), 'liga');
    await tester.pump();
    expect(find.text('Como entrar em uma liga?'), findsOneWidget);
    expect(find.text('Como ajustar minha meta?'), findsNothing);
  });
}
