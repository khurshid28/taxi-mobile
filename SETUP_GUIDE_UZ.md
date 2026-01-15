# Taxi Mobile - Ishga tushirish bo'yicha qo'llanma

## 1. Loyihani yuklab olish

Loyiha tayyor holda. Faqat Yandex MapKit API kalitini qo'shishingiz kerak.

## 2. Yandex MapKit API Kalitini Olish

### 2.1 Ro'yxatdan o'tish
1. https://developer.tech.yandex.ru/ saytiga kiring
2. Yandex akkauntingiz bilan kirish qiling
3. "MapKit" xizmatini tanlang
4. Yangi API kalit yarating

### 2.2 Android uchun sozlash

**Fayl:** `android/app/src/main/AndroidManifest.xml`

`<application>` tegi ichiga quyidagini qo'shing:

```xml
<meta-data
    android:name="com.yandex.mapkit.ApiKey"
    android:value="SIZNING_API_KALITINGIZ"/>
```

### 2.3 iOS uchun sozlash

**Fayl:** `ios/Runner/AppDelegate.swift`

Faylning boshiga qo'shing:

```swift
import YandexMapsMobile
```

Va `didFinishLaunchingWithOptions` metodiga:

```swift
YMKMapKit.setApiKey("SIZNING_API_KALITINGIZ")
```

## 3. Loyihani ishga tushirish

```bash
# Paketlarni o'rnatish
flutter pub get

# Ishga tushirish
flutter run
```

## 4. Test ma'lumotlari

- **OTP Kodi:** `123456`
- **Telefon raqam:** Istalgan raqam (test rejimida)

## 5. Asosiy funksiyalar

### Splash Screen
- Animatsiya bilan ochilish ekrani
- Avtomatik yo'naltirish (autentifikatsiya holatiga qarab)

### Autentifikatsiya
1. Telefon raqamni kiriting
2. SMS orqali kelgan 6 raqamli kodni kiriting
3. Profilni to'ldiring (ism, familiya, email, passport rasmi)

### Bosh sahifa (Home)
- Yandex xaritasi
- Yo'nalish tanlash
- Zakaz kutish (7-8 soniya)
- Yangi zakaz kelganda animatsiya
- Zakazni qabul qilish/rad etish
- Yo'lda harakatlanish (live tracking)
- Google Maps bilan yo'nalish ko'rsatish

### Zakazlarim
- Barcha zakazlar tarixi
- Masofa va narx ma'lumotlari

### To'lovlarim
- Balans ma'lumotlari
- To'lov tarixi
- Kunlik statistika

### Profil
- Shaxsiy ma'lumotlar
- Sozlamalar
- Chiqish

## 6. Loyiha tuzilmasi

```
lib/
├── core/               # Umumiy resurslar
│   ├── constants/     # O'zgarmas qiymatlar
│   ├── theme/         # Ranglar va tema
│   ├── network/       # API client (Dio)
│   ├── routes/        # Yo'nalishlar
│   └── utils/         # Yordamchi funksiyalar
├── features/          # Asosiy funksiyalar
│   ├── splash/
│   ├── auth/         # Autentifikatsiya
│   ├── profile/      # Profil
│   ├── home/         # Bosh sahifa (xarita)
│   ├── orders/       # Zakazlar
│   └── payments/     # To'lovlar
└── main.dart
```

## 7. Texnologiyalar

- **Clean Architecture** - Kod tashkil etish
- **Bloc/Cubit** - Holat boshqaruvi
- **Dio** - HTTP so'rovlar
- **Yandex MapKit** - Xarita
- **Geolocator** - GPS joylashuv
- **Image Picker** - Rasm yuklash
- **Shared Preferences** - Ma'lumotlarni saqlash

## 8. Asosiy rang

Primary Color: **#90EE90** (Och yashil)

## 9. Kelajakdagi yangilanishlar

- Real backend integratsiyasi
- Push bildirishnomalar
- To'lov tizimlari integratsiyasi
- Mijoz bilan chat
- Baho tizimi
- Ko'p tillilik

## 10. Yordam

Muammolar yuzaga kelsa:
1. `flutter clean` ni ishga tushiring
2. `flutter pub get` ni qayta ishga tushiring
3. Qurilmani qayta ishga tushiring

## Muvaffaqiyatlar! 🚕
