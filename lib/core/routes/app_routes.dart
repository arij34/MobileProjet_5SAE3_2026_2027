import 'package:flutter/material.dart';
import '../../features/users/screens/splash_screen.dart';
import '../../features/users/screens/login_screen.dart';
import '../../features/users/screens/register_screen.dart';
import '../../features/users/screens/home_screen.dart';
import '../../features/users/screens/forgot_password_screen.dart';
import '../../features/users/screens/profile_screen.dart';
import '../../features/users/screens/admin_dashboard_screen.dart';
import '../../features/users/screens/activity_history_screen.dart';
import '../../features/gyms/screens/gyms_list_screen.dart';
import '../../features/gyms/screens/gym_catalog_screen.dart';
import '../../features/gyms/screens/my_memberships_screen.dart';
import '../../features/gyms/screens/membership_requests_screen.dart';
import '../session/permissions.dart';
import '../../features/gyms/screens/coach_gyms_screen.dart';
/// Toutes les routes de l'application.
/// Chaque collègue ajoute ici les routes de son module.
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String forgotPassword = '/forgot-password';
  static const String profile = '/profile';
  static const String adminDashboard = '/admin';
  static const String history = '/history';
  static const String gyms = '/gyms';
  static const String myMemberships = '/my-memberships';
  static const String membershipRequests = '/membership-requests';
  static const String coachGyms = '/coach-gyms';
  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        home: (context) => const HomeScreen(),
        forgotPassword: (context) => const ForgotPasswordScreen(),
        profile: (context) => const ProfileScreen(),
        adminDashboard: (context) => const AdminDashboardScreen(),
        history: (context) => const ActivityHistoryScreen(),
        // L'adhérent voit le catalogue ; les autres rôles, la gestion des salles.
        gyms: (_) => Permissions.currentCan(Permission.joinGym)
            ? const GymCatalogScreen()
            : const GymsListScreen(),
        myMemberships: (_) => const MyMembershipsScreen(),
        membershipRequests: (_) => const MembershipRequestsScreen(),
        coachGyms: (_) => const CoachGymsScreen(),
      };
}