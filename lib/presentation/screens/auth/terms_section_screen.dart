import 'package:flutter/material.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/terms_content.dart';

/// Full-text viewer for one policy section.
///
/// Tapping a policy name on the sign-up step opens the real text here rather
/// than doing nothing. The sign-up checkbox previously rendered "Terms of
/// Service" and "Privacy Policy" as bold text with no tap handler at all, so a
/// member could tick "I agree" without ever being able to read what they were
/// agreeing to.
class TermsSectionScreen extends StatelessWidget {
  final TermsSection section;

  const TermsSectionScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.scaffoldBackground,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          section.title,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (section.summary.isNotEmpty) ...[
                Text(
                  section.summary,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: CoopvestShape.gapLg),
                Divider(color: context.dividerColor),
                const SizedBox(height: CoopvestShape.gapLg),
              ],
              Text(
                section.body,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}