import 'package:flutter/material.dart';

/// A translucent circular icon button with a label underneath — used in the
/// row of quick actions beneath the dashboard's gradient balance hero.
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.foregroundColor = Colors.white,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color foregroundColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: foregroundColor.withValues(alpha: selected ? 0.35 : 0.18),
              border: selected
                  ? Border.all(color: foregroundColor, width: 1.5)
                  : null,
            ),
            child: Icon(icon, color: foregroundColor, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
