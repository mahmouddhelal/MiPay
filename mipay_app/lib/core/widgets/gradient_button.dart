import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A full-width, gradient-filled primary call-to-action button — used for
/// the auth screens' submit buttons and the settings Save button.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 52,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: disabled ? null : AppColors.brandGradient,
          color: disabled ? Theme.of(context).disabledColor : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Center(
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                child: IconTheme.merge(
                  data: const IconThemeData(color: Colors.white),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
