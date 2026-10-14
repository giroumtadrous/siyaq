import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/auth_screen.dart';
import '../screens/booking/trial_booking_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'navigation.dart';

/// The app's pages and their URLs:
///
///   /          landing page (signed out) or the user's dashboard
///   /login     sign in
///   /signup    create an account   (/signup?role=tutor preselects a role)
///   /book      request a trial class (students and parents)
GoRouter buildRouter(AuthService auth) => GoRouter(
      // Re-run the redirect rules whenever the user signs in or out.
      refreshListenable: auth,
      redirect: (context, state) => appRedirect(
        signedIn: auth.isLoggedIn,
        role: auth.userRole,
        location: state.matchedLocation,
        hasBookingTarget: state.extra is BookingTarget,
      ),
      routes: [
        GoRoute(path: Routes.home, builder: (context, state) => const AuthGate()),
        // Sign in and sign up share one page key, so switching between them
        // keeps what the user already typed.
        GoRoute(
          path: Routes.login,
          pageBuilder: (context, state) =>
              const MaterialPage(key: ValueKey('auth'), child: AuthScreen()),
        ),
        GoRoute(
          path: Routes.signup,
          pageBuilder: (context, state) => MaterialPage(
            key: const ValueKey('auth'),
            child: AuthScreen(
              startOnSignUp: true,
              initialRole: roleFromQuery(state.uri.queryParameters['role']),
            ),
          ),
        ),
        GoRoute(
          path: Routes.book,
          builder: (context, state) {
            final target = state.extra is BookingTarget ? state.extra as BookingTarget : null;
            return TrialBookingScreen(
              studentId: target?.studentId,
              studentName: target?.studentName,
            );
          },
        ),
      ],
      errorBuilder: (context, state) => const _NotFoundScreen(),
    );

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('الصفحة غير موجودة',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('ربما تغيّر الرابط أو كُتب بشكل خاطئ.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => GoRouter.of(context).go(Routes.home),
                child: const Text('العودة إلى الرئيسية'),
              ),
            ]),
          ),
        ),
      );
}
