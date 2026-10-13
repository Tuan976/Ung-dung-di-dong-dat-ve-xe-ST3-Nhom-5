import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'routing/app_router.dart';
import 'services/auth_service.dart';
import 'services/booking_service.dart';
import 'services/trip_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await initializeDateFormatting('vi_VN', null);
  } catch (e) {
    debugPrint("Init date formatting error: $e");
  }

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint("Init notification service error: $e");
  }

  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase background handler error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SecureStorage>(create: (_) => SecureStorage()),
        ProxyProvider<SecureStorage, ApiClient>(
          update: (_, storage, __) => ApiClient(secureStorage: storage),
        ),
        ChangeNotifierProxyProvider2<ApiClient, SecureStorage, AuthService>(
          create: (_) => AuthService(ApiClient(secureStorage: SecureStorage()), SecureStorage()),
          update: (_, apiClient, storage, previous) =>
              previous ?? AuthService(apiClient, storage),
        ),
        ProxyProvider<ApiClient, TripService>(
          update: (_, apiClient, __) => TripService(apiClient),
        ),
        ProxyProvider<ApiClient, BookingService>(
          update: (_, apiClient, __) => BookingService(apiClient),
        ),
      ],
      child: MaterialApp.router(
        title: 'VeXe Mobile',
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
