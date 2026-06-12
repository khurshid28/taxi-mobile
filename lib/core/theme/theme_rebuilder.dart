import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// Tema (yorug'/qorong'i/tizim) o'zgarganda o'z ichidagi sahifani **darhol**
/// qayta quradi.
///
/// Sabab: ilova ranglari [AppColors] static getter'lar orqali o'qiladi va ular
/// `Theme`'ga (InheritedWidget) bog'lanmaydi. Shuning uchun tema almashganda
/// `Theme.of()` ishlatmagan widgetlar o'zicha yangilanmaydi - faqat reload yoki
/// navigatsiyadan keyin. Bu widget [ThemeController] va tizim yorqinligini
/// tinglab, [builder] ni qayta chaqiradi.
///
/// MUHIM: [builder] har safar **yangi** (const bo'lmagan) sahifa nusxasini
/// qaytarishi kerak. Shunda Flutter sahifaning `build()` ini qayta ishga
/// tushiradi (yangi ranglar bilan), lekin uning `State`'ini (masalan, xarita
/// kontrolleri) saqlab qoladi.
class ThemeRebuilder extends StatefulWidget {
  const ThemeRebuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<ThemeRebuilder> createState() => _ThemeRebuilderState();
}

class _ThemeRebuilderState extends State<ThemeRebuilder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.mode.addListener(_onChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    ThemeController.instance.mode.removeListener(_onChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangePlatformBrightness() {
    // Tizim rejimida OS mavzusi almashsa ham sahifani yangilaymiz.
    if (mounted &&
        ThemeController.instance.mode.value == ThemeMode.system) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
