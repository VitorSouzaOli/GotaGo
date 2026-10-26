import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gotago/core/theme/app_theme.dart';
import 'package:gotago/providers/achievement_provider.dart';
import 'package:gotago/providers/auth_provider.dart';
import 'package:gotago/providers/water_provider.dart';
import 'package:gotago/services/api_service.dart';
import 'package:gotago/ui/screens/welcome/welcome_screen.dart';

void main() {
  // Fonte real do app: a fonte padrão dos testes tem letras largas e
  // causaria overflows que não acontecem no aparelho
  setUpAll(() async {
    final loader = FontLoader(AppTheme.fontFamily);
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final bytes = File('assets/fonts/PlusJakartaSans-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  Future<void> openFromWelcome(WidgetTester tester, String button) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final apiService = ApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
          ChangeNotifierProvider(create: (_) => WaterProvider(apiService)),
          ChangeNotifierProvider(create: (_) => AchievementProvider(apiService)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const WelcomeScreen(),
        ),
      ),
    );

    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
  }

  testWidgets('Boas-vindas abre o Login', (tester) async {
    await openFromWelcome(tester, 'Já tenho conta · Entrar');
    expect(find.text('Bom te ver de novo!'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Boas-vindas abre o Cadastro', (tester) async {
    await openFromWelcome(tester, 'Criar minha conta');
    expect(find.text('Bora começar?'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Confirmar senha'), findsOneWidget);
  });

  testWidgets('Cadastro recusa senhas diferentes', (tester) async {
    await openFromWelcome(tester, 'Criar minha conta');

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Vitor');
    await tester.enterText(fields.at(1), 'vitor@gotago.com');
    await tester.enterText(fields.at(2), 'gota2026');
    await tester.enterText(fields.at(3), 'gota2025');
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    expect(find.text('As senhas não são iguais'), findsOneWidget);
  });
}
