import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const Color primary = Color(0xFF1A4731);
  static const Color primaryLight = Color(0xFF2D6A4F);
  static const Color accent = Color(0xFF52B788);
  static const Color accentLight = Color(0xFF74C69D);
  static const Color surface = Color(0xFF1B2E23);
  static const Color surfaceLight = Color(0xFF243B2D);
  static const Color background = Color(0xFF0F1C15);
  static const Color cardBg = Color(0xFF1E3027);
  static const Color textPrimary = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF95B8A0);
  static const Color textMuted = Color(0xFF5A7A65);
  static const Color border = Color(0xFF2D4A38);
  static const Color success = Color(0xFF52B788);
  static const Color warning = Color(0xFFFFB703);
  static const Color danger = Color(0xFFE63946);
  static const Color info = Color(0xFF48CAE4);

  static ThemeData get darkGreenTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accentLight,
          surface: surface,
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: primary,
          selectedItemColor: accentLight,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border, width: 0.5),
          ),
        ),
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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: background,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentLight,
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textSecondary),
          bodySmall: TextStyle(color: textMuted),
          labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(color: textSecondary),
          labelSmall: TextStyle(color: textMuted, fontSize: 11),
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 0.5,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surfaceLight,
          labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
          side: const BorderSide(color: border, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}
