import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';

/// Reusable loading indicator widget matching the app's design.
class SlyceLoadingWidget extends StatelessWidget {
  final String? message;

  const SlyceLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryGreen),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: GoogleFonts.inter(fontSize: 14, color: kGreyColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}


