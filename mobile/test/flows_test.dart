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
import 'package:gotago/ui/navigation/shell_controller.dart';
import 'package:gotago/ui/screens/home/home_shell.dart';

// Storage em memória; as rotas respondem pelo modo demo (MockApiInterceptor)
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

  @override
  Future<void> clearStorage() async => storage.clear();
}

// As outras abas ficam montadas (IndexedStack): rola só a lista visível
final _visibleList = find.byType(Scrollable).hitTestable().first;

void main() {
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

  // Espera as respostas da demo (~0,4 s cada) e as animações
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
  }

  Future<void> openApp(WidgetTester tester) async {
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
          ChangeNotifierProvider(create: (_) => ShellController()),
        ],
        child: MaterialApp(theme: AppTheme.current, home: const HomeShell()),
      ),
    );
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: _visibleList,
    );
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  testWidgets('Outra quantidade → Registrar água → Água registrada!', (
    tester,
  ) async {
    await openApp(tester);
    await tapText(tester, 'Outra quantidade');
    expect(find.text('Registrar água'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '300');
    await tester.pump();
    await tapText(tester, 'Registrar 300 ml');

    expect(find.text('Água registrada!'), findsOneWidget);
    expect(find.text('+300 ml'), findsOneWidget);
  });

  testWidgets('Entrar com código: inválido e depois RITMO6', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Ligas').last);
    await settle(tester);
    await tapText(tester, 'Entrar com código');

    await tester.enterText(find.byType(TextFormField), 'XXXXXX');
    await tapText(tester, 'Buscar liga');
    expect(find.text('Vamos conferir esse código'), findsOneWidget);

    // Ao digitar de novo, a tela sai do estado de erro
    await tester.enterText(find.byType(TextFormField), 'RITMO6');
    await tester.pump();
    expect(find.text('Entre em uma liga'), findsOneWidget);
    await tapText(tester, 'Buscar liga');
    expect(find.text('Esta é a sua equipe?'), findsOneWidget);
    expect(find.text('Ritmo de água'), findsOneWidget);

    await tapText(tester, 'Entrar na liga');
    expect(find.text('Você está na liga!'), findsOneWidget);
  });

  testWidgets('Sair da conta pede confirmação', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Perfil').last);
    await settle(tester);
    await tapText(tester, 'Sair da conta');

    expect(find.text('Sair da sua conta?'), findsOneWidget);
    await tester.tap(find.text('Continuar no aplicativo'));
    await settle(tester);
    expect(find.text('Sair da sua conta?'), findsNothing);
  });

  testWidgets('Aparência: escolher Escuro e salvar', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Perfil').last);
    await settle(tester);
    await tapText(tester, 'Preferências e notificações');
    await tapText(tester, 'Aparência');

    await tapText(tester, 'Menos luminosidade, com contraste confortável.');
    await tapText(tester, 'Salvar aparência');
    expect(settings.settings.appearance, 'dark');
  });
}
