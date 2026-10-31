import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../users/models/user_role.dart';
import '../models/user.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Palette MyGym
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);

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
      SnackBar(
        content: Text('Module « $module » : en cours de développement.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _violetDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: _grayLight,
        body: Center(child: AppLoader(size: 48, color: _pink)),
      );
    }

    final modules = <_ModuleItem>[
      _ModuleItem('Salles de sport', 'Trouver une salle', Icons.fitness_center,
          const [Color(0xFF4C378E), Color(0xFF7B5BC4)],
          () => _soon('Salles de sport')),
      _ModuleItem('Challenges', 'Relever des défis', Icons.emoji_events,
          const [Color(0xFFD43DA7), Color(0xFFE97BC8)],
          () => _soon('Challenges')),
      _ModuleItem('Nutrition', 'Programmes & conseils', Icons.restaurant_menu,
          const [Color(0xFFA86BEE), Color(0xFFC9A7F5)],
          () => _soon('Nutrition')),
      _ModuleItem('Activités', 'Réserver une séance', Icons.event_available,
          const [Color(0xFF6C4FB8), Color(0xFFA86BEE)],
          () => _soon('Activités')),
    ];

    return Scaffold(
      backgroundColor: _grayLight,
      body: Column(
        children: [
          _buildHeader(user),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              children: [
                // Carte réservée à l'administrateur
                if (user.role == UserRole.admin) ...[
                  _buildAdminCard(),
                  const SizedBox(height: 26),
                ],

                const Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _violetDark,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.95,
                  children: modules.map((m) => _ModuleCard(item: m)).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- En-tête ----------

    Widget _buildHeader(User user) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_violetDark, _violet],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 14, 26),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MyGym',
                      style: TextStyle(
                        color: _lilac.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$_greeting, ${user.firstName} 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.role.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Mon profil',
                icon: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _lilac, width: 2),
                  ),
                  child: UserAvatar(
                    photoUrl: user.photoUrl,
                    initial: user.firstName.isEmpty
                        ? '?'
                        : user.firstName[0].toUpperCase(),
                    radius: 22,
                  ),
                ),
                onPressed: () async {
                  await Navigator.pushNamed(context, AppRoutes.profile);
                  if (mounted) setState(() {}); // nom ou photo modifiés
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Carte administrateur ----------

  Widget _buildAdminCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.pushNamed(context, AppRoutes.adminDashboard),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_pink, Color(0xFFE97BC8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _pink.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tableau de bord administrateur',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Valider les comptes, gérer les rôles',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ---------- Modules ----------

class _ModuleItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  _ModuleItem(this.title, this.subtitle, this.icon, this.colors, this.onTap);
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;
  const _ModuleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4C378E).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: item.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: Colors.white, size: 28),
            ),
            const Spacer(),
            Text(
              item.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF4C378E),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7A7390),
              ),
            ),
          ],
        ),
      ),
    );
  }
}