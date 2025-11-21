import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_state_provider.dart';
import '../utils/localization_helper.dart';
import '../widgets/legal_document_widgets.dart';

/// Displays the Assistify terms of service in an accessible layout.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
              l10n.termsOfService,
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
                  title: l10n.termsIntroParagraph1,
                  subtitle: l10n.termsIntroParagraph2,
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
        title: l10n.legalAcceptanceTitle,
        paragraphs: [
          l10n.termsAcceptanceBody1,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionServiceTitle,
        paragraphs: [
          l10n.termsSectionServiceBody1,
          l10n.termsSectionServiceBody2,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionEligibilityTitle,
        paragraphs: [
          l10n.termsSectionEligibilityBody1,
          l10n.termsSectionEligibilityBody2,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionPermissionsTitle,
        paragraphs: [
          l10n.termsSectionPermissionsBody1,
        ],
        bullets: [
          l10n.termsSectionPermissionsBulletAccurateInfo,
          l10n.termsSectionPermissionsBulletEnvironment,
          l10n.termsSectionPermissionsBulletNotifications,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionAcceptableUseTitle,
        paragraphs: [
          l10n.termsSectionAcceptableUseBody1,
        ],
        bullets: [
          l10n.termsAcceptableUseBulletMalicious,
          l10n.termsAcceptableUseBulletScams,
          l10n.termsAcceptableUseBulletUnlawful,
          l10n.termsAcceptableUseBulletInterfere,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionAIGuidanceTitle,
        paragraphs: [
          l10n.termsSectionAIGuidanceBody1,
        ],
        bullets: [
          l10n.termsSectionAIGuidanceBulletAccuracy,
          l10n.termsSectionAIGuidanceBulletVerification,
          l10n.termsSectionAIGuidanceBulletEmergencies,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionPrivacyTitle,
        paragraphs: [
          l10n.termsSectionPrivacyBody1,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionThirdPartyTitle,
        paragraphs: [
          l10n.termsSectionThirdPartyBody1,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionAvailabilityTitle,
        paragraphs: [
          l10n.termsSectionAvailabilityBody1,
          l10n.termsSectionAvailabilityBody2,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionTerminationTitle,
        paragraphs: [
          l10n.termsSectionTerminationBody1,
          l10n.termsSectionTerminationBody2,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionDisclaimersTitle,
        paragraphs: [
          l10n.termsSectionDisclaimersBody1,
          l10n.termsSectionDisclaimersBody2,
        ],
      ),
      LegalSectionData(
        title: l10n.termsSectionGoverningLawTitle,
        paragraphs: [
          l10n.termsSectionGoverningLawBody1,
        ],
      ),
    ];
  }
}

