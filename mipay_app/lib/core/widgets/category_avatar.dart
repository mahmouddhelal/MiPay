import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A colored circular avatar for a category: a stable, deterministic color
/// (from [AppColors.categoryColor]) with a white icon on top. Reused by the
/// dashboard category list, transaction tiles, and filter chips so the same
/// category always reads as the same color everywhere.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.categoryKey,
    required this.icon,
    this.size = 40,
  });

  final String categoryKey;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(categoryKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}
