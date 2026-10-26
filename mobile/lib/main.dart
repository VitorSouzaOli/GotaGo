import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/achievement_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/water_provider.dart';
import 'services/api_service.dart';
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
      ],
      child: MaterialApp(
        title: 'GotaGo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        // Faixa "DEMO" no canto quando os dados são falsos (MOCK_API=true)
        builder: (context, child) => ApiService.useMock
            ? Banner(
                message: 'DEMO',
                location: BannerLocation.topEnd,
                child: child!,
              )
            : child!,
      ),
    );
  }
}
