import 'package:flutter/material.dart';
import 'core/routes/app_routes.dart';
import 'features/users/services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ouvre la base (migration comprise) et crée l'admin par défaut.
  // Le try/catch évite un écran noir si la base échoue.
  try {
    await UserService.instance.ensureDefaultAdmin();
  } catch (e, s) {
    debugPrint('ERREUR INIT BASE : $e\n$s');
  }

  runApp(const MyGymApp());
}

class MyGymApp extends StatelessWidget {
  const MyGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyGym',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}