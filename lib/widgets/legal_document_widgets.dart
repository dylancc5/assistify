import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../utils/localization_helper.dart';

/// Data model used to describe each legal section.
class LegalSectionData {
  const LegalSectionData({
    required this.title,
    required this.paragraphs,
    this.bullets = const [],
  });

  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
}

/// Card used for introductory text and metadata.
class LegalIntroCard extends StatelessWidget {
  const LegalIntroCard({
    super.key,
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.lastUpdated,
  });

  final AppColorScheme colors;
  final String title;
  final String subtitle;
  final String lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppDimensions.cardElevation,
      color: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        side: colors.isHighContrast
            ? BorderSide(color: colors.border, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              subtitle,
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              lastUpdated,
              style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget that renders a section with paragraphs and optional bullets.
class LegalSectionCard extends StatelessWidget {
  const LegalSectionCard({
    super.key,
    required this.section,
    required this.colors,
  });

  final LegalSectionData section;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppDimensions.cardElevation,
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      color: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        side: colors.isHighContrast
            ? BorderSide(color: colors.border, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimensions.sm),
            ...section.paragraphs.map(
              (paragraph) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                child: Text(
                  paragraph,
                  style: AppTextStyles.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
            if (section.bullets.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.xs),
              LegalBulletList(items: section.bullets, colors: colors),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bullet list with accessible spacing and contrast.
class LegalBulletList extends StatelessWidget {
  const LegalBulletList({
    super.key,
    required this.items,
    required this.colors,
  });

  final List<String> items;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '•',
                style: AppTextStyles.body.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  item,
                  style: AppTextStyles.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Card with support contact information.
class LegalContactCard extends StatelessWidget {
  const LegalContactCard({
    super.key,
    required this.colors,
    required this.bodyText,
    required this.email,
  });

  final AppColorScheme colors;
  final String bodyText;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppDimensions.cardElevation,
      color: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        side: colors.isHighContrast
            ? BorderSide(color: colors.border, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationHelper.of(context).legalContactHeading,
              style: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              bodyText,
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.sm),
            SelectableText(
              email,
              style: AppTextStyles.body.copyWith(
                color: colors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

