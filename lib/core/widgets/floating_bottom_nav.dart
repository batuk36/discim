import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Map<int, int> badgeCounts;

  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badgeCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.textDark,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavItem(icon: Icons.grid_view_rounded,      index: 0, currentIndex: currentIndex, onTap: onTap, badge: badgeCounts[0] ?? 0),
            _NavItem(icon: Icons.calendar_month_rounded, index: 1, currentIndex: currentIndex, onTap: onTap, badge: badgeCounts[1] ?? 0),
            _NavItem(icon: Icons.chat_bubble_rounded,    index: 2, currentIndex: currentIndex, onTap: onTap, badge: badgeCounts[2] ?? 0),
            _NavItem(icon: Icons.person_rounded,         index: 3, currentIndex: currentIndex, onTap: onTap, badge: badgeCounts[3] ?? 0),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final int currentIndex;
  final Function(int) onTap;
  final int badge;

  const _NavItem({
    required this.icon,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 20 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white38,
              size: 22,
            ),
          ),
          if (badge > 0)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
