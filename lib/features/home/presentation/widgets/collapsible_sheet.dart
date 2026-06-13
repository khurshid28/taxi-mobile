import 'package:flutter/material.dart';

/// Pastdan chiqadigan varaqni yig'ib/yoyib turadigan o'ram.
///
/// Maqsad: haydovchi varaqni pastga surib xaritani (mijozga yo'l, marker)
/// ko'ra olsin, tepaga torsa yana to'liq ochilsin.
///
/// MUHIM (qotmaslik): bu native YandexMap (platform view) ustida turadi.
/// Shuning uchun UZLUKSIZ (60fps) animatsiya YO'Q — xuddi "Liniyaga chiqish"
/// surilmasi kabi:
///  * barmoq harakati davomida varaq to'g'ridan-to'g'ri barmoqqa ergashadi
///    (`_ctrl.value` qo'lda o'rnatiladi, animatsiya yo'q);
///  * barmoq qo'yib yuborilganda BIR MARTALIK (one-shot) snap animatsiyasi
///    yig'ilgan yoki ochilgan holatga olib boradi.
///
/// Varaq balandligi `GlobalKey` orqali o'lchanadi — yig'ilganda faqat tepadagi
/// [peek] piksel ko'rinib qoladi (handle + sarlavha), qolgani pastga suriladi.
class CollapsibleSheet extends StatefulWidget {
  const CollapsibleSheet({
    super.key,
    required this.child,
    this.peek = 96,
  });

  /// To'liq varaq tarkibi (handle + sarlavha eng tepada bo'lishi kerak).
  final Widget child;

  /// Yig'ilganda ko'rinib turadigan tepa balandlik (piksel).
  final double peek;

  @override
  State<CollapsibleSheet> createState() => _CollapsibleSheetState();
}

class _CollapsibleSheetState extends State<CollapsibleSheet>
    with SingleTickerProviderStateMixin {
  final GlobalKey _childKey = GlobalKey();
  late final AnimationController _ctrl; // 0 = ochiq, 1 = yig'ilgan
  double _height = 0; // o'lchangan varaq balandligi

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Yig'ilganda maksimal pastga surish masofasi.
  double get _maxOffset {
    final m = _height - widget.peek;
    return m > 0 ? m : 0;
  }

  void _measure(_) {
    final h = _childKey.currentContext?.size?.height ?? 0;
    if (h > 0 && (h - _height).abs() > 0.5) {
      setState(() => _height = h);
    }
  }

  void _onDragUpdate(double dy) {
    final max = _maxOffset;
    if (max <= 0) return;
    _ctrl.value = (_ctrl.value + dy / max).clamp(0.0, 1.0);
  }

  void _onDragEnd(double velocityY) {
    // Tez surilsa — yo'nalish bo'yicha; aks holda eng yaqin holatga snap.
    if (velocityY.abs() > 320) {
      _settle(velocityY > 0); // pastga tez -> yig'
    } else {
      _settle(_ctrl.value >= 0.5);
    }
  }

  void _settle(bool collapse) {
    _ctrl.animateTo(
      collapse ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggle() => _settle(_ctrl.value < 0.5);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _ctrl.value * _maxOffset),
          child: child,
        );
      },
      child: Stack(
        children: [
          KeyedSubtree(key: _childKey, child: widget.child),
          // Tepadagi peek qismi — surish/tap shu yerda ushlanadi (handle +
          // sarlavha). Pastdagi tugmalar/skroll bloklanmaydi.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.peek,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggle,
              onVerticalDragUpdate: (d) => _onDragUpdate(d.delta.dy),
              onVerticalDragEnd: (d) =>
                  _onDragEnd(d.velocity.pixelsPerSecond.dy),
            ),
          ),
        ],
      ),
    );
  }
}
