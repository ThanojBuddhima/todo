import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme textTheme(Brightness brightness) => GoogleFonts.interTextTheme(
        brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      );

  static TextStyle heading(BuildContext context) =>
      GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 24);

  static TextStyle title(BuildContext context) =>
      GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18);

  static TextStyle body(BuildContext context) =>
      GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14);
}
