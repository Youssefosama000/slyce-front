import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Palette sampled directly from the Slyce Figma design.
const kBgColor = Color(0xFFFCF7ED); // warm cream background
const kPrimaryGreen = Color(0xFF4CB050); // vibrant brand green
const kDarkGreen = Color(0xFF3D9142); // pressed / darker green
const kDarkColor = Color(0xFF1C1C1C);
const kGreyColor = Color(0xFF9E9E9E);
const kLightGrey = Color(0xFFE6E0D4); // subtle borders / dividers
const kCardColor = Color(0xFFFFFBF3); // near-white cards on cream bg
const kWhite = Color(0xFFFFFFFF);

class AppTheme {
  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: kBgColor,
        colorScheme: const ColorScheme.light(
          primary: kPrimaryGreen,
          surface: kBgColor,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBgColor,
          elevation: 0,
          iconTheme: IconThemeData(color: kDarkColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: kLightGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: kLightGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: kPrimaryGreen, width: 1.5),
          ),
          hintStyle: GoogleFonts.inter(
            color: kGreyColor,
            fontSize: 15,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      );
}


