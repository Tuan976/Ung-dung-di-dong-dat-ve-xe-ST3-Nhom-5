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
import '../models/trip.dart';
import '../models/booking.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/sos', builder: (context, state) => const SosScreen()),
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
          return SearchResultsScreen(from: from, to: to, date: date);
        },
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TripDetailScreen(tripId: id);
        },
      ),
      GoRoute(
        path: '/seat_selection',
        builder: (context, state) {
          final trip = state.extra as Trip?;
          if (trip == null) return const HomeScreen();
          return SeatSelectionScreen(initialTrip: trip);
        },
      ),
      GoRoute(
        path: '/passenger_info',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) return const HomeScreen();
          final trip = extra['trip'] as Trip;
          final seat = extra['seat'] as String;
          return PassengerInfoScreen(trip: trip, seat: seat);
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
  );
}
