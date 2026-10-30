import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../users/models/user_role.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Sécurité : sans utilisateur connecté, retour à la connexion.
    if (!SessionManager.instance.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.login, (route) => false);
      });
    }
  }

  void _soon(String module) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Module « $module » : en cours de développement.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final modules = <_ModuleItem>[
      _ModuleItem('Salles de sport', Icons.fitness_center,
          () => _soon('Salles de sport')),
      _ModuleItem('Challenges', Icons.emoji_events, () => _soon('Challenges')),
      _ModuleItem('Nutrition', Icons.restaurant_menu, () => _soon('Nutrition')),
      _ModuleItem('Activités', Icons.event_available, () => _soon('Activités')),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFE),
      appBar: AppBar(
        title: const Text('MyGym'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 30),
            tooltip: 'Mon profil',
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.profile);
              if (mounted) setState(() {}); // le nom a pu changer
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Bonjour, ${user.firstName} 👋',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user.role.label,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 22),

          // Carte réservée à l'administrateur
          if (user.role == UserRole.admin) ...[
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.pushNamed(context, AppRoutes.adminDashboard),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9B6DE0), Color(0xFFC9A7F5)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tableau de bord administrateur',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          SizedBox(height: 4),
                          Text('Valider les comptes, gérer les rôles',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],

          const Text('Services',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
            children: modules.map((m) => _ModuleCard(item: m)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ModuleItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  _ModuleItem(this.title, this.icon, this.onTap);
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;
  const _ModuleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 38, color: AppTheme.purpleLight),
            const SizedBox(height: 10),
            Text(item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}