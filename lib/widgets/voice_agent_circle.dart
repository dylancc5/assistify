import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';

/// Voice agent circle widget with breathing animation
class VoiceAgentCircle extends StatefulWidget {
  final double size;

  const VoiceAgentCircle({
    super.key,
    this.size = AppDimensions.voiceAgentCircleSize,
  });

  @override
  State<VoiceAgentCircle> createState() => _VoiceAgentCircleState();
}

class _VoiceAgentCircleState extends State<VoiceAgentCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Setup breathing animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start infinite breathing animation
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.voiceAgentGradientStart,
              AppColors.voiceAgentGradientEnd,
            ],
          ),
          border: Border.all(
            color: AppColors.voiceAgentBorder,
            width: AppDimensions.voiceAgentBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _SmileyFace(
            size: AppDimensions.voiceAgentIconSize,
            color: AppColors.voiceAgentIcon,
          ),
        ),
      ),
    );
  }
}

/// Simple smiley face widget with two eyes and a smile
class _SmileyFace extends StatelessWidget {
  final double size;
  final Color color;

  const _SmileyFace({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate proportional sizes
    final eyeSize = size * 0.15;
    final eyeSpacing = size * 0.25;
    final smileWidth = size * 0.4;
    final smileHeight = size * 0.15;
    final smileTopOffset = size * 0.15;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SmileyFacePainter(
          eyeSize: eyeSize,
          eyeSpacing: eyeSpacing,
          smileWidth: smileWidth,
          smileHeight: smileHeight,
          smileTopOffset: smileTopOffset,
          color: color,
        ),
      ),
    );
  }
}

class _SmileyFacePainter extends CustomPainter {
  final double eyeSize;
  final double eyeSpacing;
  final double smileWidth;
  final double smileHeight;
  final double smileTopOffset;
  final Color color;

  _SmileyFacePainter({
    required this.eyeSize,
    required this.eyeSpacing,
    required this.smileWidth,
    required this.smileHeight,
    required this.smileTopOffset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw left eye
    canvas.drawCircle(
      Offset(centerX - eyeSpacing, centerY - eyeSize),
      eyeSize / 2,
      paint,
    );

    // Draw right eye
    canvas.drawCircle(
      Offset(centerX + eyeSpacing, centerY - eyeSize),
      eyeSize / 2,
      paint,
    );

    // Draw smile (curved line)
    final smilePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = eyeSize * 0.3
      ..strokeCap = StrokeCap.round;

    final smilePath = Path();
    final smileStartX = centerX - smileWidth / 2;
    final smileEndX = centerX + smileWidth / 2;
    final smileY = centerY + smileTopOffset;

    // Create a curved smile
    smilePath.moveTo(smileStartX, smileY);
    smilePath.quadraticBezierTo(
      centerX,
      smileY + smileHeight,
      smileEndX,
      smileY,
    );

    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
