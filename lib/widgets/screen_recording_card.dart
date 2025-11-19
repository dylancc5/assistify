import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../models/screen_recording.dart';

/// Card widget for displaying a screen recording item
class ScreenRecordingCard extends StatefulWidget {
  final ScreenRecording recording;
  final VoidCallback onDelete;
  final VoidCallback? onPlay;

  const ScreenRecordingCard({
    super.key,
    required this.recording,
    required this.onDelete,
    this.onPlay,
  });

  @override
  State<ScreenRecordingCard> createState() => _ScreenRecordingCardState();
}

class _ScreenRecordingCardState extends State<ScreenRecordingCard> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() async {
    if (_controller == null) {
      // Initialize video player
      _controller = VideoPlayerController.file(File(widget.recording.filePath));

      try {
        await _controller!.initialize();
        setState(() {
          _isInitialized = true;
        });

        _controller!.addListener(() {
          if (!mounted) return;

          // Check if video finished
          if (_controller!.value.position >= _controller!.value.duration) {
            setState(() {
              _isPlaying = false;
            });
            _controller!.seekTo(Duration.zero);
            _controller!.pause();
          }
        });

        await _controller!.play();
        setState(() {
          _isPlaying = true;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing video: $e')),
          );
        }
      }
    } else {
      // Toggle play/pause
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _controller!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this screen recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.accentCoral),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d, y \'at\' h:mm a').format(widget.recording.timestamp);

    return Card(
      elevation: AppDimensions.cardElevation,
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video player or thumbnail
          if (_isInitialized && _controller != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.borderRadiusSmall),
              ),
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.buttonGray,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.borderRadiusSmall),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.videocam,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

          // Recording details
          Padding(
            padding: const EdgeInsets.all(AppDimensions.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      widget.recording.formattedDuration,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      '•',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      widget.recording.formattedSize,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.sm),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _togglePlayback,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          side: const BorderSide(color: AppColors.primaryBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
                          ),
                        ),
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Pause' : 'Play'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    IconButton(
                      onPressed: _showDeleteConfirmation,
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.accentCoral,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
