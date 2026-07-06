import 'package:flutter/material.dart';

/// A single segment of a [SegmentedPills] selector.
class PillSegment<T> {
  const PillSegment({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// A pill-styled segmented selector — a thin wrapper around [SegmentedButton]
/// with full-radius (pill) corners, reused for the type toggle (transactions
/// filter, dashboard spending/income) and the settings language switch.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.emptySelectionAllowed = false,
  });

  final List<PillSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool emptySelectionAllowed;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      emptySelectionAllowed: emptySelectionAllowed,
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        visualDensity: VisualDensity.compact,
      ),
      segments: [
        for (final s in segments)
          ButtonSegment(
            value: s.value,
            label: Text(s.label),
            icon: s.icon != null ? Icon(s.icon, size: 16) : null,
          ),
      ],
      selected: selected,
      onSelectionChanged: onChanged,
    );
  }
}
