# Taxi Mobile App

Clean architecture taxi app uchun Yandex Map, Bloc/Cubit va Dio bilan.

## Features

- ✅ Clean Architecture
- ✅ Bloc/Cubit State Management
- ✅ Yandex Maps Integration
- ✅ Phone Authentication with OTP
- ✅ Profile Management
- ✅ Real-time Order Tracking
- ✅ Google Maps Integration
- ✅ Multi-state Order Flow

## Pages

1. **Splash Screen** - Animated splash screen
2. **Phone Authentication** - Phone number input
3. **OTP Verification** - 6-digit OTP verification
4. **Complete Profile** - Name, fullname, email, passport image
5. **Home** - Yandex Map with order states
6. **My Orders** - Order history
7. **Payments** - Payment history and balance
8. **Profile** - User profile and settings

## Order States

- Initial - Waiting for destination selection
- Drawing Route - User selects destination on map
- Waiting for Order - Searching for order (7-8 seconds)
- Order Received - New order with animation
- Order Accepted - Order accepted, calculating route
- In Progress - Driving to destination with live tracking
- Completed - Order completed

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Yandex MapKit Setup

#### Android (android/app/src/main/AndroidManifest.xml)
```xml
<application>
    <meta-data
        android:name="com.yandex.mapkit.ApiKey"
        android:value="YOUR_YANDEX_API_KEY"/>
</application>
```

#### iOS (ios/Runner/AppDelegate.swift)
```swift
import YandexMapsMobile

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    YMKMapKit.setApiKey("YOUR_YANDEX_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 3. Get Yandex MapKit API Key

Visit: https://developer.tech.yandex.ru/

### 4. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── core/
│   ├── constants/      # App constants
│   ├── error/         # Error handling
│   ├── network/       # Dio client
│   ├── routes/        # App routes
│   ├── theme/         # Theme configuration
│   └── utils/         # Utility functions
├── features/
│   ├── splash/        # Splash screen
│   ├── auth/          # Authentication
│   ├── profile/       # Profile management
│   ├── home/          # Home with map
│   ├── orders/        # Orders history
│   └── payments/      # Payments
└── main.dart
```

## Technologies Used

- Flutter SDK 3.10.4+
- flutter_bloc ^8.1.6
- yandex_mapkit ^4.1.0
- dio ^5.7.0
- geolocator ^13.0.2
- image_picker ^1.1.2
- shared_preferences ^2.3.3

## Primary Color

Primary Color: `#90EE90` (Light Green)

## Icons

Icons from SVGRepo Gentlecons collection:
https://www.svgrepo.com/collection/gentlecons-interface-icons

## Notes

- For testing, default OTP is `123456`
- Mock API calls with 2-second delays
- Location tracking updates every 10 meters
- Order waiting time is 8 seconds

## License

MIT License
