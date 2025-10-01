import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'auth_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'settings.dart';
import 'submit_lie_page.dart';
import 'exploreLies.dart';
import 'streak_badges_page.dart';
import 'regionTrends.dart';
import 'truth_lie_game_page.dart';
import 'lieVault.dart';
import 'notifications_page.dart'; // Ensure this file exists/exported with the NotificationsPage class
import 'liechat_userlist_page.dart'; // Ensure this file exists/exported with LieChatUserPage class

// ----- Notifications setup -----
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

void showPopupNotification(String title, String body) async {
  const androidDetails = AndroidNotificationDetails(
    'default_channel',
    'Default Channel',
    importance: Importance.max,
    priority: Priority.high,
  );
  const platformDetails = NotificationDetails(android: androidDetails);
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    platformDetails,
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // background message handler - no popup from here, handled by OS
}

// ----- SplashScreen -----
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _fadeIn = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleIn = Tween(
      begin: 0.8,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2300), () {
      _navigateFromSplash();
    });
  }

  void _navigateFromSplash() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/auth');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color kAccent = Color(0xFF00A86B);

    return Scaffold(
      backgroundColor: Color(0xffd8e4bc),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.scale(
                    scale: _scaleIn.value,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kAccent.withOpacity(0.12),
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withOpacity(0.14),
                            blurRadius: 48,
                            spreadRadius: 6,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(34),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo.jpg',
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 34),
            FadeTransition(
              opacity: _fadeIn,
              child: Text(
                "LieDar",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                  color: kAccent,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 9),
            FadeTransition(
              opacity: _fadeIn,
              child: Text(
                "Truth, Lies & Fun 🎭🤫",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- Main -----
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options:
        kIsWeb
            ? const FirebaseOptions(
              apiKey: "AIzaSyD1-pw...",
              authDomain: "liedar.firebaseapp.com",
              projectId: "liedar",
              storageBucket: "liedar.firebasestorage.app",
              messagingSenderId: "321398923949",
              appId: "1:321398923949:web:xxxxxxxx",
            )
            : null,
  );

  await Supabase.initialize(
    url: 'https://lcmgrrblpcpwjlqhowmd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjbWdycmJscGNwd2pscWhvd21kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU1MjY0MzgsImV4cCI6MjA3MTEwMjQzOH0.cGWXj35FwPoG8GbuZ2IEaiKkBSjTP3_FpBLs4RVL6cs',
  );

  await initNotifications();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission();

  runApp(const MyApp());
}

// ----- Notifications Page (same as you provided) -----
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showPopupNotification(
          message.notification!.title ?? 'Notification',
          message.notification!.body ?? '',
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.notification != null) {
        showPopupNotification(
          message.notification!.title ?? 'Notification',
          message.notification!.body ?? '',
        );
      }
    });
  }

  Future<void> fetchNotifications() async {
    setState(() => loading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          notifications = [];
          loading = false;
        });
        return;
      }
      final response = await Supabase.instance.client
          .from('notifications')
          .select('id, type, body, created_at, dismissed')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);
      setState(() {
        notifications = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      print('ERROR fetching notifications: $e');
      setState(() {
        notifications = [];
        loading = false;
      });
    }
  }

  IconData typeIcon(String? type) {
    switch (type) {
      case 'motivation':
        return Icons.lightbulb;
      case 'reminder':
        return Icons.alarm;
      case 'reaction':
        return Icons.emoji_emotions;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.deepOrange),
        elevation: 2,
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
              ? const Center(child: Text('No Notifications yet! 🎉'))
              : ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, i) {
                  final n = notifications[i];
                  final createdAt = n['created_at'].toString().substring(0, 16);
                  return ListTile(
                    leading: Icon(
                      typeIcon(n['type']),
                      color: Colors.deepOrange,
                      size: 28,
                    ),
                    title: Text(
                      n['body'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      createdAt,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing:
                        n['dismissed'] == false
                            ? const Icon(
                              Icons.circle,
                              size: 10,
                              color: Colors.green,
                            )
                            : null,
                    onTap: () async {
                      if (n['dismissed'] == false) {
                        await Supabase.instance.client
                            .from('notifications')
                            .update({'dismissed': true})
                            .eq('id', n['id']);
                        fetchNotifications();
                      }
                    },
                  );
                },
              ),
    );
  }
}

// ----- MyApp with routes -----
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static const Color kAccent = Color(0xFF00A86B);
  static const Color kBackground = Color(0xffd8e4bc);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "LieDar",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Montserrat',
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: kAccent,
          onPrimary: Colors.white,
          secondary: kBackground,
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          background: kBackground,
          onBackground: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kAccent,
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 23,
            letterSpacing: 1.1,
          ),
        ),
        scaffoldBackgroundColor: kBackground,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kAccent,
          foregroundColor: Colors.white,
          elevation: 8,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: kAccent, width: 2),
          ),
        ),
        buttonTheme: const ButtonThemeData(
          buttonColor: kAccent,
          shape: StadiumBorder(),
          textTheme: ButtonTextTheme.primary,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kAccent,
            textStyle: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => AuthPage(),
        '/home': (context) => HomePage(),
        '/profile': (context) => ProfilePage(),
        '/settings': (context) => SettingsPage(),
        '/submit_lie': (context) => SubmitLiePage(),
        '/explore': (context) => ExploreLiesPage(),
        '/badges': (context) => StreakBadgesPage(),
        '/trends': (context) => RegionalTrendsPage(),
        '/game': (context) => TruthLieGamePage(),
        '/lievault': (context) => LieVaultPage(),
        '/notifications': (context) => const NotificationsPage(),
        // Optionally add liechat route here if you want named route for it:
        // '/liechat': (context) => LieChatUserPage(currentUserId: '<id>'),
      },
    );
  }
}
