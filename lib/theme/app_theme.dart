import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
class AppTheme {
  // Warna Utama
  static const Color primaryLight = Color(0xFFFF758F); // Light Pink
  static const Color primary = Color.fromARGB(255, 255, 77, 109); // Medium Pink
  static const Color primaryDark = Color(0xFFC9184A); // Dark Pink

  // Warna Pendukung
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFB00020);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);

  // Font Styles menggunakan Google Fonts
  static final TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.poppins(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: textPrimary,
    ),
    displayMedium: GoogleFonts.poppins(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    displaySmall: GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    headlineMedium: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    titleLarge: GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: textPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textPrimary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      color: textSecondary,
    ),
  );

  // Custom Theme Data
  static ThemeData get theme {
    return ThemeData(
      // Gunakan Google Fonts untuk default font
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // Warna Utama
      primaryColor: primary,
      primaryColorLight: primaryLight,
      primaryColorDark: primaryDark,

      // Icon Theme
      iconTheme: IconThemeData(
        color: primary,
        size: 24,
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryLight.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Contoh penggunaan icon
  static const IconData homeIcon = Icons.home_outlined;
  static const IconData cartIcon = Icons.shopping_cart_outlined;
  static const IconData profileIcon = Icons.person_outline;
  static const IconData searchIcon = Icons.search;
  static const IconData favoriteIcon = Icons.favorite_border;
  static const IconData addIcon = Icons.add;
  static const IconData removeIcon = Icons.remove;
  static const IconData deleteIcon = Icons.delete_outline;
  static const IconData editIcon = Icons.edit_outlined;
  static const IconData locationIcon = Icons.location_on_outlined;
  static const IconData paymentIcon = Icons.payment_outlined;
  static const IconData notificationIcon = Icons.notifications_outlined;
}
