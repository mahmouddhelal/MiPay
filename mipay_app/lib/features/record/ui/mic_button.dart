import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final color = widget.isRecording ? colorScheme.error : colorScheme.primary;

    return ScaleTransition(
      scale: _pulse,
      child: SizedBox(
        width: 112,
        height: 112,
        child: Material(
          shape: const CircleBorder(),
          color: color,
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.isProcessing ? null : widget.onTap,
            child: widget.isProcessing
                ? Padding(
                    padding: const EdgeInsets.all(34),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Icon(
                    widget.isRecording ? Icons.stop : Icons.mic,
                    size: 48,
                    color: colorScheme.onPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}
