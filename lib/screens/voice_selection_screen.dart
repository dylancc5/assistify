import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../providers/app_state_provider.dart';
import '../services/tts_service.dart';
import '../utils/localization_helper.dart';

/// Screen for selecting TTS voices for English and Chinese
class VoiceSelectionScreen extends StatefulWidget {
  const VoiceSelectionScreen({super.key});

  @override
  State<VoiceSelectionScreen> createState() => _VoiceSelectionScreenState();
}

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen> {
  final TTSService _ttsService = TTSService();
  List<Map<String, String>> _englishVoices = [];
  List<Map<String, String>> _chineseVoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await _ttsService.getAvailableVoices();
    setState(() {
      _englishVoices = voices['english'] ?? [];
      _chineseVoices = voices['chinese'] ?? [];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final colors = AppColorScheme(
      isHighContrast: appState.preferences.highContrastEnabled,
    );
    final l10n = LocalizationHelper.of(context);

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
          l10n.voiceSelection,
          style: AppTextStyles.heading.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.primaryBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // English voices section
                  _buildVoiceSection(
                    context: context,
                    title: l10n.english,
                    voices: _englishVoices,
                    selectedVoiceId: appState.preferences.englishVoiceId,
                    onVoiceSelected: (voiceId) {
                      appState.updatePreferences(
                        appState.preferences.copyWith(englishVoiceId: voiceId),
                      );
                    },
                    colors: colors,
                    l10n: l10n,
                  ),

                  const SizedBox(height: AppDimensions.lg),

                  // Chinese voices section
                  _buildVoiceSection(
                    context: context,
                    title: l10n.chinese,
                    voices: _chineseVoices,
                    selectedVoiceId: appState.preferences.chineseVoiceId,
                    onVoiceSelected: (voiceId) {
                      appState.updatePreferences(
                        appState.preferences.copyWith(chineseVoiceId: voiceId),
                      );
                    },
                    colors: colors,
                    l10n: l10n,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildVoiceSection({
    required BuildContext context,
    required String title,
    required List<Map<String, String>> voices,
    required String? selectedVoiceId,
    required ValueChanged<String> onVoiceSelected,
    required AppColorScheme colors,
    required dynamic l10n,
  }) {
    return Card(
      elevation: AppDimensions.cardElevation,
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
              style: AppTextStyles.bodyLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            if (voices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.noVoicesAvailable,
                      style: AppTextStyles.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      l10n.downloadVoicesInSettings,
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.isHighContrast ? colors.border : colors.divider,
                    width: colors.isHighContrast ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusSmall,
                  ),
                  color: colors.background,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedVoiceId != null &&
                            voices.any((v) => v['id'] == selectedVoiceId)
                        ? selectedVoiceId
                        : voices.first['id'],
                    isExpanded: true,
                    dropdownColor: colors.cardBackground,
                    style: AppTextStyles.body.copyWith(
                      color: colors.textPrimary,
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: colors.textSecondary,
                    ),
                    items: voices.map((voice) {
                      final name = voice['name'] ?? '';
                      final quality = voice['quality'] ?? 'default';
                      final isEnhanced = quality == 'enhanced';

                      return DropdownMenuItem<String>(
                        value: voice['id'],
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: AppTextStyles.body.copyWith(
                                  color: colors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isEnhanced)
                              Container(
                                margin: const EdgeInsets.only(left: AppDimensions.xs),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.enhanced,
                                  style: AppTextStyles.caption.copyWith(
                                    color: colors.primaryBlue,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onVoiceSelected(value);
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
