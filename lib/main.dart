import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/booking_service.dart';
import 'services/progress_service.dart';
import 'services/tutor_application_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Real paths (/login) instead of /#/login, so each page has a clean URL.
  usePathUrlStrategy();
  // Make pages opened with push() (like /login) show in the address bar too,
  // so refreshing or sharing the link lands on the same page.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  await initializeDateFormatting('ar');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Wait for the saved session to be restored before showing any page, so a
  // refresh on a signed-in page doesn't flash the signed-out version. The
  // timeout keeps the app usable if the network is down.
  final auth = AuthService();
  await auth.ready.timeout(const Duration(seconds: 6), onTimeout: () {});

  runApp(SiyaqApp(auth: auth));
}

class SiyaqApp extends StatefulWidget {
  const SiyaqApp({super.key, required this.auth});
  final AuthService auth;

  @override
  State<SiyaqApp> createState() => _SiyaqAppState();
}

class _SiyaqAppState extends State<SiyaqApp> {
  late final GoRouter _router = buildRouter(widget.auth);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.auth),
        ChangeNotifierProvider(create: (_) => BookingService()),
        Provider(create: (_) => ProgressService()),
        Provider(create: (_) => AdminService()),
        Provider(create: (_) => TutorApplicationService()),
      ],
      child: MaterialApp.router(
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
        routerConfig: _router,
      ),
    );
  }
}
