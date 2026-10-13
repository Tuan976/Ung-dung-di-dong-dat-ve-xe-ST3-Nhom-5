import 'package:go_router/go_router.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/trip_history_screen.dart';
import '../screens/profile/terms_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/tickets/my_tickets_screen.dart';
import '../screens/tickets/ticket_detail_screen.dart';
import '../screens/trips/search_results_screen.dart';
import '../screens/trips/trip_detail_screen.dart';
import '../screens/seat_selection/seat_selection_screen.dart';
import '../screens/booking/passenger_info_screen.dart';
import '../screens/booking/booking_confirmation_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../screens/sos/sos_screen.dart';
import '../screens/vision/vision_assistant_screen.dart';
import '../screens/map_booking/map_booking_screen.dart';
import '../models/trip.dart';
import '../models/booking.dart';
import '../models/map_station.dart';
import '../widgets/global_shake_listener.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      ShellRoute(
        builder: (context, state, child) => GlobalShakeListener(child: child),
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
          GoRoute(path: '/sos', builder: (context, state) => const SosScreen()),
          GoRoute(path: '/vision', builder: (context, state) => const VisionAssistantScreen()),
          GoRoute(
            path: '/map_booking',
            builder: (context, state) => const MapBookingScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: '/forgot_password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/trip-history',
            builder: (context, state) => const TripHistoryScreen(),
          ),
          GoRoute(
            path: '/terms',
            builder: (context, state) => const TermsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/tickets',
            builder: (context, state) => const MyTicketsScreen(),
          ),
          GoRoute(
            path: '/tickets/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return TicketDetailScreen(bookingId: id);
            },
          ),
          GoRoute(
            path: '/search_results',
            builder: (context, state) {
              final from = state.uri.queryParameters['from'] ?? '';
              final to = state.uri.queryParameters['to'] ?? '';
              final date = state.uri.queryParameters['date'] ?? '';
              final extra = state.extra as Map<String, dynamic>?;
              return SearchResultsScreen(
                from: from,
                to: to,
                date: date,
                pickupStop: extra?['pickup_stop'] as MapStation?,
                dropoffStop: extra?['dropoff_stop'] as MapStation?,
              );
            },
          ),
          GoRoute(
            path: '/trip/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final extra = state.extra as Map<String, dynamic>?;
              return TripDetailScreen(
                tripId: id,
                pickupStop: extra?['pickup_stop'] as MapStation?,
                dropoffStop: extra?['dropoff_stop'] as MapStation?,
              );
            },
          ),
          GoRoute(
            path: '/seat_selection',
            builder: (context, state) {
              Trip? trip;
              String? initialPickup;
              String? initialDropoff;
              String? pickupStationId;
              String? dropoffStationId;

              if (state.extra is Trip) {
                trip = state.extra as Trip;
              } else if (state.extra is Map<String, dynamic>) {
                final map = state.extra as Map<String, dynamic>;
                trip = map['trip'] as Trip?;
                initialPickup = map['pickup'] as String?;
                initialDropoff = map['dropoff'] as String?;
                pickupStationId = map['pickup_station_id'] as String?;
                dropoffStationId = map['dropoff_station_id'] as String?;
              }

              if (trip == null) return const HomeScreen();
              return SeatSelectionScreen(
                initialTrip: trip,
                initialPickup: initialPickup,
                initialDropoff: initialDropoff,
                pickupStationId: pickupStationId,
                dropoffStationId: dropoffStationId,
              );
            },
          ),
          GoRoute(
            path: '/passenger_info',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              if (extra == null) return const HomeScreen();
              final trip = extra['trip'] as Trip;
              final seat = extra['seat'] as String;
              final pickup = extra['pickup'] as String?;
              final dropoff = extra['dropoff'] as String?;
              final pickupStationId = extra['pickup_station_id'] as String?;
              final dropoffStationId = extra['dropoff_station_id'] as String?;
              return PassengerInfoScreen(
                trip: trip,
                seat: seat,
                initialPickup: pickup,
                initialDropoff: dropoff,
                pickupStationId: pickupStationId,
                dropoffStationId: dropoffStationId,
              );
            },
          ),
          GoRoute(
            path: '/booking_confirmation',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              if (extra == null) return const HomeScreen();
              final booking = extra['booking'] as Booking;
              final trip = extra['trip'] as Trip;
              return BookingConfirmationScreen(booking: booking, trip: trip);
            },
          ),
          GoRoute(
            path: '/payment',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              if (extra == null) return const HomeScreen();
              final booking = extra['booking'] as Booking;
              final trip = extra['trip'] as Trip;
              return PaymentScreen(booking: booking, trip: trip);
            },
          ),
        ],
      ),
    ],
  );
}
