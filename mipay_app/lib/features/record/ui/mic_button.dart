import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The hero mic button: pulsing ring while recording, progress spinner while
/// the server is working.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.isRecording,
    required this.isProcessing,
    required this.onTap,
  });

  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onTap;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.95,
      upperBound: 1.12,
    );
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulse.stop();
      _pulse.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const iconColor = Colors.white;

    return ScaleTransition(
      scale: _pulse,
      child: SizedBox(
        width: 112,
        height: 112,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.brandGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandGradientEnd.withValues(
                  alpha: widget.isRecording ? 0.55 : 0.35,
                ),
                blurRadius: widget.isRecording ? 28 : 18,
                spreadRadius: widget.isRecording ? 4 : 1,
              ),
            ],
          ),
          child: Material(
            shape: const CircleBorder(),
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.isProcessing ? null : widget.onTap,
              child: widget.isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(34),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: iconColor,
                      ),
                    )
                  : Icon(
                      widget.isRecording ? Icons.stop : Icons.mic,
                      size: 48,
                      color: iconColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
