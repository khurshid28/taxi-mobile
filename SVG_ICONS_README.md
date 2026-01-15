# SVG Icons Setup Guide

## SVG ikonlarni yuklab olish

Men sizga asosiy SVG ikonlarni yaratib berdim, lekin siz https://www.svgrepo.com/collection/scarlab-duotone-line-vectors/ dan ko'proq ikonlarni yuklab olishingiz mumkin.

### Yaratilgan SVG ikonlar (assets/icons/):

1. ✅ **user_duotone.svg** - Foydalanuvchi profili
2. ✅ **phone_duotone.svg** - Telefon
3. ✅ **location_duotone.svg** - Joylashuv/lokatsiya
4. ✅ **car_duotone.svg** - Mashina
5. ✅ **wallet_duotone.svg** - Hamyon
6. ✅ **clock_duotone.svg** - Soat/vaqt
7. ✅ **check_duotone.svg** - Tasdiqlash belgisi
8. ✅ **close_duotone.svg** - Yopish
9. ✅ **star_duotone.svg** - Yulduz (reytinglar uchun)
10. ✅ **document_duotone.svg** - Hujjat
11. ✅ **card_duotone.svg** - Karta
12. ✅ **search_duotone.svg** - Qidiruv
13. ✅ **message_duotone.svg** - Xabar
14. ✅ **email_duotone.svg** - Email
15. ✅ **calendar_duotone.svg** - Kalendar
16. ✅ **success_duotone.svg** - Muvaffaqiyat

### Qo'shimcha ikonlar uchun:

1. https://www.svgrepo.com/collection/scarlab-duotone-line-vectors/ ga boring
2. Kerakli ikonni toping (masalan, navigation, map, settings, etc.)
3. Ikonni yuklab oling (Download SVG tugmasi)
4. Yuklab olingan SVG faylni `assets/icons/` papkasiga joylashtiring
5. Fayl nomini `icon_name_duotone.svg` formatida qo'ying

### Foydalanish:

```dart
import 'package:flutter_svg/flutter_svg.dart';

// Oddiy SVG
SvgPicture.asset(
  'assets/icons/user_duotone.svg',
  width: 24,
  height: 24,
)

// Rang o'zgartirish (duotone ikonlar uchun - faqat stroke rangini o'zgartiradi)
SvgPicture.asset(
  'assets/icons/phone_duotone.svg',
  width: 24,
  height: 24,
  colorFilter: ColorFilter.mode(
    Colors.blue,
    BlendMode.srcIn,
  ),
)
```

### Keyingi qadamlar:

- [ ] Barcha UI elementlarni zamonaviy dizaynla
- [ ] Shimmer effektlarni qo'shish
- [ ] Bottom sheet'larni yaxshilash
- [ ] Alert dialoglarni modernizatsiya qilish
- [ ] Barcha sahifalarni yangilash

---
**Eslatma:** Barcha SVG ikonlar duotone (ikki rangli) formatida yaratilgan. Ular Flutter'da juda yaxshi ko'rinadi va professional ko'rinish beradi.
