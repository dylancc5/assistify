import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../providers/app_state_provider.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../utils/localization_helper.dart';
import '../l10n/app_localizations.dart';

/// History screen showing conversation history
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  /// Get localized formatted date/time string
  String _getLocalizedDateTime(BuildContext context, Conversation conversation) {
    final l10n = LocalizationHelper.of(context);
    final timestamp = conversation.timestamp;
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    String dayPart;
    if (difference.inDays == 0) {
      dayPart = l10n.today;
    } else if (difference.inDays == 1) {
      dayPart = l10n.yesterday;
    } else if (difference.inDays < 7) {
      dayPart = _getLocalizedWeekday(l10n, timestamp);
    } else {
      dayPart = '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }

    return '$dayPart, ${_formatLocalizedTime(l10n, timestamp)}';
  }

  /// Get localized weekday
  String _getLocalizedWeekday(AppLocalizations l10n, DateTime date) {
    switch (date.weekday) {
      case 1: return l10n.monday;
      case 2: return l10n.tuesday;
      case 3: return l10n.wednesday;
      case 4: return l10n.thursday;
      case 5: return l10n.friday;
      case 6: return l10n.saturday;
      case 7: return l10n.sunday;
      default: return '';
    }
  }

  /// Format time with localized AM/PM
  String _formatLocalizedTime(AppLocalizations l10n, DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? l10n.pm : l10n.am;
    return '$hour:$minute $period';
  }

  /// Get localized formatted duration string
  String _getLocalizedDuration(BuildContext context, Conversation conversation) {
    final l10n = LocalizationHelper.of(context);
    final minutes = conversation.duration.inMinutes;
    final seconds = conversation.duration.inSeconds % 60;
    return l10n.durationFormat(minutes, seconds);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final colors = AppColorScheme(
      isHighContrast: appState.preferences.highContrastEnabled,
    );

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
          LocalizationHelper.of(context).history,
          style: AppTextStyles.heading.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_sweep,
              color: appState.conversations.isEmpty
                  ? colors.textSecondary.withValues(alpha: 0.5)
                  : colors.textPrimary,
            ),
            onPressed: appState.conversations.isEmpty
                ? null
                : () => _showClearAllDialog(context, colors),
            tooltip: LocalizationHelper.of(context).clearAll,
          ),
        ],
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          final conversations = appState.conversations;

          // Show empty state if no conversations
          if (conversations.isEmpty) {
            return _buildEmptyState(colors);
          }

          // Show conversation list
          return _buildConversationList(context, conversations, colors);
        },
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(AppColorScheme colors) {
    return Builder(
      builder: (context) {
        final l10n = LocalizationHelper.of(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: colors.textSecondary,
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  l10n.noConversationsYet,
                  style: AppTextStyles.heading.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  l10n.yourConversationsWithAssistifyWillAppearHere,
                  style: AppTextStyles.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build conversation list
  Widget _buildConversationList(
    BuildContext context,
    List<Conversation> conversations,
    AppColorScheme colors,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _buildConversationCard(context, conversation, colors);
      },
    );
  }

  /// Build conversation card
  Widget _buildConversationCard(
    BuildContext context,
    Conversation conversation,
    AppColorScheme colors,
  ) {
    return Card(
      elevation: AppDimensions.cardElevation,
      margin: const EdgeInsets.only(bottom: AppDimensions.sm + AppDimensions.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        side: colors.isHighContrast
            ? BorderSide(color: colors.border, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          // Navigate to conversation detail
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ConversationDetailScreen(
                conversation: conversation,
              ),
            ),
          );
        },
        onLongPress: () {
          _showDeleteDialog(context, conversation);
        },
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date/Time
              Text(
                _getLocalizedDateTime(context, conversation),
                style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
              ),

              const SizedBox(height: AppDimensions.sm),

              // Preview Text
              Text(
                conversation.previewText,
                style: AppTextStyles.body.copyWith(color: colors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppDimensions.sm),

              // Duration
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Text(
                    _getLocalizedDuration(context, conversation),
                    style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteDialog(BuildContext context, Conversation conversation) {
    final l10n = LocalizationHelper.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteConversation),
        content: Text(l10n.areYouSureYouWantToDeleteThisConversation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Provider.of<AppStateProvider>(context, listen: false)
                  .deleteConversation(conversation.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.conversationDeleted)),
              );
            },
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// Show clear all conversations confirmation dialog
  void _showClearAllDialog(BuildContext context, AppColorScheme colors) {
    final l10n = LocalizationHelper.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(
          l10n.clearAllConversations,
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          l10n.areYouSureYouWantToClearAllConversations,
          style: TextStyle(color: colors.textPrimary),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
          side: colors.isHighContrast
              ? BorderSide(color: colors.border, width: 2)
              : BorderSide.none,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: colors.isHighContrast ? colors.textPrimary : null,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Provider.of<AppStateProvider>(context, listen: false)
                  .clearAllConversations();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.allConversationsCleared)),
              );
            },
            child: Text(
              l10n.clearAll,
              style: TextStyle(
                color: colors.isHighContrast ? Colors.red[300] : Colors.red,
                fontWeight: colors.isHighContrast ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conversation detail screen showing full transcript
class ConversationDetailScreen extends StatelessWidget {
  final Conversation conversation;

  const ConversationDetailScreen({
    super.key,
    required this.conversation,
  });

  /// Get localized formatted date/time string
  String _getLocalizedDateTime(BuildContext context) {
    final l10n = LocalizationHelper.of(context);
    final timestamp = conversation.timestamp;
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    String dayPart;
    if (difference.inDays == 0) {
      dayPart = l10n.today;
    } else if (difference.inDays == 1) {
      dayPart = l10n.yesterday;
    } else if (difference.inDays < 7) {
      dayPart = _getLocalizedWeekday(l10n, timestamp);
    } else {
      dayPart = '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }

    return '$dayPart, ${_formatLocalizedTime(l10n, timestamp)}';
  }

  String _getLocalizedWeekday(AppLocalizations l10n, DateTime date) {
    switch (date.weekday) {
      case 1: return l10n.monday;
      case 2: return l10n.tuesday;
      case 3: return l10n.wednesday;
      case 4: return l10n.thursday;
      case 5: return l10n.friday;
      case 6: return l10n.saturday;
      case 7: return l10n.sunday;
      default: return '';
    }
  }

  String _formatLocalizedTime(AppLocalizations l10n, DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? l10n.pm : l10n.am;
    return '$hour:$minute $period';
  }

  String _getLocalizedDuration(BuildContext context) {
    final l10n = LocalizationHelper.of(context);
    final minutes = conversation.duration.inMinutes;
    final seconds = conversation.duration.inSeconds % 60;
    return l10n.durationFormat(minutes, seconds);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final colors = AppColorScheme(
      isHighContrast: appState.preferences.highContrastEnabled,
    );

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
          _getLocalizedDateTime(context),
          style: AppTextStyles.heading.copyWith(
            color: colors.textPrimary,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: conversation.messages.isNotEmpty
          ? _buildMessageList(context, colors)
          : _buildFullTranscript(context, colors),
    );
  }

  /// Build message list with speech bubbles
  Widget _buildMessageList(BuildContext context, AppColorScheme colors) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: conversation.messages.length + 1, // +1 for duration header
      itemBuilder: (context, index) {
        if (index == 0) {
          // Duration header
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.md),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  _getLocalizedDuration(context),
                  style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          );
        }

        final message = conversation.messages[index - 1];
        return _buildMessageBubble(message, colors);
      },
    );
  }

  /// Build a single message bubble
  Widget _buildMessageBubble(Message message, AppColorScheme colors) {
    final timeString = _formatMessageTime(message.timestamp);
    final isAgent = message.sender == MessageSender.agent;

    return Align(
      alignment: isAgent ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(
          bottom: AppDimensions.sm,
          left: isAgent ? 0 : AppDimensions.xl,
          right: isAgent ? AppDimensions.xl : 0,
        ),
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: isAgent
              ? colors.textSecondary.withValues(alpha: colors.isHighContrast ? 0.3 : 0.15)
              : colors.primaryBlue.withValues(alpha: colors.isHighContrast ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
          border: colors.isHighContrast
              ? Border.all(
                  color: isAgent ? colors.textSecondary : colors.primaryBlue,
                  width: 2,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: isAgent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            SelectableText(
              message.text,
              style: AppTextStyles.body.copyWith(
                height: 1.4,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              timeString,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format message timestamp
  String _formatMessageTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Build full transcript view (fallback for old conversations)
  Widget _buildFullTranscript(BuildContext context, AppColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duration info
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.xs),
              Text(
                _getLocalizedDuration(context),
                style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Full transcript
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
              border: colors.isHighContrast
                  ? Border.all(color: colors.border, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SelectableText(
              conversation.fullTranscript ?? conversation.previewText,
              style: AppTextStyles.body.copyWith(
                height: 1.6,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
