import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:speedsharemob/MainScreen.dart';
import 'package:speedsharemob/PermissionManager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PermissionManager().requestAppPermissions();
  // Load settings
  final prefs = await SharedPreferences.getInstance();
  final bool darkMode = prefs.getBool('darkMode') ?? false;
  
  runApp(MyApp(darkMode: darkMode));
}

class MyApp extends StatefulWidget {
  final bool darkMode;
  
  const MyApp({super.key, required this.darkMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _darkMode;
  
  @override
  void initState() {
    super.initState();
    _darkMode = widget.darkMode;
    
    // Listen for settings changes
    SharedPreferences.getInstance().then((prefs) {
      prefs.reload();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpeedShare',
      theme: ThemeData(
        brightness: _darkMode ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4E6AF3),
          primary: const Color(0xFF4E6AF3),
          secondary: const Color(0xFF2AB673),
          brightness: _darkMode ? Brightness.dark : Brightness.light,
        ),
        fontFamily: 'Poppins',
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        scaffoldBackgroundColor: _darkMode ? const Color(0xFF121212) : Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: _darkMode ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _darkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
          iconTheme: IconThemeData(
            color: _darkMode ? Colors.white : Colors.black87,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: _darkMode ? const Color(0xFF1E1E1E) : Colors.white,
          selectedItemColor: const Color(0xFF4E6AF3),
          unselectedItemColor: _darkMode ? Colors.grey[400] : Colors.grey[600],
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4E6AF3),
          primary: const Color(0xFF4E6AF3),
          secondary: const Color(0xFF2AB673),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Poppins',
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          selectedItemColor: const Color(0xFF4E6AF3),
          unselectedItemColor: Colors.grey[400],
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}