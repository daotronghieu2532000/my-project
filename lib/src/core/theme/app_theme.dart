import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const primaryColor = Colors.red; // red color
  const scaffoldBg = Color(0xFFF6F7FB);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: primaryColor,
    primary: primaryColor,
    brightness: Brightness.light,
  );

  // Shopee dùng system fonts: -apple-system (iOS), HelveticaNeue, Roboto (Android), Arial
  // Flutter sẽ tự động dùng system font phù hợp:
  // - iOS: San Francisco (SF Pro)
  // - Android: Roboto
  // Không chỉ định fontFamily để dùng system font mặc định (giống Shopee)
  final textTheme = ThemeData.light().textTheme.copyWith(
    // Regular (400) - cho body text
    bodyLarge: const TextStyle(
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    bodyMedium: const TextStyle(
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    bodySmall: const TextStyle(
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    // Medium (500) - cho labels
    labelLarge: const TextStyle(
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    labelMedium: const TextStyle(
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    labelSmall: const TextStyle(
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    // Bold (600-700) - cho titles
    titleLarge: const TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    titleMedium: const TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    titleSmall: const TextStyle(
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    // Display styles
    displayLarge: const TextStyle(
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    displayMedium: const TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    displaySmall: const TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    headlineLarge: const TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    headlineMedium: const TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    headlineSmall: const TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBg,
    // Áp dụng system fonts (như Shopee): San Francisco trên iOS, Roboto trên Android
    // Không chỉ định fontFamily để Flutter tự động dùng system font phù hợp
    textTheme: textTheme,
    // Áp dụng cho các widget Material
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
    ),
  );
}


