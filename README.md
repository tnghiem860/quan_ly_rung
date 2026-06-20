# 🌳 Forest Worker App - Flutter

Ứng dụng mobile cho nhân viên hiện trường trong hệ thống Forest Carbon Management Platform.

---

## 🗺️ Flowchart quy trình hoạt động

### 1. Luồng tổng quan hệ thống

```mermaid
flowchart TD
    A([Khởi động App]) --> B{Đã đăng nhập?}
    B -- Chưa --> C[Màn hình Login]
    B -- Rồi --> D[MainShell - Bottom Nav]

    C --> E[Nhập Email / Password]
    E --> F{Xác thực Firebase Auth}
    F -- Thất bại --> G[Hiện lỗi] --> E
    F -- Thành công --> H[Lưu UserSession\nuid, ownerId, role]
    H --> D

    D --> D1[🏠 Trang chủ]
    D --> D2[📍 Check-in GPS]
    D --> D3[📔 Nhật ký]
    D --> D4[🌲 Điều tra rừng]
    D --> D5[👤 Hồ sơ]
```

### 2. Luồng xác thực & phiên làm việc

```mermaid
flowchart TD
    A[Login Screen] --> B[Firebase Auth\nsignInWithEmailAndPassword]
    B --> C{Kết quả}
    C -- Lỗi --> D[Hiển thị thông báo lỗi]
    C -- OK --> E[Lấy thông tin user\ntừ Firestore /users/uid]
    E --> F[UserSession.init\nuid, ownerId, fullName, role]
    F --> G[Navigator → MainShell]
    G --> H[SyncService.startListening\nLắng nghe kết nối mạng]
    H --> I{Có mạng?}
    I -- Có --> J[syncAll: đồng bộ\nnhật ký + check-in]
    I -- Không --> K[Chờ kết nối trở lại]
    K --> I
```

### 3. Luồng Check-in GPS

```mermaid
flowchart TD
    A[Mở tab Check-in] --> B[Tải danh sách dự án\ntừ Firestore]
    B --> C[Hiển thị bản đồ OpenStreetMap]
    C --> D[Nhấn 'Lấy vị trí']
    D --> E{GPS bật?}
    E -- Không --> F[Yêu cầu bật GPS] --> D
    E -- Có --> G{Quyền location?}
    G -- Từ chối --> H[Hiển thị cảnh báo] --> Stop1([Dừng])
    G -- Cho phép --> I[Geolocator.getCurrentPosition\ndesiredAccuracy: high]
    I --> J[Hiển thị tọa độ\ntrên bản đồ + card]
    J --> K[Chọn dự án\nNhập ghi chú]
    K --> L[Nhấn 'Xác nhận Check-in']
    L --> M{Online?}
    M -- Offline --> N[Lưu Firestore local\nsynced: false]
    M -- Online --> O[Lưu Firestore\nsynced: true]
    O --> P[NotificationService\npushCheckIn → Web Admin]
    N --> Q[Hiển thị:\nĐã lưu ngoại tuyến]
    P --> R[Hiển thị:\nCheck-in thành công]
```

### 4. Luồng Nhật ký & Đồng bộ ảnh

```mermaid
flowchart TD
    A[Mở Nhật ký mới] --> B[Nhập tiêu đề\nchọn loại nhật ký]
    B --> C[Thêm ảnh từ Camera/Gallery]
    C --> D{Online?}
    D -- Online --> E[Upload ảnh lên\nFirebase Storage]
    E --> F[Lấy download URL]
    D -- Offline --> G[Lưu file ảnh\nvào bộ nhớ máy\nlocalPath]
    
    F --> H[Lưu nhật ký vào Firestore\nlogbook_activities\nsynced: true]
    H --> H2[NotificationService\npushLogbookEntry]
    H2 --> J([Hoàn thành])
    
    G --> I[Lưu nhật ký vào Firestore\nsynced: false\nlocalPath trong photos]
    I --> I2[NotificationService\nLưu cache đợi sync]
    I2 --> J

    subgraph SyncService [⚙️ SyncService - Chạy nền]
        K[Connectivity.onConnectivityChanged] --> L{Có mạng trở lại?}
        L -- Có --> M[syncAll]
        M --> N[_syncLogbookActivities:\nUpload ảnh offline → Storage\ncập nhật URL + synced: true]
        M --> O[_syncCheckins:\ncập nhật synced: true]
        M --> P[Đồng bộ các thông báo\ntrong Firestore cache]
    end
```

### 5. Luồng Điều tra rừng

