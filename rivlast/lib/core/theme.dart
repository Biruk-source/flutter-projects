import 'package:flutter/material.dart';
import 'package:rivlast/core/constants.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppConstants.lightPrimaryColor,
    colorScheme: ColorScheme.light(
      primary: AppConstants.lightPrimaryColor,
      secondary: AppConstants.lightAccentColor,
      surface: AppConstants.lightCardColor,
      background: AppConstants.lightBackgroundColor,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: AppConstants.lightTextColor,
      onBackground: AppConstants.lightTextColor,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppConstants.lightBackgroundColor,
    appBarTheme: const AppBarTheme(
      color: AppConstants.lightPrimaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AppConstants.lightPrimaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppConstants.lightCardColor, // Text field background
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: AppConstants.lightPrimaryColor,
          width: 2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: AppConstants.lightLightTextColor),
      hintStyle: const TextStyle(color: AppConstants.lightLightTextColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppConstants.lightCardColor,
      selectedColor: AppConstants.lightPrimaryColor,
      labelStyle: const TextStyle(color: AppConstants.lightTextColor),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppConstants.lightLightTextColor),
      ),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.1),
    ),
    textTheme: _buildTextTheme(
      AppConstants.lightTextColor,
      AppConstants.lightLightTextColor,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppConstants.darkPrimaryColor,
    colorScheme: ColorScheme.dark(
      primary: AppConstants.darkPrimaryColor,
      secondary: AppConstants.darkAccentColor,
      surface: AppConstants.darkCardColor,
      background: AppConstants.darkBackgroundColor,
      onPrimary: Colors.black, // Dark primary text
      onSecondary: Colors.black,
      onSurface: AppConstants.darkTextColor,
      onBackground: AppConstants.darkTextColor,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppConstants.darkBackgroundColor,
    appBarTheme: const AppBarTheme(
      color: AppConstants.darkBackgroundColor, // Darker app bar for dark mode
      foregroundColor: AppConstants.darkTextColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppConstants.darkTextColor,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: AppConstants.darkTextColor, // Button text color
        backgroundColor: AppConstants.darkPrimaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppConstants.darkCardColor, // Text field background
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: AppConstants.darkPrimaryColor,
          width: 2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: AppConstants.darkLightTextColor),
      hintStyle: const TextStyle(color: AppConstants.darkLightTextColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppConstants.darkCardColor,
      selectedColor: AppConstants.darkPrimaryColor,
      labelStyle: const TextStyle(color: AppConstants.darkTextColor),
      secondaryLabelStyle: const TextStyle(
        color: Colors.black,
      ), // For selected chip label (on a dark background)
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppConstants.darkLightTextColor),
      ),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.3),
    ),
    textTheme: _buildTextTheme(
      AppConstants.darkTextColor,
      AppConstants.darkLightTextColor,
    ),
  );

  static TextTheme _buildTextTheme(Color textColor, Color lightTextColor) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 57, color: textColor),
      displayMedium: TextStyle(fontSize: 45, color: textColor),
      displaySmall: TextStyle(fontSize: 36, color: textColor),
      headlineLarge: TextStyle(fontSize: 32, color: textColor),
      headlineMedium: TextStyle(fontSize: 28, color: textColor),
      headlineSmall: TextStyle(fontSize: 24, color: textColor),
      titleLarge: TextStyle(
        fontSize: 22,
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(fontSize: 16, color: textColor),
      bodyLarge: TextStyle(fontSize: 16, color: textColor),
      bodyMedium: TextStyle(fontSize: 14, color: textColor),
      bodySmall: TextStyle(fontSize: 12, color: lightTextColor),
      labelLarge: TextStyle(
        fontSize: 14,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: TextStyle(fontSize: 12, color: lightTextColor),
      labelSmall: TextStyle(fontSize: 11, color: lightTextColor),
    );
  }
}
