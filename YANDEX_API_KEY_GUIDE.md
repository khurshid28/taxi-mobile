# 🔑 Yandex MapKit API Kalitini Olish Bo'yicha Qo'llanma

## 1-qadam: Yandex Developer konsolasiga kiring

🔗 **Link:** https://developer.tech.yandex.ru/

## 2-qadam: Ro'yxatdan o'ting yoki kiring

1. Yandex akkauntingiz bilan kiring
2. Agar akkauntingiz bo'lmasa, yangi akkount yarating

## 3-qadam: MapKit xizmatini tanlang

1. Developer konsolada "**Сервисы**" (Services) bo'limiga o'ting
2. "**JavaScript API и HTTP Геокодер**" yoki "**MapKit Mobile SDK**" ni toping
3. "**Подключить**" (Connect) tugmasini bosing

## 4-qadam: API kalitini yarating

1. "**Получить ключ**" (Get Key) tugmasini bosing
2. Loyiha nomini kiriting (masalan: "Taxi Mobile")
3. API kalitingiz yaratiladi

## 5-qadam: API kalitini ko'chirib oling

API kalitingiz shu ko'rinishda bo'ladi:
```
a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

## 6-qadam: Loyihangizga qo'shing

### Android uchun:

**Fayl:** `android/app/src/main/AndroidManifest.xml`

Bu qatorni toping:
```xml
<meta-data
    android:name="com.yandex.mapkit.ApiKey"
    android:value="YOUR_YANDEX_API_KEY_HERE"/>
```

`YOUR_YANDEX_API_KEY_HERE` ni o'zingizning API kalitingizga almashtiring:
```xml
<meta-data
    android:name="com.yandex.mapkit.ApiKey"
    android:value="a1b2c3d4-e5f6-7890-abcd-ef1234567890"/>
```

### iOS uchun:

**Fayl:** `ios/Runner/AppDelegate.swift`

Bu qatorni toping:
```swift
YMKMapKit.setApiKey("YOUR_YANDEX_API_KEY_HERE")
```

`YOUR_YANDEX_API_KEY_HERE` ni o'zingizning API kalitingizga almashtiring:
```swift
YMKMapKit.setApiKey("a1b2c3d4-e5f6-7890-abcd-ef1234567890")
```

## 7-qadam: Ishga tushiring

```bash
flutter clean
flutter pub get
flutter run
```

## ⚠️ Muhim eslatmalar:

1. **Bepul limit:** Yandex MapKit kuniga 25,000 gacha so'rovni bepul qo'llab-quvvatlaydi
2. **API kalitni himoya qiling:** Git repositoriyangizda API kalitni oshkor qoldirmang
3. **Restrictions:** Kerak bo'lsa, API kalitni faqat o'z ilovangiz uchun cheklang

## 🔗 Foydali linklar:

- **Yandex Developer:** https://developer.tech.yandex.ru/
- **MapKit Documentation:** https://yandex.ru/dev/maps/mapkit/
- **Flutter Plugin:** https://pub.dev/packages/yandex_mapkit

## 🎥 Video qo'llanma:

YouTube'da "Yandex MapKit API key" qidiring

---

**Savol yoki muammo bo'lsa, Yandex Developer Support'ga murojaat qiling!**
