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
import 'widgets/global_shake_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
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
