import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VoiceMarketing.ai design tokens.
///
/// Hard constraint: every colour traces back to one of five source hues.
/// The "neutrals" are derived from those hues (cool ink = darkened teal,
/// warm paper = lightened blush) — no raw grey, no pure black.
class AppColors {
  // Source hues (accents / surfaces only — never a bed for white text).
  static const azure = Color(0xFF42CAFD);
  static const teal = Color(0xFF66B3BA);
  static const sage = Color(0xFF8EB19D);
  static const yellow = Color(0xFFF6EFA6);
  static const blush = Color(0xFFF0D2D1);

  // Tints of the source hues.
  static const azureSoft = Color(0xFFD6F1FD);
  static const tealSoft = Color(0xFFDCEDEF);
  static const sageSoft = Color(0xFFE1ECE5);
  static const blushSoft = Color(0xFFFBEDEC);

  // Warm paper ramp — lightened blush (~6°).
  static const paper0 = Color(0xFFFAF5F4); // app canvas
  static const paper1 = Color(0xFFF4ECEB); // raised cards
  static const line = Color(0xFFE8DAD9); // hairlines

  // Cool ink ramp — darkened teal (~190°).
  static const ink950 = Color(0xFF0E191B); // max ink
  static const ink800 = Color(0xFF1A2A2E); // strong headings
  static const ink600 = Color(0xFF3F555A); // secondary text
  static const ink400 = Color(0xFF6F8A90); // meta only

  // Dark studio — spent only on the generating + playback payoff.
  static const studio0 = Color(0xFF0E191B);
  static const studio1 = Color(0xFF16282C);
  static const studioLine = Color(0xFF26454B);
  static const studioText = Color(0xFFC6D6D9);
  static const studioMeta = Color(0xFF7E999E);
}

/// Fraunces — humanist serif carrying the personality ("your idea, narrated").
TextStyle serif({
  required double size,
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.ink950,
  double height = 1.1,
  double letterSpacing = -0.01,
}) =>
    GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

/// Hanken Grotesk — warm humanist sans, tuned for small-size legibility.
TextStyle sans({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink800,
  double height = 1.4,
  double letterSpacing = 0,
}) =>
    GoogleFonts.hankenGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

/// Tracked micro-label (uppercase eyebrows, step counters).
TextStyle micro({Color color = AppColors.ink400}) => GoogleFonts.hankenGrotesk(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1,
      letterSpacing: 1.6,
    );

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper0,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.azure,
      secondary: AppColors.teal,
      surface: AppColors.paper0,
      onPrimary: AppColors.ink950,
      onSurface: AppColors.ink950,
    ),
    textTheme: GoogleFonts.hankenGroteskTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink800, displayColor: AppColors.ink950),
    splashColor: AppColors.azure.withValues(alpha: 0.10),
    highlightColor: AppColors.azure.withValues(alpha: 0.06),
  );
}
