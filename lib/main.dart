import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'pages/buyer/home_screen.dart';
import 'controllers/auth_controller.dart';

import 'pages/admin/home_screen.dart';
import 'pages/courier/home_screen.dart';
import 'pages/branch/home_screen.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'services/local_notification_service.dart';
import 'services/notification_service.dart';

import 'package:flutter/services.dart';
import 'services/courier_background_notification_service.dart';
import 'services/admin_background_notification_service.dart';
import 'services/background_notification_service.dart';

import 'package:timeago/timeago.dart' as timeago;
import 'services/chat_service.dart';
import 'services/buyer_chat_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await showNotification();
    return Future.value(true);
  });
}

Future<void> showNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'channel_id',
    'Background Notifications',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    'Reminder!',
    'Cek aplikasi sekarang!',
    platformDetails,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications
  await LocalNotificationService().initNotification();

  await _initializeNotifications();

  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Set false jika sudah release
  );

  await Supabase.initialize(
    url: 'https://hfeolsmaqsjfueypfebj.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhmZW9sc21hcXNqZnVleXBmZWJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgzOTA1MDIsImV4cCI6MjA1Mzk2NjUwMn0.fLpXoLsYY_c16kjS-pGVGRf1LSLTZn6kI3ilK-_9ktI',
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    debug: true,
  );

  // Setup lifecycle observer untuk mendeteksi status aplikasi
  SystemChannels.lifecycle.setMessageHandler((msg) {
    if (msg == AppLifecycleState.paused.toString()) {
      NotificationService.isAppInForeground = false;
    } else if (msg == AppLifecycleState.resumed.toString()) {
      NotificationService.isAppInForeground = true;
    }
    return Future.value(msg);
  });

  await NotificationService.initialize();

  Get.put(AuthController());
  Get.put(RouteObserver<Route>());
  // Get.put(CartController());

  // Hanya inisialisasi background service
  await CourierBackgroundNotificationService().initialize();

  // Inisialisasi admin background service
  await AdminBackgroundNotificationService().initialize();

  // Initialize background notifications
  await BackgroundNotificationService.initialize();

  timeago.setLocaleMessages('id', timeago.IdMessages());

  // Setelah inisialisasi Supabase
  BuyerChatService().initializeMessageListener();

  runApp(GetMaterialApp(
    title: 'E-Commerce App',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: const SplashScreen(),
    getPages: [
      GetPage(name: '/splash', page: () => SplashScreen()),
      GetPage(name: '/login', page: () => LoginPage()),
      GetPage(name: '/register', page: () => RegisterPage()),
      GetPage(name: '/buyer/home_screen', page: () => BuyerHomeScreen()),
      GetPage(name: '/admin/home_screen', page: () => AdminHomeScreen()),
      GetPage(name: '/courier/home_screen', page: () => CourierHomeScreen()),
      GetPage(name: '/branch/home_screen', page: () => BranchHomeScreen()),
    ],
    navigatorObservers: [RouteObserver<PageRoute>()],
  ));
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Langsung ke BuyerHomeScreen untuk semua user
        return BuyerHomeScreen();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home: const AuthWrapper(),
      getPages: [
        GetPage(name: '/login', page: () => LoginPage()),
        GetPage(name: '/register', page: () => RegisterPage()),
        GetPage(name: '/buyer/home', page: () => BuyerHomeScreen()),
      ],
    );
  }
}
