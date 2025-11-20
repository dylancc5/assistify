import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../providers/app_state_provider.dart';
import '../models/conversation.dart';
import '../utils/localization_helper.dart';

/// History screen showing conversation history
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          LocalizationHelper.of(context).history,
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          final conversations = appState.conversations;

          // Show empty state if no conversations
          if (conversations.isEmpty) {
            return _buildEmptyState();
          }

          // Show conversation list
          return _buildConversationList(context, conversations);
        },
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final l10n = LocalizationHelper.of(context);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                l10n.noConversationsYet,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                l10n.yourConversationsWithAssistifyWillAppearHere,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build conversation list
  Widget _buildConversationList(
    BuildContext context,
    List<Conversation> conversations,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _buildConversationCard(context, conversation);
      },
    );
  }

  /// Build conversation card
  Widget _buildConversationCard(
    BuildContext context,
    Conversation conversation,
  ) {
    return Card(
      elevation: AppDimensions.cardElevation,
      margin: const EdgeInsets.only(bottom: AppDimensions.sm + AppDimensions.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
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
                conversation.formattedDateTime,
                style: AppTextStyles.caption,
              ),

              const SizedBox(height: AppDimensions.sm),

              // Preview Text
              Text(
                conversation.previewText,
                style: AppTextStyles.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppDimensions.sm),

              // Duration
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Text(
                    conversation.formattedDuration,
                    style: AppTextStyles.caption,
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
}

/// Conversation detail screen showing full transcript
class ConversationDetailScreen extends StatelessWidget {
  final Conversation conversation;

  const ConversationDetailScreen({
    super.key,
    required this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          conversation.formattedDateTime,
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
      ),
      body: conversation.messages.isNotEmpty
          ? _buildMessageList()
          : _buildFullTranscript(),
    );
  }

  /// Build message list with speech bubbles
  Widget _buildMessageList() {
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
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  conversation.formattedDuration,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          );
        }

        final message = conversation.messages[index - 1];
        return _buildMessageBubble(message);
      },
    );
  }

  /// Build a single message bubble
  Widget _buildMessageBubble(message) {
    final timeString = _formatMessageTime(message.timestamp);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: AppDimensions.sm,
          left: AppDimensions.xl,
        ),
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(
              message.text,
              style: AppTextStyles.body.copyWith(
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              timeString,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
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
  Widget _buildFullTranscript() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duration info
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.xs),
              Text(
                conversation.formattedDuration,
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Full transcript
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