```mermaid
flowchart TD
    A[Mở tab Điều tra] --> B[Tải danh sách dự án\nFirestore forest_projects]
    B --> C[Chọn dự án]
    C --> D[Tải & hiển thị danh sách ô mẫu\ndo Admin tạo sẵn]

    D --> E{Người dùng chọn}

    E -- Cập nhật vị trí GPS --> F[Geolocator.getCurrentPosition]
    F --> F1{Online?}
    F1 -- Offline --> F2[Lưu cập nhật + Thông báo\nvào Firestore cache đợi sync]
    F1 -- Online --> G[Cập nhật trực tiếp\nFirestore inventory_plots]
    G --> H[NotificationService\npushPlotLocationUpdate]
    H --> D
    F2 --> D

    E -- Xem dữ liệu cây --> I[Tab Dữ liệu cây]
    I --> J{Thao tác}

    J -- Thêm mới --> K["Chọn ô mẫu + nhập thông tin"]
    K --> K1{Online?}
    K1 -- Offline --> K2[Lưu cây + Thông báo\nvào Firestore cache đợi sync]
    K1 -- Online --> L[Lưu vào Firestore\ninventory_trees]
    L --> L1[NotificationService\npushTreeData]
    L1 --> I
    K2 --> I

    J -- Xóa --> M[Xác nhận xóa]
    M --> N[Xóa khỏi Firestore\ninventory_trees]
    N --> I
```

### 6. Luồng trạng thái Online / Offline

```mermaid
flowchart LR
    A[App khởi động] --> B[checkConnectivity\nlấy trạng thái ban đầu]
    B --> C{Kết quả}
    C -- Có mạng --> D[🟢 Online\nĐang kết nối]
    C -- Mất mạng --> E[🔴 Offline\nMất kết nối]

    F[Connectivity.onConnectivityChanged\nStream lắng nghe liên tục] --> G{Thay đổi mạng}
    G -- Kết nối --> D
    G -- Mất kết nối --> E

    D --> H[SyncService.syncAll\nTự động đồng bộ dữ liệu offline]
    E --> I[Lưu cục bộ\nFirestore offline cache]
```

---

## 📱 Màn hình

| Màn hình | Chức năng |
|---|---|
| **Login** | Đăng nhập bằng email/password |
| **Home** | Dashboard: KPI, quick actions, hoạt động gần đây |
| **Check-in GPS** | Ghi nhận vị trí GPS + chọn dự án + ghi chú |
| **Nhật ký** | Danh sách nhật ký, lọc theo loại, thêm mới |
| **Điều tra rừng** | Ô mẫu (plots) + dữ liệu cây (DBH, chiều cao) |
| **Hồ sơ** | Thông tin cá nhân, dự án, cài đặt, đăng xuất |

---

## ⚙️ Cài đặt & Chạy

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
```

### Bước 4: Build APK

```bash
flutter build apk --release
# APK output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🗂️ Cấu trúc project

```
lib/
├── main.dart                    # App entry + AppTheme
├── firebase_options.dart        # Cấu hình Firebase
├── models/
│   └── models.dart              # Data models (LogbookEntry, CheckInRecord, ...)
├── screens/
│   ├── login_screen.dart        # Đăng nhập
│   ├── main_shell.dart          # Bottom navigation shell
│   ├── home_screen.dart         # Dashboard
│   ├── checkin_screen.dart      # Check-in GPS
│   ├── logbook_screen.dart      # Danh sách nhật ký
│   ├── new_logbook_screen.dart  # Tạo nhật ký mới
│   ├── inventory_screen.dart    # Điều tra rừng
│   └── profile_screen.dart      # Hồ sơ cá nhân
├── services/
│   ├── user_session.dart        # Singleton quản lý phiên đăng nhập
│   ├── sync_service.dart        # Đồng bộ dữ liệu offline → online
│   └── notification_service.dart# Gửi thông báo lên web admin
└── widgets/
    ├── stat_card.dart           # StatCard + SectionHeader
    ├── activity_tile.dart       # ActivityTile
    └── section_header.dart      # SectionHeader
```

---

## 🎨 Màu sắc

```dart
primary:      #1A4731  // Dark forest green
accent:       #52B788  // Medium green
accentLight:  #74C69D  // Light green
background:   #0F1C15  // Near-black green
cardBg:       #1E3027  // Card background
```

---

## 📡 Firebase Collections

| Collection | Mô tả |
|---|---|
| `users` | Thông tin người dùng (fullName, role, ownerId) |
| `forest_projects` | Dự án rừng (ownerUid, workerUids) |
| `forest_plots` | Ô mẫu điều tra (projectId) |
| `forest_trees` | Cây trong ô mẫu (plotId, DBH, height) |
| `logbook_activities` | Nhật ký hoạt động (user, photos, synced) |
| `checkins` | Bản ghi check-in GPS (createdBy, lat, lng, synced) |
| `notifications` | Thông báo từ admin (recipientIds, readBy) |

---

## 🔌 Tính năng Offline

App hỗ trợ offline mode hoàn chỉnh:
- Dữ liệu nhật ký & check-in lưu vào **Firestore offline cache** tự động
- Ảnh offline lưu vào **bộ nhớ máy** (`localPath`)
- **SyncService** tự động đồng bộ khi có mạng trở lại
- Indicator real-time hiển thị trạng thái **Online / Offline**

---

## 🗒️ TODO / Mở rộng

- [ ] Push notification (Firebase Cloud Messaging)
- [ ] Tính toán carbon sơ bộ
- [ ] Xuất báo cáo PDF
- [ ] Bộ lọc nâng cao cho nhật ký và điều tra
