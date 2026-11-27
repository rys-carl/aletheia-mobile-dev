import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';

/// Bottom bar with four tabs (Home, Albums, Calendar, Map) and a round "+"
/// button in the middle.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.onAdd,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 12,
      shadowColor: AppColors.shadow,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: () => onSelected(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.photo_album_outlined,
                  selectedIcon: Icons.photo_album_rounded,
                  label: 'Albums',
                  selected: currentIndex == 1,
                  onTap: () => onSelected(1),
                ),
              ),
              _AddButton(onTap: onAdd),
              Expanded(
                child: _NavItem(
                  icon: Icons.calendar_month_outlined,
                  selectedIcon: Icons.calendar_month_rounded,
                  label: 'Calendar',
                  selected: currentIndex == 2,
                  onTap: () => onSelected(2),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.map_outlined,
                  selectedIcon: Icons.map_rounded,
                  label: 'Map',
                  selected: currentIndex == 3,
                  onTap: () => onSelected(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textHint;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Tooltip(
        message: 'New memory',
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.add, color: AppColors.onPrimary, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
