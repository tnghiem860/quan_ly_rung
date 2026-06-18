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
      'fullName': 'Trần Văn B',
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
  final projectsSnapshot = await firestore.collection('forest_projects').limit(1).get();
  if (projectsSnapshot.docs.isEmpty) {
    final defaultProjects = [
      {'projectName': 'Dak Lak Project 01', 'province': 'Đắk Lắk', 'status': 'Active', 'areaHa': 1250.50, 'treeSpecies': 'Keo Lai'},
      {'projectName': 'Lam Dong Project 02', 'province': 'Lâm Đồng', 'status': 'Active', 'areaHa': 980.75, 'treeSpecies': 'Bạch Đàn'},
      {'projectName': 'Gia Lai Project 01', 'province': 'Gia Lai', 'status': 'Surveying', 'areaHa': 1520.30, 'treeSpecies': 'Thông'},
    ];
    for (var project in defaultProjects) {
      await firestore.collection('forest_projects').add(project);
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
      theme: AppTheme.lightNatureTheme,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }
}

class AppTheme {
  // ── Bảng màu nền – Light Nature ─────────────────────────────────────────
  static const Color background   = Color(0xFFF8FAFC); // Nền xám nhạt/trắng
  static const Color surface      = Color(0xFFFFFFFF); // Nền layer 2 (trắng)
  static const Color surfaceLight = Color(0xFFF1F5F9); // Nền input/card nhỏ
  static const Color cardBg       = Color(0xFFFFFFFF); // Card trắng
  static const Color primary      = Color(0xFF065F46); // Xanh rừng rậm (AppBar)
  static const Color primaryLight = Color(0xFF047857); // Xanh lục bảo

  // ── Màu nhấn chính – Xanh lục bảo ──────────────────────────────────────
  static const Color accent       = Color(0xFF059669); // Xanh lá đậm hơn
  static const Color accentLight  = Color(0xFF10B981); // Highlight trên nền sáng
  static const Color accentDark   = Color(0xFF064E3B); // Hover/pressed accent

  // ── Màu nhấn phụ – Cam ──────────────────────────────────────────────────
  static const Color amber        = Color(0xFFF59E0B); // Cảnh báo
  static const Color amberLight   = Color(0xFFFCD34D); // Hover amber

  // ── Màu viền và phân chia ───────────────────────────────────────────────
  static const Color border       = Color(0xFFE2E8F0); // Viền card/input xám nhạt
  static const Color borderBright = Color(0xFFCBD5E1); // Viền active xám vừa

  // ── Màu văn bản – phân cấp rõ ràng ─────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0F172A); // Đen đậm – tiêu đề
  static const Color textSecondary = Color(0xFF475569); // Xám trung bình – phụ đề
  static const Color textMuted     = Color(0xFF94A3B8); // Xám nhạt – mờ

  // ── Màu trạng thái ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF059669); // = accent
  static const Color warning = Color(0xFFF59E0B); // = amber
  static const Color danger  = Color(0xFFEF4444); // Đỏ
  static const Color info    = Color(0xFF0EA5E9); // Xanh dương

  static ThemeData get lightNatureTheme {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
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
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),

      // ── Bottom Nav ───────────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // ── Card ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 1.0),
        ),
      ),

      // ── Input ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: textSecondary,
      ),

      // ── ElevatedButton ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
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
          foregroundColor: primary,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1.0,
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        side: const BorderSide(color: borderBright, width: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
