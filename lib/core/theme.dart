import 'package:flutter/material.dart';

class AppTheme {
  static const String appFontFamily = 'Pretendard';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: appFontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueAccent,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: appFontFamily,
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: appFontFamily),
        bodyMedium: TextStyle(fontFamily: appFontFamily),
        titleLarge: TextStyle(fontFamily: appFontFamily),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(fontFamily: appFontFamily),
        hintStyle: TextStyle(fontFamily: appFontFamily),
        errorStyle: TextStyle(fontFamily: appFontFamily),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
