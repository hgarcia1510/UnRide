import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta estilo Uber: monocromática (negro/blanco) con acentos puntuales.
class Paleta {
  static const negro = Color(0xFF000000);
  static const blanco = Color(0xFFFFFFFF);
  static const gris50 = Color(0xFFF6F6F6);
  static const gris100 = Color(0xFFEEEEEE);
  static const gris200 = Color(0xFFE2E2E2);
  static const gris500 = Color(0xFF757575);
  static const gris800 = Color(0xFF282828);
  static const gris900 = Color(0xFF161616);
  static const azul = Color(0xFF276EF1);
  static const verde = Color(0xFF05A357);
  static const rojo = Color(0xFFE11900);
  static const ambar = Color(0xFFFFC043);
}

ThemeData temaUniRaite(Brightness brillo) {
  final oscuro = brillo == Brightness.dark;
  final esquema = ColorScheme(
    brightness: brillo,
    primary: oscuro ? Paleta.blanco : Paleta.negro,
    onPrimary: oscuro ? Paleta.negro : Paleta.blanco,
    primaryContainer: oscuro ? Paleta.gris800 : Paleta.gris100,
    onPrimaryContainer: oscuro ? Paleta.blanco : Paleta.negro,
    secondary: Paleta.azul,
    onSecondary: Paleta.blanco,
    secondaryContainer: oscuro ? const Color(0xFF1B2A4A) : const Color(0xFFEEF3FE),
    onSecondaryContainer: oscuro ? const Color(0xFFB7CCF9) : const Color(0xFF174291),
    tertiary: Paleta.verde,
    onTertiary: Paleta.blanco,
    tertiaryContainer: oscuro ? const Color(0xFF0D3321) : const Color(0xFFE6F2ED),
    onTertiaryContainer: oscuro ? const Color(0xFF9BDDBB) : const Color(0xFF0D572F),
    error: Paleta.rojo,
    onError: Paleta.blanco,
    errorContainer: oscuro ? const Color(0xFF4A1408) : const Color(0xFFFFEFED),
    onErrorContainer: oscuro ? const Color(0xFFFFB4A6) : const Color(0xFF870F00),
    surface: oscuro ? Paleta.negro : Paleta.blanco,
    onSurface: oscuro ? Paleta.blanco : Paleta.negro,
    onSurfaceVariant: oscuro ? const Color(0xFFAFAFAF) : Paleta.gris500,
    surfaceContainerLowest: oscuro ? Paleta.negro : Paleta.blanco,
    surfaceContainerLow: oscuro ? Paleta.gris900 : Paleta.gris50,
    surfaceContainer: oscuro ? Paleta.gris900 : Paleta.gris50,
    surfaceContainerHigh: oscuro ? Paleta.gris800 : Paleta.gris100,
    surfaceContainerHighest: oscuro ? Paleta.gris800 : Paleta.gris100,
    outline: oscuro ? const Color(0xFF545454) : Paleta.gris200,
    outlineVariant: oscuro ? Paleta.gris800 : Paleta.gris100,
    inverseSurface: oscuro ? Paleta.blanco : Paleta.negro,
    onInverseSurface: oscuro ? Paleta.negro : Paleta.blanco,
    shadow: Paleta.negro,
    scrim: Paleta.negro,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: esquema, brightness: brillo);
  final texto = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    headlineLarge: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
    headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
    headlineSmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    labelLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
  ).apply(bodyColor: esquema.onSurface, displayColor: esquema.onSurface);

  final relleno = esquema.surfaceContainerHigh;
  final botonForma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

  return base.copyWith(
    textTheme: texto,
    scaffoldBackgroundColor: esquema.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: esquema.surface,
      foregroundColor: esquema.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: texto.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: relleno,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: esquema.onSurface, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: esquema.error, width: 1.5),
      ),
      hintStyle: TextStyle(color: esquema.onSurfaceVariant),
      prefixIconColor: esquema.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: esquema.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: botonForma,
        textStyle: texto.labelLarge?.copyWith(fontSize: 17),
        backgroundColor: esquema.primary,
        foregroundColor: esquema.onPrimary,
        disabledBackgroundColor: relleno,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: botonForma,
        foregroundColor: esquema.onSurface,
        backgroundColor: relleno,
        side: BorderSide.none,
        textStyle: texto.labelLarge?.copyWith(fontSize: 17),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: esquema.onSurface, textStyle: texto.labelLarge),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: esquema.primary,
      foregroundColor: esquema.onPrimary,
      elevation: 2,
      shape: const StadiumBorder(),
      extendedTextStyle: texto.labelLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: esquema.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? esquema.onSurface : esquema.onSurfaceVariant,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 26,
            color: s.contains(WidgetState.selected) ? esquema.onSurface : esquema.onSurfaceVariant,
          )),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: relleno,
      selectedColor: esquema.primary,
      labelStyle: texto.labelLarge?.copyWith(fontSize: 14),
      secondaryLabelStyle: texto.labelLarge?.copyWith(fontSize: 14, color: esquema.onPrimary),
      checkmarkColor: esquema.onPrimary,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: esquema.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: esquema.outline,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: esquema.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: texto.titleLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: esquema.inverseSurface,
      contentTextStyle: texto.bodyMedium?.copyWith(color: esquema.onInverseSurface, fontWeight: FontWeight.w500),
      actionTextColor: oscuro ? Paleta.azul : const Color(0xFF8DB2F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: esquema.outlineVariant, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: esquema.onSurface,
      titleTextStyle: texto.titleMedium,
      subtitleTextStyle: texto.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: esquema.onSurface),
    badgeTheme: const BadgeThemeData(backgroundColor: Paleta.rojo, textColor: Paleta.blanco),
  );
}
