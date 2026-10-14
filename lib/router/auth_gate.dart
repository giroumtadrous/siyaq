import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../screens/dashboard/admin_dashboard.dart';
import '../screens/dashboard/parent_dashboard.dart';
import '../screens/dashboard/student_dashboard.dart';
import '../screens/dashboard/tutor_dashboard.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/tutor/tutor_application_screen.dart';
import '../services/auth_service.dart';

/// The home page (`/`): the landing page when signed out, otherwise the
/// dashboard for the user's role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isLoggedIn) {
      return const LandingScreen();
    }

    switch (auth.userRole) {
      case UserRole.tutor:
        return auth.currentUser?.approved == true
            ? const TutorDashboard()
            : const TutorApplicationScreen();
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.parent:
        return const ParentDashboard();
      case UserRole.student:
        return const StudentDashboard();
    }
  }
}
