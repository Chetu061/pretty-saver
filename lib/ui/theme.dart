import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const brandGradient = LinearGradient(
  colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), Color(0xFF515BD4)],
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
);

/// Fonts offered in Settings. "Default" is the phone's own font.
const appFonts = ['Default', 'Poppins', 'Nunito', 'Montserrat', 'Quicksand'];

/// Text styled in [font], used to preview each choice in the picker.
TextStyle fontPreview(String font, TextStyle base) =>
    font == 'Default' ? base : GoogleFonts.getFont(font, textStyle: base);

ThemeData buildTheme(Brightness brightness, String font) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFDD2A7B), brightness: brightness);
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
  if (font == 'Default') return base;
  return base.copyWith(textTheme: GoogleFonts.getTextTheme(font, base.textTheme));
}
