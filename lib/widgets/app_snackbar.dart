import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';

/// The kind of feedback a snackbar conveys.
///
/// Only the small leading icon and its tint change between types — the shape,
/// background, text colors, margins and animation stay identical so every
/// message across the whole app looks the same.
enum AppSnackbarType { success, error, info }

/// Brand-error red, kept here so every error message uses the exact same tone
/// instead of Flutter's default `Colors.redAccent`.
const _kErrorRed = Color(0xFFE05246);

/// Shows a single, app-wide consistent snackbar.
///
/// Use this for ALL user messages instead of calling `Get.snackbar` or
/// `ScaffoldMessenger` directly, so the look (rounded card, floating, same
/// margins/colors/typography) is identical everywhere. The optional [title]
/// renders a bold heading; omit it for a clean single-line message.
void showAppSnackbar(
  String message, {
  String? title,
  AppSnackbarType type = AppSnackbarType.info,
}) {
  late final IconData icon;
  late final Color accent;
  switch (type) {
    case AppSnackbarType.success:
      icon = Icons.check_circle_rounded;
      accent = kPrimaryGreen;
      break;
    case AppSnackbarType.error:
      icon = Icons.error_rounded;
      accent = _kErrorRed;
      break;
    case AppSnackbarType.info:
      icon = Icons.info_rounded;
      accent = kDarkColor;
      break;
  }

  // Never stack duplicates when actions fire quickly.
  if (Get.isSnackbarOpen) Get.closeAllSnackbars();

  Get.snackbar(
    title ?? '',
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: kCardColor,
    colorText: kDarkColor,
    borderRadius: 14,
    borderColor: kLightGrey,
    borderWidth: 1,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    duration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 300),
    icon: Icon(icon, color: accent),
    shouldIconPulse: false,
    boxShadows: const [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
    titleText: title == null
        ? const SizedBox.shrink()
        : Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kDarkColor,
            ),
          ),
    messageText: Text(
      message,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: kDarkColor,
      ),
    ),
  );
}
