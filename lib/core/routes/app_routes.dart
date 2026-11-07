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
import '../../features/activities/screens/activities_home_screen.dart';
import '../../features/nutrition/screens/nutrition_shell_screen.dart';
import '../../features/challenges/screens/challenges_screen.dart';
import '../../features/challenges/screens/challenge_form_screen.dart';
import '../../features/challenges/screens/challenge_detail_screen.dart';
import '../../features/challenges/screens/admin_challenges_screen.dart';
import '../../features/challenges/screens/ai_challenge_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
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
  static const String activities = '/activities';
  static const String nutrition = '/nutrition';
  static const String challenges = '/challenges';
  static const String challengeForm = '/challenge-form';
  static const String aiChallenge = '/ai-challenge';
  static const String challengeDetail = '/challenge-detail';
  static const String adminChallenges = '/admin-challenges';
  static const String notifications = '/notifications';
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
        activities: (_) => const ActivitiesHomeScreen(),
        nutrition: (_) => const NutritionShellScreen(),
        challenges: (_) => Permissions.currentCan(Permission.reviewChallenges)
            ? const AdminChallengesScreen()
            : const ChallengesScreen(),
        challengeForm: (_) => const ChallengeFormScreen(),
        aiChallenge: (_) => const AiChallengeScreen(),
        adminChallenges: (_) => const AdminChallengesScreen(),
        notifications: (_) => const NotificationsScreen(),
        challengeDetail: (context) => ChallengeDetailScreen(
              challengeId:
                  ModalRoute.of(context)?.settings.arguments as int? ?? -1,
            ),
      };
}