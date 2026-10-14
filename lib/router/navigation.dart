import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../models/user_model.dart';

/// Where each page lives. These are the real browser URLs.
class Routes {
  static const home = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const book = '/book';
}

/// Goes back one page, or to the home page when this page was opened directly
/// (a refresh or a shared link) and there is nothing to go back to.
void goBackOrHome(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    GoRouter.of(context).go(Routes.home);
  }
}

/// The sign-up role chosen with `/signup?role=tutor`. Unknown values are ignored
/// (an admin can never be chosen from a link).
UserRole? roleFromQuery(String? value) {
  for (final role in const [UserRole.student, UserRole.parent, UserRole.tutor]) {
    if (role.name == value) return role;
  }
  return null;
}

/// The routing rules, kept free of Flutter and Firebase so they can be tested.
/// Returns the address to redirect to, or null to stay where you are.
String? appRedirect({
  required bool signedIn,
  required UserRole role,
  required String location,
  required bool hasBookingTarget,
}) {
  final onAuthPage = location == Routes.login || location == Routes.signup;

  // Already signed in: there is nothing to do on the sign-in pages.
  if (signedIn && onAuthPage) return Routes.home;

  if (location == Routes.book) {
    if (!signedIn) return Routes.login;
    // Only students and parents book classes.
    if (role != UserRole.student && role != UserRole.parent) return Routes.home;
    // A parent books for a chosen child, which can't be recovered from the
    // address (it never contains a student's id), so go back and pick again.
    if (role == UserRole.parent && !hasBookingTarget) return Routes.home;
  }
  return null;
}
