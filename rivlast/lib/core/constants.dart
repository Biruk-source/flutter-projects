import 'package:flutter/material.dart';

class AppConstants {
  // Rive Asset Paths - IMPORTANT: Ensure these files exist in your assets/ folder.
  static const String riveLoadingAsset = 'assets/3d_soup-simple-loop.riv';
  static const String riveWelcomeAsset = 'assets/web.riv';
  static const String riveProfileAsset = 'assets/cat_button.riv';
  static const String rivePersonalizedWelcomeAsset = 'assets/untitled.riv';
  static const String riveModeSwitchAsset = 'assets/mode_switch.riv'; // NEW

  // Default Rive State Machine Name (common in Rive files)
  static const String defaultRiveStateMachineName = 'State Machine 1';

  // Specific Rive Input Names (only if your Rive files have these exact inputs)
  // For cat_button.riv, we might try a generic 'Submit' or 'Click' trigger if it exists.
  static const String riveInputSubmitTrigger = 'Submit';
  static const String riveInputErrorTrigger = 'Error';
  // For mode_switch.riv, typically has an 'isDark' boolean input
  static const String riveInputIsDark = 'isDark'; // NEW

  static const List<String> availableInterests = [
    'Fitness',
    'Cooking',
    'Travel',
    'Reading',
    'Coding',
    'Art',
    'Music',
    'Gaming',
    'Gardening',
    'Photography',
    'Writing',
  ];

  static const Color lightPrimaryColor = Color(0xFF6200EE); // Deep Purple
  static const Color lightAccentColor = Color(0xFF03DAC5); // Teal Green
  static const Color lightBackgroundColor = Color(0xFFF0F2F5); // Light Grey
  static const Color lightCardColor = Color(0xFFFFFFFF); // White
  static const Color lightTextColor = Color(0xFF212121); // Dark Grey
  static const Color lightLightTextColor = Color(0xFF757575); // Medium Grey

  static const Color darkPrimaryColor = Color(0xFFBB86FC); // Light Purple
  static const Color darkAccentColor = Color(
    0xFF03DAC5,
  ); // Teal Green (can be same)
  static const Color darkBackgroundColor = Color(0xFF121212); // Very Dark Grey
  static const Color darkCardColor = Color(0xFF1E1E1E); // Dark Grey
  static const Color darkTextColor = Color(0xFFE0E0E0); // Light Grey
  static const Color darkLightTextColor = Color(0xFFB0B0B0); // Lighter Grey
}
