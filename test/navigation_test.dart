import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:siyaq/models/user_model.dart';
import 'package:siyaq/router/navigation.dart';
import 'package:siyaq/screens/booking/trial_booking_screen.dart';

String? _redirect({
  bool signedIn = false,
  UserRole role = UserRole.student,
  required String location,
  bool target = false,
}) =>
    appRedirect(
      signedIn: signedIn,
      role: role,
      location: location,
      hasBookingTarget: target,
    );

void main() {
  group('appRedirect', () {
    test('signed-out visitors can see home and the sign-in pages', () {
      expect(_redirect(location: Routes.home), isNull);
      expect(_redirect(location: Routes.login), isNull);
      expect(_redirect(location: Routes.signup), isNull);
    });

    test('signed-in users are sent away from sign-in and sign-up', () {
      expect(_redirect(signedIn: true, location: Routes.login), Routes.home);
      expect(_redirect(signedIn: true, location: Routes.signup), Routes.home);
    });

    test('booking needs a signed-in student or parent', () {
      expect(_redirect(location: Routes.book), Routes.login);
      expect(_redirect(signedIn: true, role: UserRole.student, location: Routes.book), isNull);
      expect(_redirect(signedIn: true, role: UserRole.tutor, location: Routes.book), Routes.home);
      expect(_redirect(signedIn: true, role: UserRole.admin, location: Routes.book), Routes.home);
    });

    test('a parent must arrive with a child chosen', () {
      expect(_redirect(signedIn: true, role: UserRole.parent, location: Routes.book),
          Routes.home);
      expect(
          _redirect(signedIn: true, role: UserRole.parent, location: Routes.book, target: true),
          isNull);
    });
  });

  group('roleFromQuery', () {
    test('accepts the three public roles only', () {
      expect(roleFromQuery('tutor'), UserRole.tutor);
      expect(roleFromQuery('parent'), UserRole.parent);
      expect(roleFromQuery('student'), UserRole.student);
      expect(roleFromQuery('admin'), isNull, reason: 'an admin can never be picked from a link');
      expect(roleFromQuery(null), isNull);
      expect(roleFromQuery('nonsense'), isNull);
    });
  });

  // A real GoRouter wired with the same redirect rules and the same route
  // shapes as lib/router/app_router.dart, using stand-in pages.
  group('browser-style navigation', () {
    late _FakeSession session;

    GoRouter makeRouter(String initial) => GoRouter(
          initialLocation: initial,
          refreshListenable: session,
          redirect: (context, state) => appRedirect(
            signedIn: session.signedIn,
            role: session.role,
            location: state.matchedLocation,
            hasBookingTarget: state.extra is BookingTarget,
          ),
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (c, s) => _Page('HOME', onGoLogin: () => GoRouter.of(c).push(Routes.login)),
            ),
            GoRoute(
              path: Routes.login,
              pageBuilder: (c, s) => const MaterialPage(
                  key: ValueKey('auth'), child: _Page('LOGIN', showBack: true)),
            ),
            GoRoute(
              path: Routes.signup,
              pageBuilder: (c, s) => MaterialPage(
                  key: const ValueKey('auth'),
                  child: _Page('SIGNUP role=${roleFromQuery(s.uri.queryParameters['role'])?.name}',
                      showBack: true)),
            ),
            GoRoute(
              path: Routes.book,
              builder: (c, s) => _Page(
                  'BOOK ${s.extra is BookingTarget ? (s.extra as BookingTarget).studentName : 'self'}',
                  showBack: true),
            ),
          ],
          errorBuilder: (c, s) => const _Page('NOT FOUND'),
        );

    Future<GoRouter> pumpApp(WidgetTester t, String initial) async {
      final router = makeRouter(initial);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      return router;
    }

    setUp(() => session = _FakeSession());

    testWidgets('back from a pushed page returns to the previous one', (t) async {
      await pumpApp(t, Routes.home);
      expect(find.text('HOME'), findsOneWidget);

      await t.tap(find.text('go to login'));
      await t.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);

      await t.tap(find.byKey(const Key('back')));
      await t.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('a page opened directly goes home instead of leaving the app', (t) async {
      await pumpApp(t, Routes.login);
      expect(find.text('LOGIN'), findsOneWidget);

      await t.tap(find.byKey(const Key('back')));
      await t.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('the system back button pops the page like the browser back button', (t) async {
      await pumpApp(t, Routes.home);
      await t.tap(find.text('go to login'));
      await t.pumpAndSettle();

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('/signup?role=tutor preselects the tutor role', (t) async {
      await pumpApp(t, '${Routes.signup}?role=tutor');
      expect(find.text('SIGNUP role=tutor'), findsOneWidget);
    });

    testWidgets('booking while signed out goes to sign-in', (t) async {
      await pumpApp(t, Routes.book);
      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('a parent opening /book directly lands home, but with a child it opens', (t) async {
      session.set(signedIn: true, role: UserRole.parent);
      final router = await pumpApp(t, Routes.book);
      expect(find.text('HOME'), findsOneWidget);

      router.push(Routes.book,
          extra: const BookingTarget(studentId: 'kid1', studentName: 'سارة'));
      await t.pumpAndSettle();
      expect(find.text('BOOK سارة'), findsOneWidget);
    });

    testWidgets('signing in while on /login moves you to home', (t) async {
      await pumpApp(t, Routes.login);
      expect(find.text('LOGIN'), findsOneWidget);

      session.set(signedIn: true, role: UserRole.student);
      await t.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('signing out while on /book moves you to sign-in', (t) async {
      session.set(signedIn: true, role: UserRole.student);
      await pumpApp(t, Routes.book);
      expect(find.text('BOOK self'), findsOneWidget);

      session.set(signedIn: false);
      await t.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('an unknown address shows the not-found page', (t) async {
      await pumpApp(t, '/nope');
      expect(find.text('NOT FOUND'), findsOneWidget);
    });
  });
}

class _FakeSession extends ChangeNotifier {
  bool signedIn = false;
  UserRole role = UserRole.student;

  void set({required bool signedIn, UserRole role = UserRole.student}) {
    this.signedIn = signedIn;
    this.role = role;
    notifyListeners();
  }
}

class _Page extends StatelessWidget {
  const _Page(this.label, {this.onGoLogin, this.showBack = false});
  final String label;
  final VoidCallback? onGoLogin;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          Text(label),
          if (onGoLogin != null) TextButton(onPressed: onGoLogin, child: const Text('go to login')),
          if (showBack)
            IconButton(
                key: const Key('back'),
                onPressed: () => goBackOrHome(context),
                icon: const Icon(Icons.arrow_back)),
        ]),
      );
}
