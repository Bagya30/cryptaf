import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cryptaf/screens/login_screen.dart';
import 'package:cryptaf/screens/dashboard_screen.dart';
import 'package:cryptaf/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cryptaf/screens/splash_screen.dart';
import 'package:cryptaf/screens/share_screen.dart';
import 'package:cryptaf/screens/nominee_portal_screen.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:cryptaf/services/firestore_service.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cryptaf/web_url_stub.dart' if (dart.library.html) 'dart:html' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
          authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
          projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
          storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
          messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
          appId: dotenv.env['FIREBASE_APP_ID_WEB'] ?? '',
          measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID'] ?? '',
        ),
      );
    } else {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
          appId: dotenv.env['FIREBASE_APP_ID_ANDROID'] ?? '',
          messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
          projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
        ),
      );
    }
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  // Initialize Firebase Performance
  try {
    FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
  } catch (e) {
    debugPrint("Firebase Performance initialization error: $e");
  }

  // Initialize Firebase Crashlytics for non-web platforms
  if (!kIsWeb) {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  
  runApp(const CryptafApp());
}

class CryptafApp extends StatefulWidget {
  const CryptafApp({super.key});
  static CryptafAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<CryptafAppState>();

  @override
  State<CryptafApp> createState() => CryptafAppState();
}

class CryptafAppState extends State<CryptafApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.dark;
  String _initialRoute = '/';
  Timer? _activityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirestoreService().updateLastActive();
    _activityTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      FirestoreService().updateLastActive();
    });
    _loadTheme();
    if (kIsWeb) {
      final url = html.window.location.href;
      if (url.contains('/share/')) {
        final token = url.split('/share/').last.split('?').first.split('#').first;
        _initialRoute = '/share/$token';
      } else if (url.contains('/nominee-access')) {
        _initialRoute = '/nominee-access';
      }
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isLight = prefs.getBool('lightMode') ?? false;
    setState(() {
      _themeMode = isLight ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void toggleTheme(bool isLight) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lightMode', isLight);
    setState(() {
      _themeMode = isLight ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await FirestoreService().updateLastActive();
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      cardColor: const Color(0xFF111111),
      primaryColor: const Color(0xFF0A0A0A),
      colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(
        surface: const Color(0xFF0A0A0A),
        secondary: const Color(0xFFC9A84C), // Antique Gold Accent
      ),
      textTheme: GoogleFonts.oxaniumTextTheme(Theme.of(context).textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: const Color(0xFFC9A84C),
        selectionColor: const Color(0xFFC9A84C).withOpacity(0.3),
        selectionHandleColor: const Color(0xFFC9A84C),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadePageTransitionsBuilder(),
          TargetPlatform.iOS: FadePageTransitionsBuilder(),
          TargetPlatform.windows: FadePageTransitionsBuilder(),
          TargetPlatform.macOS: FadePageTransitionsBuilder(),
          TargetPlatform.linux: FadePageTransitionsBuilder(),
        },
      ),
    );

    final lightTheme = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      primaryColor: Colors.white,
      colorScheme: ColorScheme.fromSwatch(brightness: Brightness.light).copyWith(
        secondary: const Color(0xFFC9A84C), // Antique Gold Accent
      ),
      textTheme: GoogleFonts.oxaniumTextTheme(Theme.of(context).textTheme).apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: const Color(0xFFC9A84C),
        selectionColor: const Color(0xFFC9A84C).withOpacity(0.3),
        selectionHandleColor: const Color(0xFFC9A84C),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadePageTransitionsBuilder(),
          TargetPlatform.iOS: FadePageTransitionsBuilder(),
          TargetPlatform.windows: FadePageTransitionsBuilder(),
          TargetPlatform.macOS: FadePageTransitionsBuilder(),
          TargetPlatform.linux: FadePageTransitionsBuilder(),
        },
      ),
    );

    return MaterialApp(
      title: 'Cryptaf',
      debugShowCheckedModeBanner: false,
      initialRoute: _initialRoute,
      themeMode: _themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      navigatorObservers: [ActivityObserver()],
      onGenerateRoute: (settings) {
        final path = settings.name;
        if (path != null && path.startsWith('/share/')) {
          final token = path.replaceFirst('/share/', '');
          return MaterialPageRoute(
            builder: (context) => ShareRouteWrapper(token: token),
          );
        }
        if (path != null && (path == '/nominee-access' || path.startsWith('/nominee-access'))) {
          return MaterialPageRoute(
            builder: (context) => const NomineePortalScreen(),
          );
        }
        if (path == '/' || path == null) {
          return MaterialPageRoute(builder: (context) => const SplashScreen());
        }
        return null;
      },
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService auth = AuthService();
    
    return StreamBuilder(
      stream: auth.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary)),
          );
        } else if (snapshot.hasData) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}

class GoldShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const GoldShimmerText({super.key, required this.text, this.style});

  @override
  State<GoldShimmerText> createState() => GoldShimmerTextState();
}

class GoldShimmerTextState extends State<GoldShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFC9A84C),
                Colors.white,
                Color(0xFFC9A84C),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-2.0 + (_controller.value * 4.0), 0.0),
              end: Alignment(0.0 + (_controller.value * 4.0), 0.0),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.style?.copyWith(color: Colors.white) ?? const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }
}

class ShareRouteWrapper extends StatelessWidget {
  final String token;
  const ShareRouteWrapper({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C))),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return ShareScreen(token: token);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('pending_share_token', token);
            if (context.mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            }
          });
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C))),
          );
        }
      },
    );
  }
}

class ActivityObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    FirestoreService().updateLastActive();
  }
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    FirestoreService().updateLastActive();
  }
}

