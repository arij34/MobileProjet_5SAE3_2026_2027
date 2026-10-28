import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/database/database_helper.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/users/services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper.instance.debugListTables();
  await UserService.instance.ensureDefaultAdmin();

  // --- TEST PROVISOIRE (à supprimer à l'étape 6) ---
  if (kDebugMode) {
    try {
      final admin = await UserService.instance.login(
        UserService.defaultAdminEmail,
        UserService.defaultAdminPassword,
      );
      debugPrint('Connexion OK : ${admin.fullName} (${admin.role.label})');
    } catch (e) {
      debugPrint('Échec du test de connexion : $e');
    }
  }
  // --------------------------------------------------

  runApp(const MyGymApp());
}

class MyGymApp extends StatelessWidget {
  const MyGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyGym',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}