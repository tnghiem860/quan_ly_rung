# 🌳 Forest Worker App - Flutter

Ứng dụng mobile cho nhân viên hiện trường trong hệ thống Forest Carbon Management Platform.

## Màn hình

| Màn hình | Chức năng |
|---|---|
| **Login** | Đăng nhập bằng email/password |
| **Home** | Dashboard: KPI, quick actions, hoạt động gần đây |
| **Check-in GPS** | Ghi nhận vị trí GPS + chọn dự án + ghi chú |
| **Nhật ký** | Danh sách nhật ký, lọc theo loại, thêm mới |
| **Điều tra rừng** | Ô mẫu (plots) + dữ liệu cây (DBH, chiều cao) |
| **Hồ sơ** | Thông tin cá nhân, dự án, cài đặt, đăng xuất |

## Cài đặt & Chạy

### Yêu cầu
- Flutter SDK >= 3.0.0 (https://docs.flutter.dev/get-started/install)
- Dart >= 3.0.0
- Android Studio / Xcode
- Android emulator hoặc iOS simulator (hoặc thiết bị thật)

### Bước 1: Clone / giải nén project

```bash
cd forest_worker_app
```

### Bước 2: Cài packages

```bash
flutter pub get
```

### Bước 3: Chạy app

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Web (xem trước)
flutter run -d chrome
```

### Bước 4: Build APK

```bash
flutter build apk --release
# APK output: build/app/outputs/flutter-apk/app-release.apk
```

## Cấu hình API

Mở `lib/main.dart` và cập nhật:
```dart
// Thêm base URL của backend
const String kBaseUrl = 'https://your-api.forest.vn/api';
```

## Cấu hình Google Maps

1. Lấy API key từ https://console.cloud.google.com
2. Cập nhật `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data android:name="com.google.android.geo.API_KEY"
              android:value="YOUR_KEY_HERE"/>
   ```
3. Cập nhật `ios/Runner/AppDelegate.swift`:
   ```swift
   GMSServices.provideAPIKey("YOUR_KEY_HERE")
   ```

## Cấu trúc project

```
lib/
├── main.dart              # App entry + theme (AppTheme)
├── models/
│   └── models.dart        # Data models + sample data
├── screens/
│   ├── login_screen.dart
│   ├── main_shell.dart    # Bottom navigation shell
│   ├── home_screen.dart
│   ├── checkin_screen.dart
│   ├── logbook_screen.dart
│   ├── new_logbook_screen.dart
│   ├── inventory_screen.dart
│   └── profile_screen.dart
└── widgets/
    ├── stat_card.dart     # StatCard, ActivityTile, SectionHeader
    ├── activity_tile.dart
    └── section_header.dart
```

## Màu sắc

```dart
primary:      #1A4731  // Dark forest green
accent:       #52B788  // Medium green
accentLight:  #74C69D  // Light green
background:   #0F1C15  // Near-black green
cardBg:       #1E3027  // Card background
```

## Tính năng Offline

App hỗ trợ offline mode:
- Dữ liệu nhật ký lưu local (SQLite via `sqflite`)
- Tự động sync khi có mạng (`connectivity_plus`)
- Indicator hiển thị trạng thái sync

## TODO / Mở rộng

- [ ] Tích hợp Google Maps thực tế
- [ ] Camera để chụp ảnh hiện trường
- [ ] Đồng bộ offline thực sự với SQLite
- [ ] Push notification (Firebase)
- [ ] Tính toán carbon sơ bộ
- [ ] Xuất báo cáo PDF
