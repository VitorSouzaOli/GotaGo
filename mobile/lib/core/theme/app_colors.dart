import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Cores do app. As cores da marca são fixas; as de superfície e texto mudam
// com o tema (claro/escuro), por isso são getters e não podem ir em `const`.
class AppColors {
  // Tema ativo. Quem muda é o GotaGoApp (main.dart), que reconstrói a árvore.
  static bool isDark = false;

  static Color _pick(Color light, Color dark) => isDark ? dark : light;

  // ---- Variam com o tema ----

  // Fundo menta (escuro: petróleo profundo)
  static Color get background =>
      _pick(const Color(0xFFEEF7F2), const Color(0xFF0D2A2F));

  // Texto principal e botão primário. No escuro vira quase branco.
  static Color get primaryDark =>
      _pick(const Color(0xFF0B3B3C), const Color(0xFFE8F5F3));
  static Color get primaryDarkLight =>
      _pick(const Color(0xFF17585B), const Color(0xFFB8D8D4));

  // Superfície dos cards e conteúdo sobre o botão primário.
  // É sempre o "oposto" de primaryDark (no escuro, um card petróleo).
  static Color get white => _pick(Colors.white, const Color(0xFF16383E));

  // Links, ícones e item ativo da navegação
  static Color get tealDark =>
      _pick(const Color(0xFF0E8496), const Color(0xFF5FD8DC));

  // Botões rápidos, chips e destaque da navegação
  static Color get tealSoft =>
      _pick(const Color(0xFFE4F3F2), const Color(0xFF1F4A50));

  // Trilho do anel de hidratação
  static Color get ringTrack =>
      _pick(const Color(0xFFE1EFEB), const Color(0xFF27505A));

  // Barra do Histórico em dia que não bateu a meta
  static Color get barPartial =>
      _pick(const Color(0xFF9FD3DA), const Color(0xFF3E7F88));

  // Fundo das conquistas bloqueadas e dos avisos cinza
  static Color get lockedSurface =>
      _pick(const Color(0xFFE3EFEC), const Color(0xFF1C4047));

  static Color get textSecondary =>
      _pick(const Color(0xFF5E6F6C), const Color(0xFF9DB9B6));
  static Color get outlineBorder =>
      _pick(const Color(0xFFBFD8D0), const Color(0xFF2F5960));
  static Color get surfaceLight =>
      _pick(const Color(0xFFF5FBF8), const Color(0xFF16383E));
  static Color get error =>
      _pick(const Color(0xFFC2412D), const Color(0xFFF08A7C));

  // Fundo dos avisos de erro (rosado)
  static Color get errorSurface =>
      _pick(const Color(0xFFFCEDE9), const Color(0xFF3E2A2A));

  // Botão destrutivo ("Excluir", "Sair da conta")
  static Color get danger =>
      _pick(const Color(0xFFA63D3D), const Color(0xFFC9524E));

  // Destaque sobre o botão primário e avatares (seta, iniciais):
  // verde-amarelado no claro; no escuro o botão é claro, então fica escuro
  static Color get onPrimaryAccent =>
      isDark ? const Color(0xFF0B3B3C) : limeAccent;

  // Ícones da barra de status
  static SystemUiOverlayStyle get overlayStyle =>
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

  // ---- Fixas (marca) ----

  // Ciano / Teal (ponto do logo)
  static const Color tealPrimary = Color(0xFF12A3B8);

  // Gradiente da gota (topo → base)
  static const Color dropLight = Color(0xFF2FD0DA);
  static const Color dropDark = Color(0xFF0890A5);

  // Gota ainda clara, no início da animação da splash
  static const Color dropLightPale = Color(0xFF8EE0E3);
  static const Color dropDarkPale = Color(0xFF6CC3CE);

  // Ondas na água
  static const Color ripple = Color(0xFF7FCDD3);

  // Verde-amarelado (seta do botão, card de constância, prato do troféu)
  static const Color limeAccent = Color(0xFFD7EE7C);
  static const Color limeLight = Color(0xFFEFF8C2);

  // Texto sobre o verde-amarelado: sempre escuro, nos dois temas
  static const Color onLime = Color(0xFF0B3B3C);

  // Base do troféu (verde-petróleo fixo)
  static const Color trophyBase = Color(0xFF0B3B3C);
  static const Color trophyBaseLight = Color(0xFF17585B);
}
