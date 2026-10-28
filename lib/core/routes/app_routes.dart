import 'package:flutter/material.dart';
import '../../features/users/screens/splash_screen.dart';
import '../../features/users/screens/login_screen.dart';
import '../../features/users/screens/register_screen.dart';
import '../../features/users/screens/home_screen.dart';

/// Toutes les routes de l'application.
/// Chaque collègue ajoute ici les routes de son module.
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        home: (context) => const HomeScreen(),
      };
}