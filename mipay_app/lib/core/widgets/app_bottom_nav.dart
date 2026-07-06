import 'package:flutter/material.dart';

/// One destination in [AppBottomNav]: an outline icon for the inactive state
/// and a filled icon for the active state, plus its label.
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Custom bottom navigation bar: muted outline icons when inactive, full
/// color filled icon + label when active. Replaces the Material
/// [NavigationBar] with the same destinations/behavior.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final inactive = theme.colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == currentIndex
                              ? destinations[i].activeIcon
                              : destinations[i].icon,
                          color: i == currentIndex ? active : inactive,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destinations[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                i == currentIndex ? FontWeight.w600 : FontWeight.w400,
                            color: i == currentIndex ? active : inactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
