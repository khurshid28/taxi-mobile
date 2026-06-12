import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/theme/app_colors.dart';

/// Silliq, "ideal" surish tugmasi — Liniyaga chiqish uchun.
///
/// Barmoq harakatini to'g'ridan-to'g'ri kuzatadi (AnimationController.value),
/// shuning uchun og'irlik sezilmaydi. Yarmidan oshsa avtomatik yakunlanadi,
/// aks holda silliq orqaga qaytadi.
class SlideToOnlineButton extends StatefulWidget {
  const SlideToOnlineButton({
    super.key,
    required this.onConfirmed,
    this.text = 'Liniyaga chiqish',
    this.icon = Icons.power_settings_new,
  });

  final VoidCallback onConfirmed;
  final String text;
  final IconData icon;

  @override
  State<SlideToOnlineButton> createState() => _SlideToOnlineButtonState();
}

class _SlideToOnlineButtonState extends State<SlideToOnlineButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(double delta, double maxX) {
    if (_confirmed || maxX <= 0) return;
    _ctrl.value = (_ctrl.value + delta / maxX).clamp(0.0, 1.0);
  }

  void _onDragEnd() {
    if (_confirmed) return;
    // Yarmidan (0.6) oshsa — yakunlanadi, qolganini animatsiya bilan to'ldiramiz.
    if (_ctrl.value >= 0.6) {
      _confirmed = true;
      HapticFeedback.mediumImpact();
      _ctrl
          .animateTo(1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut)
          .then((_) {
        if (mounted) widget.onConfirmed();
      });
    } else {
      _ctrl.animateBack(0.0,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = 62.h;
    final double thumb = 54.h;
    const double pad = 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxX = constraints.maxWidth - thumb - pad * 2;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final double pos = _ctrl.value * maxX;
            final double textOpacity = (1 - _ctrl.value * 1.6).clamp(0.0, 1.0);
            return Container(
              height: height,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16.r,
                    offset: Offset(0, 6.h),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Markazdagi matn — surilgan sari yo'qoladi.
                  Center(
                    child: Opacity(
                      opacity: textOpacity,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.text,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            Iconsax.arrow_right_3,
                            color: Colors.white,
                            size: 18.w,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Surma (thumb).
                  Positioned(
                    left: pad + pos,
                    top: (height - thumb) / 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) =>
                          _onDragUpdate(d.delta.dx, maxX),
                      onHorizontalDragEnd: (_) => _onDragEnd(),
                      child: Container(
                        width: thumb,
                        height: thumb,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 8.r,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.icon,
                          color: AppColors.primary,
                          size: 24.w,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
