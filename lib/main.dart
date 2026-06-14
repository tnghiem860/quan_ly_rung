import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Kích hoạt Offline Persistence cho Web và các nền tảng
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  
  // Khởi tạo dữ liệu mặc định nếu chưa có
  await _seedDefaultData();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ForestWorkerApp());
}

Future<void> _seedDefaultData() async {
  final firestore = FirebaseFirestore.instance;

  // Cập nhật User
  final userDoc = await firestore.collection('users').doc('user_001').get();
  if (!userDoc.exists) {
    await firestore.collection('users').doc('user_001').set({
      'name': 'Trần Văn B',
      'email': 'tranvanb@forest.vn',
      'phone': '0901234567',
      'role': 'Forest Worker',
      'status': 'Active',
    });
  }

  // Cập nhật Activities
  final activitiesSnapshot = await firestore.collection('activities').limit(1).get();
  if (activitiesSnapshot.docs.isEmpty) {
    final defaultActivities = [
      'Trồng cây',
      'Chăm sóc cây',
      'Bón phân',
      'Kiểm tra sinh trưởng',
      'Tuần tra',
      'Phòng cháy chữa cháy',
    ];
    for (String activity in defaultActivities) {
      await firestore.collection('activities').add({'name': activity});
    }
  }

  // Cập nhật Projects
  final projectsSnapshot = await firestore.collection('projects').limit(1).get();
  if (projectsSnapshot.docs.isEmpty) {
    final defaultProjects = [
      {'name': 'Dak Lak Project 01', 'province': 'Đắk Lắk', 'status': 'Active', 'areaHa': 1250.50, 'treeSpecies': 'Keo Lai'},
      {'name': 'Lam Dong Project 02', 'province': 'Lâm Đồng', 'status': 'Active', 'areaHa': 980.75, 'treeSpecies': 'Bạch Đàn'},
      {'name': 'Gia Lai Project 01', 'province': 'Gia Lai', 'status': 'Surveying', 'areaHa': 1520.30, 'treeSpecies': 'Thông'},
    ];
    for (var project in defaultProjects) {
      await firestore.collection('projects').add(project);
    }
  }
}

class ForestWorkerApp extends StatelessWidget {
  const ForestWorkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forest Worker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkGreenTheme,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }
}

class AppTheme {
  // ── Bảng màu nền – tối hơn và sắc nét hơn ──────────────────────────────
  static const Color background   = Color(0xFF080F0B); // Đen tuyền ám xanh
  static const Color surface      = Color(0xFF101A12); // Nền layer 2
  static const Color surfaceLight = Color(0xFF172019); // Nền input/card nhỏ
  static const Color cardBg       = Color(0xFF142218); // Card nổi bật hơn
  static const Color primary      = Color(0xFF112118); // AppBar / bottom bar
  static const Color primaryLight = Color(0xFF1E3828); // Hover/pressed state

  // ── Màu nhấn chính – xanh lá rừng sáng ─────────────────────────────────
  static const Color accent       = Color(0xFF4ADE80); // Xanh lá tươi (như cây mới)
  static const Color accentLight  = Color(0xFF86EFAC); // Highlight trên nền tối
  static const Color accentDark   = Color(0xFF16A34A); // Hover/pressed accent

  // ── Màu nhấn phụ – Cam hổ phách (warm accent) ───────────────────────────
  static const Color amber        = Color(0xFFFBBF24); // Cảnh báo / nút quan trọng
  static const Color amberLight   = Color(0xFFFDE68A); // Hover amber

  // ── Màu viền và phân chia ───────────────────────────────────────────────
  static const Color border       = Color(0xFF1F3025); // Viền card/input
  static const Color borderBright = Color(0xFF2D4A38); // Viền active

  // ── Màu văn bản – phân cấp rõ ràng ─────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF); // Trắng tinh – tiêu đề
  static const Color textSecondary = Color(0xFF9CA3AF); // Xám trung bình – phụ đề
  static const Color textMuted     = Color(0xFF4B5563); // Xám nhạt – mờ

  // ── Màu trạng thái ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF4ADE80); // = accent
  static const Color warning = Color(0xFFFBBF24); // = amber
  static const Color danger  = Color(0xFFF87171); // Đỏ nhẹ (tránh quá chói)
  static const Color info    = Color(0xFF38BDF8); // Xanh dương nhạt

  static ThemeData get darkGreenTheme {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentLight,
        surface: surface,
        error: danger,
      ),

      // ── TextTheme dùng Inter font ────────────────────────────────────────
      textTheme: base.copyWith(
        headlineLarge:  base.headlineLarge?.copyWith(color: textPrimary,   fontWeight: FontWeight.w700),
        headlineMedium: base.headlineMedium?.copyWith(color: textPrimary,  fontWeight: FontWeight.w600),
        headlineSmall:  base.headlineSmall?.copyWith(color: textPrimary,   fontWeight: FontWeight.w600),
        titleLarge:     base.titleLarge?.copyWith(color: textPrimary,      fontWeight: FontWeight.w600),
        titleMedium:    base.titleMedium?.copyWith(color: textPrimary,     fontWeight: FontWeight.w500),
        titleSmall:     base.titleSmall?.copyWith(color: textSecondary,    fontWeight: FontWeight.w500),
        bodyLarge:      base.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium:     base.bodyMedium?.copyWith(color: textSecondary),
        bodySmall:      base.bodySmall?.copyWith(color: textMuted),
        labelLarge:     base.labelLarge?.copyWith(color: textPrimary,      fontWeight: FontWeight.w600),
        labelMedium:    base.labelMedium?.copyWith(color: textSecondary),
        labelSmall:     base.labelSmall?.copyWith(color: textMuted,        fontSize: 11),
      ),

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: textSecondary, size: 22),
        actionsIconTheme: const IconThemeData(color: textSecondary, size: 22),
      ),

      // ── Bottom Nav ───────────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: primary,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Card ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 0.5),
        ),
      ),

      // ── Input ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: textSecondary,
      ),

      // ── ElevatedButton ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          elevation: 0,
        ),
      ),

      // ── TextButton ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentLight,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 0.5,
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        side: const BorderSide(color: border, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
