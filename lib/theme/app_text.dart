import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppText {
  static TextStyle get title => GoogleFonts.mPlusRounded1c(
    fontSize: 28, // Balanced size
    fontWeight: FontWeight.w800, // Extra Bold for impact
    color: AppColors.label,
    letterSpacing: 0.5,
  );

  static TextStyle get body => GoogleFonts.mPlusRounded1c(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5, // Reduced slightly to prevent excessive vertical drift, allowing padding to handle space
    color: AppColors.label,
  );

  static TextStyle get caption => GoogleFonts.mPlusRounded1c(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.secondaryLabel,
    letterSpacing: 1.0, // Spaced out for elegance
  );
}
