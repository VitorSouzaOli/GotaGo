import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/achievement_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/league_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/water_provider.dart';
import 'services/api_service.dart';
import 'ui/navigation/shell_controller.dart';
import 'ui/screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Uma única instância do Dio/storage compartilhada por todos os providers
  runApp(MyApp(apiService: ApiService()));
}

class MyApp extends StatelessWidget {
  final ApiService apiService;

  const MyApp({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => WaterProvider(apiService)),
        ChangeNotifierProvider(create: (_) => AchievementProvider(apiService)),
        ChangeNotifierProvider(create: (_) => LeagueProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ShellController()),
        // A aparência é lida já na abertura do app
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(apiService)..load(),
        ),
      ],
      child: const _GotaGoApp(),
    );
  }
}

// Aplica o tema escolhido em Preferências → Aparência (claro, escuro ou sistema)
class _GotaGoApp extends StatefulWidget {
  const _GotaGoApp();

  @override
  State<_GotaGoApp> createState() => _GotaGoAppState();
}

class _GotaGoAppState extends State<_GotaGoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Aparelho trocou entre claro/escuro (vale para a opção "Sistema")
  @override
  void didChangePlatformBrightness() => setState(() {});

  // As cores vêm de getters estáticos (AppColors); marcar todos os elementos
  // para reconstruir faz cada tela ler as cores do tema novo
  void _rebuildAll() {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    if (mounted) (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<SettingsProvider>().settings.appearance;
    final systemDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final dark = appearance == 'dark' || (appearance == 'system' && systemDark);

    if (dark != AppColors.isDark) {
      AppColors.isDark = dark;
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }

    return MaterialApp(
      title: 'GotaGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      home: const SplashScreen(),
      // Faixa "DEMO" no canto quando os dados são falsos (MOCK_API=true)
      builder: (context, child) => ApiService.useMock
          ? Banner(
              message: 'DEMO',
              location: BannerLocation.topEnd,
              child: child!,
            )
          : child!,
    );
  }
}
