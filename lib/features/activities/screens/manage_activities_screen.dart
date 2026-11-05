import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart';
import '../../gyms/models/gym.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/activity.dart';
import '../models/activity_session.dart';
import '../services/activity_service.dart';
import '../services/session_service.dart';
import 'activity_form_screen.dart';
import 'activity_ui.dart';
import 'ai_assistant_screen.dart';
import 'session_form_screen.dart';
import 'session_reservations_screen.dart';

/// Tableau de bord du responsable : gérer les activités et le planning d'une
/// de ses salles (sélecteur de salle en haut, deux onglets).
class ManageActivitiesScreen extends StatefulWidget {
  const ManageActivitiesScreen({super.key});

  @override
  State<ManageActivitiesScreen> createState() => _ManageActivitiesScreenState();
}

class _ManageActivitiesScreenState extends State<ManageActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  List<Gym> _gyms = [];
  Gym? _gym;
  bool _loadingGyms = true;

  List<Activity> _activities = [];
  List<ActivitySession> _sessions = [];
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    _loadGyms();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadGyms() async {
    try {
      final gyms = await ActivityService.instance.getManageableGyms();
      setState(() {
        _gyms = gyms;
        _gym = gyms.isNotEmpty ? gyms.first : null;
        _loadingGyms = false;
      });
      if (_gym != null) _loadData();
    } catch (e) {
      if (mounted) setState(() => _loadingGyms = false);
    }
  }

  Future<void> _loadData() async {
    final gym = _gym;
    if (gym == null) return;
    setState(() => _loadingData = true);
    try {
      final activities = await ActivityService.instance.getForGym(gym.id!);
      final sessions = await SessionService.instance.getForGym(gym.id!);
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _sessions = sessions;
        _loadingData = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _confirmDelete(String message, Future<void> Function() action,
      String okLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AColors.red),
            child: Text(okLabel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await action();
      if (mounted) showASnack(context, 'Supprimé.', color: AColors.green);
      _loadData();
    } on AuthException catch (e) {
      if (mounted) showASnack(context, e.message, color: AColors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AColors.grayLight,
      appBar: AppBar(
        title: const Text('Gestion des activités'),
        backgroundColor: AColors.violetDark,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AColors.pink,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Activités', icon: Icon(Icons.fitness_center)),
            Tab(text: 'Planning', icon: Icon(Icons.event)),
          ],
        ),
      ),
      floatingActionButton: _gym == null ? null : _fab(),
      body: _loadingGyms
          ? const Center(child: AppLoader())
          : _gyms.isEmpty
              ? _noGym()
              : Column(
                  children: [
                    _gymPicker(),
                    Expanded(
                      child: _loadingData
                          ? const Center(child: AppLoader())
                          : TabBarView(
                              controller: _tabs,
                              children: [
                                _activitiesTab(),
                                _planningTab(),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _fab() {
    final isActivities = _tabs.index == 0;
    return FloatingActionButton.extended(
      backgroundColor: AColors.pink,
      icon: const Icon(Icons.add),
      label: Text(isActivities ? 'Activité' : 'Séance'),
      onPressed: () async {
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => isActivities
                ? ActivityFormScreen(gymId: _gym!.id!)
                : SessionFormScreen(gymId: _gym!.id!),
          ),
        );
        if (changed == true) _loadData();
      },
    );
  }

  Widget _noGym() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Vous ne gérez aucune salle.\nCréez une salle dans le module '
            '« Salles de sport » pour y ajouter des activités.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AColors.textSecondary),
          ),
        ),
      );

  Widget _gymPicker() {
    if (_gyms.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: pill(Icons.store, _gym!.name, AColors.violet),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DropdownButtonFormField<Gym>(
        initialValue: _gym,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Salle',
          prefixIcon: Icon(Icons.store),
          filled: true,
          fillColor: Colors.white,
        ),
        items: _gyms
            .map((g) => DropdownMenuItem(
                value: g,
                child: Text(g.name, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (g) {
          setState(() => _gym = g);
          _loadData();
        },
      ),
    );
  }

  // ---------- Onglet Activités ----------

  Widget _activitiesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _aiBanner(),
          const SizedBox(height: 12),
          if (_activities.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text('Aucune activité. Touchez « Activité » pour en '
                    'créer une.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AColors.textSecondary)),
              ),
            )
          else
            ..._activities.map(_activityCard),
        ],
      ),
    );
  }

  Widget _aiBanner() => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AiAssistantScreen(gym: _gym!)),
          );
          _loadData(); // des activités ont pu être ajoutées depuis les propositions
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AColors.violetDark, AColors.violet]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assistant IA',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text('Des idées d\'activités adaptées à votre salle',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      );

  Widget _activityCard(Activity a) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      style: const TextStyle(
                          color: AColors.violetDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      pill(Icons.category, a.category.label, AColors.violet),
                      pill(Icons.timer, a.durationLabel, AColors.textSecondary),
                      pill(Icons.signal_cellular_alt, a.level.label,
                          AColors.violet),
                      if ((a.sessionCount ?? 0) > 0)
                        pill(Icons.event, '${a.sessionCount} séance(s)',
                            AColors.green),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ActivityFormScreen(gymId: _gym!.id!, activity: a),
                    ),
                  );
                  if (changed == true) _loadData();
                } else if (v == 'delete') {
                  _confirmDelete(
                    'Supprimer « ${a.name} » ? Ses séances et réservations '
                    'seront aussi supprimées.',
                    () => ActivityService.instance.delete(a.id!),
                    'Supprimer',
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Onglet Planning ----------

  Widget _planningTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _sessions.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text('Aucune séance planifiée.',
                        style: TextStyle(color: AColors.textSecondary)),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: _sessions.map(_sessionCard).toList(),
            ),
    );
  }

  Widget _sessionCard(ActivitySession s) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.activityName ?? 'Séance',
                      style: TextStyle(
                          color: s.isPast
                              ? AColors.textSecondary
                              : AColors.violetDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'inscriptions') {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SessionReservationsScreen(session: s)),
                      );
                    } else if (v == 'edit') {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SessionFormScreen(gymId: _gym!.id!, session: s),
                        ),
                      );
                      if (changed == true) _loadData();
                    } else if (v == 'delete') {
                      _confirmDelete(
                        'Supprimer cette séance ? Les réservations associées '
                        'seront supprimées.',
                        () => SessionService.instance.delete(s.id!),
                        'Supprimer',
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'inscriptions',
                        child: Text('Voir les inscriptions')),
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                pill(Icons.event, s.dateLabel, AColors.violet),
                pill(Icons.schedule, s.timeRangeLabel, AColors.textSecondary),
                if (s.coachName != null)
                  pill(Icons.sports, s.coachName!, AColors.violet),
                placesChip(s),
                if (s.isPast) pill(Icons.history, 'Passée', AColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
