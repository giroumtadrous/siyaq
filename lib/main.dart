import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/landing/landing_screen.dart';
import 'theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/booking_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/student_dashboard.dart';
import 'screens/dashboard/tutor_dashboard.dart';
import 'screens/dashboard/admin_dashboard.dart';
import 'models/user_model.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SiyaqApp());
}

class SiyaqApp extends StatelessWidget {
  const SiyaqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => BookingService()),
      ],
      child: MaterialApp(
        title: 'سياق | Siyaq',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(),
        home: const LandingScreen(),
      ),
    );
  }
}

/// Routes the user to the right dashboard based on role once logged in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    switch (auth.userRole) {
      case UserRole.tutor:
        return const TutorDashboard();
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.student:
      default:
        return const StudentDashboard();
    }
  }
}
