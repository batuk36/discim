import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/clinic/screens/clinic_detail_screen.dart';
import 'features/appointment/screens/appointment_screen.dart';
import 'features/appointment/screens/my_appointments_screen.dart';
import 'features/messages/screens/messages_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/auth/screens/dentist_register_screen.dart';
import 'features/dentist/screens/dentist_home_screen.dart';

GoRouter createRouter(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';

      if (!authProvider.initialized) {
        return isSplash ? null : '/splash';
      }

      if (isSplash) {
        return authProvider.isLoggedIn
            ? (authProvider.role == AuthRole.dentist ? '/dentist' : '/home')
            : '/login';
      }

      final isLoggedIn = authProvider.isLoggedIn;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/dentist-register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        return authProvider.role == AuthRole.dentist ? '/dentist' : '/home';
      }
      return null;
    },
    refreshListenable: authProvider,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/clinic/:id',
        builder: (_, state) =>
            ClinicDetailScreen(clinicId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/appointment/:clinicId',
        builder: (_, state) =>
            AppointmentScreen(clinicId: state.pathParameters['clinicId']!),
      ),
      GoRoute(path: '/appointments', builder: (_, __) => const MyAppointmentsScreen()),
      GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/dentist', builder: (_, __) => const DentistHomeScreen()),
      GoRoute(path: '/dentist-register', builder: (_, __) => const DentistRegisterScreen()),
    ],
  );
}
