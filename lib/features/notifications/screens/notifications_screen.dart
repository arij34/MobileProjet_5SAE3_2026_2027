import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../challenges/models/challenge_status.dart';
import '../../challenges/services/challenge_service.dart';
import '../../challenges/widgets/challenge_styles.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.service, this.challengeService});

  final NotificationService? service;
  final ChallengeService? challengeService;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = 50;
  NotificationService get _service =>
      widget.service ?? NotificationService.instance;
  List<AppNotification> _items = [];
  bool _loading = true;
  bool _more = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _load({bool append = false}) async {
    if (append && _busy) return;
    if (mounted) setState(() => _busy = true);
    try {
      final items = await _service.getMyNotifications(
        limit: _pageSize,
        offset: append ? _items.length : 0,
      );
      await _service.refreshUnreadCount();
      if (!mounted) return;
      setState(() {
        _items = append ? [..._items, ...items] : items;
        _more = items.length == _pageSize;
        _error = null;
        _loading = false;
      });
    } catch (e, s) {
      debugPrint('ERREUR CHARGEMENT NOTIFICATIONS : $e\n$s');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les notifications';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markAll() async {
    try {
      await _service.markAllAsRead();
      await _load();
    } catch (e, s) {
      debugPrint('ERREUR LECTURE NOTIFICATIONS : $e\n$s');
      _snack('Impossible de marquer les notifications comme lues');
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: const Text('Tout effacer ?'),
        content: const Text('Toutes vos notifications seront supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Effacer',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.clearAll();
      await _load();
    } catch (e, s) {
      debugPrint('ERREUR SUPPRESSION NOTIFICATIONS : $e\n$s');
      _snack('Impossible de supprimer les notifications');
    }
  }

  Future<void> _open(AppNotification notification) async {
    try {
      await _service.markAsRead(notification.id!);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (item) => item.id == notification.id
                  ? item.copyWith(isRead: true)
                  : item,
            )
            .toList();
      });
      final id = notification.challengeId;
      if (id == null) {
        _snack("Ce challenge n'est plus disponible");
        return;
      }
      final challenge = await (widget.challengeService ?? ChallengeService.instance)
          .getChallengeById(id);
      if (challenge == null || challenge.status == ChallengeStatus.cancelled) {
        _snack("Ce challenge n'est plus disponible");
        return;
      }
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        AppRoutes.challengeDetail,
        arguments: id,
      );
      if (mounted) await _load();
    } on ChallengeException {
      _snack("Ce challenge n'est plus disponible");
    } catch (e, s) {
      debugPrint('ERREUR OUVERTURE NOTIFICATION : $e\n$s');
      _snack('Impossible d’ouvrir la notification');
    }
  }

  String _relativeTime(DateTime createdAt) {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inMinutes < 1) return 'À l’instant';
    if (elapsed.inHours < 1) return 'Il y a ${elapsed.inMinutes} min';
    if (elapsed.inDays < 1) return 'Il y a ${elapsed.inHours} h';
    if (elapsed.inDays < 30) return 'Il y a ${elapsed.inDays} j';
    return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  }

  Widget _card(AppNotification item) => Dismissible(
    key: ValueKey(item.id),
    direction: DismissDirection.endToStart,
    background: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(right: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: AppTheme.error,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: const Icon(Icons.delete_outline, color: AppTheme.surface),
    ),
    confirmDismiss: (_) async {
      try {
        await _service.deleteNotification(item.id!);
        return true;
      } catch (e, s) {
        debugPrint('ERREUR SUPPRESSION NOTIFICATION : $e\n$s');
        _snack('Impossible de supprimer la notification');
        return false;
      }
    },
    onDismissed: (_) =>
        setState(() => _items.removeWhere((n) => n.id == item.id)),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: challengeCardDecoration().copyWith(
        border: item.isRead
            ? null
            : Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () => _open(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChallengeIconTile(icon: item.type.icon, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: item.isRead
                              ? FontWeight.w600
                              : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _relativeTime(item.createdAt),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.isRead)
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 4),
                    child: Icon(Icons.circle, size: 9, color: AppTheme.accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: Column(
      children: [
        GradientHeader(
          title: 'Notifications',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Tout marquer comme lu',
                icon: const Icon(Icons.done_all, color: AppTheme.surface),
                onPressed: _busy ? null : _markAll,
              ),
              IconButton(
                tooltip: 'Tout effacer',
                icon: const Icon(Icons.delete_outline, color: AppTheme.surface),
                onPressed: _busy ? null : _clearAll,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: AppLoader(size: 48))
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  top: false,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 64,
                                  color: AppTheme.purpleLight,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Aucune notification',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        for (final item in _items) _card(item),
                        if (_more)
                          TextButton(
                            onPressed: _busy ? null : () => _load(append: true),
                            child: const Text('Afficher plus'),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}
