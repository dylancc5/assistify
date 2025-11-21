import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_state_provider.dart';
import '../utils/localization_helper.dart';
import '../widgets/legal_document_widgets.dart';

/// Displays the Assistify privacy policy in an accessible layout.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final colors = AppColorScheme(
          isHighContrast: appState.preferences.highContrastEnabled,
        );
        final l10n = LocalizationHelper.of(context);

        final sections = _buildSections(l10n);

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            elevation: 1,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              l10n.privacyPolicy,
              style: AppTextStyles.heading.copyWith(color: colors.textPrimary),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LegalIntroCard(
                  colors: colors,
                  title: l10n.privacyPolicyIntroParagraph1,
                  subtitle: l10n.privacyPolicyIntroParagraph2,
                  lastUpdated: l10n.legalLastUpdated(
                    l10n.legalLastUpdatedDate,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                ...sections.map(
                  (section) => LegalSectionCard(
                    section: section,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                LegalContactCard(
                  colors: colors,
                  bodyText: l10n.legalContactBody,
                  email: l10n.legalContactEmail,
                ),
                const SizedBox(height: AppDimensions.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  List<LegalSectionData> _buildSections(AppLocalizations l10n) {
    return [
      LegalSectionData(
        title: l10n.privacySectionDataWeCollectTitle,
        paragraphs: [
          l10n.privacySectionDataWeCollectBody1,
        ],
        bullets: [
          l10n.privacyDataWeCollectBulletScreen,
          l10n.privacyDataWeCollectBulletAudio,
          l10n.privacyDataWeCollectBulletPreferences,
          l10n.privacyDataWeCollectBulletDiagnostics,
        ],
      ),
      LegalSectionData(
        title: l10n.privacyHowWeUseTitle,
        paragraphs: [
          l10n.privacyHowWeUseBody1,
          l10n.privacyHowWeUseBody2,
        ],
      ),
      LegalSectionData(
        title: l10n.privacySharingTitle,
        paragraphs: [
          l10n.privacySharingBody1,
        ],
        bullets: [
          l10n.privacySharingBulletVendors,
          l10n.privacySharingBulletCompliance,
          l10n.privacySharingBulletConsent,
        ],
      ),
      LegalSectionData(
        title: l10n.privacySafetyTitle,
        paragraphs: [
          l10n.privacySafetyBody1,
          l10n.privacySafetyBody2,
        ],
      ),
      LegalSectionData(
        title: l10n.privacyStorageTitle,
        paragraphs: [
          l10n.privacyStorageBody1,
          l10n.privacyStorageBody2,
        ],
      ),
      LegalSectionData(
        title: l10n.privacyChoicesTitle,
        paragraphs: [
          l10n.privacyChoicesBody1,
        ],
        bullets: [
          l10n.privacyChoicesBulletPermissions,
          l10n.privacyChoicesBulletHistory,
          l10n.privacyChoicesBulletPreferences,
          l10n.privacyChoicesBulletContact,
        ],
      ),
      LegalSectionData(
        title: l10n.privacyChildrenTitle,
        paragraphs: [
          l10n.privacyChildrenBody1,
        ],
      ),
      LegalSectionData(
        title: l10n.privacyInternationalTitle,
        paragraphs: [
          l10n.privacyInternationalBody1,
        ],
      ),
      LegalSectionData(
        title: l10n.privacyChangesTitle,
        paragraphs: [
          l10n.privacyChangesBody1,
          l10n.privacyChangesBody2,
        ],
      ),
    ];
  }
}

