import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';

class AppNavBar extends StatelessWidget {
  final int currentIndex;
  const AppNavBar({super.key, required this.currentIndex});

  static const List<({IconData icon, IconData activeIcon, String label})> _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Trang chủ'),
    (icon: Icons.confirmation_number_outlined, activeIcon: Icons.confirmation_number, label: 'Vé của tôi'),
    (icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: 'Thông báo'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Tài khoản'),
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/tickets'); break;
      case 2: context.go('/notifications'); break;
      case 3: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final isActive = index == currentIndex;
              return Expanded(
                child: _NavItem(
                  icon: tab.icon,
                  activeIcon: tab.activeIcon,
                  label: tab.label,
                  isActive: isActive,
                  onTap: () => _onTap(context, index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _pillWidthAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: widget.isActive ? 1.0 : 0.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _pillWidthAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pill indicator + Icon
              Stack(
                alignment: Alignment.center,
                children: [
                  // Animated pill background in soft orange
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 54 * _pillWidthAnim.value,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: _pillWidthAnim.value),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  // Icon
                  Transform.scale(
                    scale: _scaleAnim.value,
                    child: Icon(
                      widget.isActive ? widget.activeIcon : widget.icon,
                      size: 23,
                      color: widget.isActive
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.isActive
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(widget.label),
              ),
            ],
          );
        },
      ),
    );
  }
}
