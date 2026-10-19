import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/classes_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EduTrackApp());
}

class EduTrackApp extends StatelessWidget {
  const EduTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: MaterialApp(
        title: 'EduTrack Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            primary: Colors.teal.shade700,
            secondary: Colors.teal.shade500,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F9FA),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        home: const ClassesScreen(),
      ),
    );
  }
}
