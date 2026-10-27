import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF256F7B);
  static const secondary = Color(0xFFD56B72);
  static const ink = Color(0xFF15233B);
  static const body = Color(0xFF35445D);
  static const muted = Color(0xFF59697D);
  static const surface = Color(0xFFFFFFFF);
  static const softSurface = Color(0xFFF6F9FC);
  static const lavender = Color(0xFFEEE8FB);
  static const mint = Color(0xFFE1F3EB);
  static const peach = Color(0xFFFFF0DF);
  static const rose = Color(0xFFFBE7ED);
  static const sky = Color(0xFFE3EFFF);
  static const border = Color(0xFFD9E2EA);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      error: const Color(0xFFB4233C),
      onError: Colors.white,
      primaryContainer: sky,
      secondaryContainer: lavender,
      tertiaryContainer: peach,
      surface: surface,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F7FA),
      fontFamily: 'MyAapthaRoboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 24,color:ink,fontWeight:FontWeight.w500),
        displayMedium: TextStyle(fontSize: 24,color:ink,fontWeight:FontWeight.w500),
        displaySmall: TextStyle(fontSize: 24,color:ink,fontWeight:FontWeight.w500),
        headlineLarge: TextStyle(fontSize: 24,color:ink,fontWeight:FontWeight.w500),
        headlineMedium: TextStyle(fontSize: 20,color:ink,fontWeight:FontWeight.w500),
        headlineSmall: TextStyle(fontSize: 18,color:ink,fontWeight:FontWeight.w500),
        titleLarge: TextStyle(fontSize: 20,color:ink,fontWeight:FontWeight.w500),
        titleMedium: TextStyle(fontSize: 18,color:ink,fontWeight:FontWeight.w500),
        titleSmall: TextStyle(fontSize: 14,color:ink,fontWeight:FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 14,color:body,height:1.5),
        bodyMedium: TextStyle(fontSize: 14,color:body,height:1.5),
        bodySmall: TextStyle(fontSize: 12,color:muted,height:1.5),
        labelLarge: TextStyle(fontSize: 14,fontWeight:FontWeight.w500),
        labelMedium: TextStyle(fontSize: 13,fontWeight:FontWeight.w500),
        labelSmall: TextStyle(fontSize: 12,fontWeight:FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(minimumSize:const Size(44,44),backgroundColor:sky,foregroundColor:ink,elevation:0,textStyle:const TextStyle(fontFamily:'MyAapthaRoboto',fontSize: 14,fontWeight:FontWeight.w500),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize:const Size(44,44),foregroundColor:primary,side:const BorderSide(color:border),textStyle:const TextStyle(fontFamily:'MyAapthaRoboto',fontSize: 14,fontWeight:FontWeight.w500),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
      textButtonTheme: TextButtonThemeData(style:TextButton.styleFrom(minimumSize:const Size(44,44),foregroundColor:primary,textStyle:const TextStyle(fontFamily:'MyAapthaRoboto',fontSize: 14,fontWeight:FontWeight.w500))),
      popupMenuTheme:const PopupMenuThemeData(color:surface,textStyle:TextStyle(fontFamily:'MyAapthaRoboto',fontSize: 14,color:ink)),
      dialogTheme:const DialogThemeData(backgroundColor:surface,titleTextStyle:TextStyle(fontFamily:'MyAapthaRoboto',fontSize: 20,color:ink,fontWeight:FontWeight.w500),contentTextStyle:TextStyle(fontFamily:'MyAapthaRoboto',fontSize: 14,color:body,height:1.5)),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: ink,
        titleTextStyle:
            TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFDCE6EC)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        errorMaxLines: 3,
        helperMaxLines: 3,
        errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFB4233C)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 2)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(fontFamily: 'MyAapthaRoboto', fontSize: 14, color: ink, fontWeight: FontWeight.w500),
        subtitleTextStyle: TextStyle(fontFamily: 'MyAapthaRoboto', fontSize: 12, color: muted, height: 1.4),
        iconColor: primary,
      ),
      dividerTheme: const DividerThemeData(color: border, space: 16, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontFamily:'MyAapthaRoboto',fontSize: 14,fontWeight: FontWeight.w500),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 64,
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFE7F1F3),
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFFF8FAFC)),
      chipTheme: ChipThemeData(
        backgroundColor: lavender,
        selectedColor: sky,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
