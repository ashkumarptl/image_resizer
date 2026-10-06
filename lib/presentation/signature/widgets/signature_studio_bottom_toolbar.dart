import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

enum SignatureStudioTool { clean, ink, compress, dimensions }

class SignatureStudioBottomToolbar extends StatelessWidget {
  final SignatureStudioTool activeTool;
  final ValueChanged<SignatureStudioTool> onToolSelected;
  final bool isDark;

  const SignatureStudioBottomToolbar({
    super.key,
    required this.activeTool,
    required this.onToolSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black45
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToolButton(
                context,
                tool: SignatureStudioTool.clean,
                icon: Icons.auto_fix_high_rounded,
                label: 'CLEAN',
                isActive: activeTool == SignatureStudioTool.clean,
                onTap: () => onToolSelected(SignatureStudioTool.clean),
              ),
              _buildToolButton(
                context,
                tool: SignatureStudioTool.ink,
                icon: Icons.palette_outlined,
                label: 'INK COLOR',
                isActive: activeTool == SignatureStudioTool.ink,
                onTap: () => onToolSelected(SignatureStudioTool.ink),
              ),
              _buildToolButton(
                context,
                tool: SignatureStudioTool.compress,
                icon: Icons.compress_rounded,
                label: 'TARGET KB',
                isActive: activeTool == SignatureStudioTool.compress,
                onTap: () => onToolSelected(SignatureStudioTool.compress),
              ),
              _buildToolButton(
                context,
                tool: SignatureStudioTool.dimensions,
                icon: Icons.aspect_ratio_rounded,
                label: 'DIMENSIONS',
                isActive: activeTool == SignatureStudioTool.dimensions,
                onTap: () => onToolSelected(SignatureStudioTool.dimensions),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required SignatureStudioTool tool,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    String? badge,
  }) {
    final activeColor = AppColors.primary;
    final inactiveColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isActive
                            ? activeColor.withValues(alpha: 0.14)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: isActive ? activeColor : inactiveColor,
                      ),
                    ),
                    if (badge != null && !isActive)
                      Positioned(
                        top: -2,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? activeColor : inactiveColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
