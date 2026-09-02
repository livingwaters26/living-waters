import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only - the big-button layouts are designed and tested for
  // this. Landscape was allowed before, but the fixed-height sections
  // (caption box, buttons, notes list) don't have enough vertical room in
  // landscape on a tablet and buttons were getting pushed off-screen.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: DrivingNotesApp()));
}

/// One shared seed color for both light and dark themes - a calmer,
/// friendlier blue than the original.
const _seedColor = Color(0xFF0F5A46);

/// Builds a big-touch-target, rounded, friendly theme for the given
/// brightness. Both light and dark themes come from this single function
/// so they always stay in sync.
ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness);

  // Start from Inter (already used) and size everything up a notch across
  // the board - bigger body text, bigger titles, bigger button labels.
  final baseTextTheme = GoogleFonts.interTextTheme(
    isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
  );
  final textTheme = baseTextTheme.copyWith(
    displaySmall: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w700, height: 1.2),
    headlineSmall: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w600, height: 1.45),
    titleLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
    titleMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.inter(fontSize: 19),
    bodyMedium: GoogleFonts.inter(fontSize: 17),
    labelLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
  );

  final roundedShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? colorScheme.surface
        : Color.alphaBlend(colorScheme.primary.withOpacity(0.035), colorScheme.surface),
    textTheme: textTheme,

    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 3,
      toolbarHeight: 68,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 28),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.25),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.primary,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      minVerticalPadding: 18,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(88, 64), // Big touch targets
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        textStyle: textTheme.labelLarge,
        shape: roundedShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 64),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        textStyle: textTheme.labelLarge,
        side: BorderSide(color: colorScheme.primary, width: 2),
        shape: roundedShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: textTheme.labelLarge,
      ),
    ),

    iconTheme: IconThemeData(size: 28, color: colorScheme.onSurface),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      extendedSizeConstraints: const BoxConstraints(minHeight: 68, minWidth: 68),
      extendedTextStyle: textTheme.labelLarge,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 3,
    ),

    checkboxTheme: CheckboxThemeData(
      visualDensity: VisualDensity.comfortable,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 26),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.4 : 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),

    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      contentTextStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
    ),
  );
}

class DrivingNotesApp extends StatelessWidget {
  const DrivingNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driving Notes',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
