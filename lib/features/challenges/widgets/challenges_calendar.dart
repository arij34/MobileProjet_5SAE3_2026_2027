import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../models/challenge_task_log.dart';
import '../models/participant_status.dart';
import '../services/participation_service.dart';
import 'challenge_styles.dart';

class ChallengesCalendar extends StatefulWidget {
  const ChallengesCalendar({
    super.key,
    required this.onDiscover,
    this.onDetailClosed,
    this.service,
    this.now,
  });

  final VoidCallback onDiscover;
  final Future<void> Function()? onDetailClosed;
  final ParticipationService? service;
  final DateTime Function()? now;

  @override
  State<ChallengesCalendar> createState() => _ChallengesCalendarState();
}

class _ChallengesCalendarState extends State<ChallengesCalendar> {
  static const _palette = [
    AppTheme.primary,
    AppTheme.accent,
    AppTheme.purpleLight,
    AppTheme.challengeLight,
  ];
  static final _first = DateTime(1900);
  static final _last = DateTime(2200, 12, 31);
  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  late DateTime _selected;
  late DateTime _focused;
  final _shown = ParticipantStatus.values.toSet();
  List<MyChallenge> _entries = const [];
  List<CalendarDayDetail> _details = const [];
  Map<String, int> _loggedDays = const {};
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  int _request = 0;

  ParticipationService get _service =>
      widget.service ?? ParticipationService.instance;
  DateTime get _today => _dateOnly((widget.now ?? DateTime.now)());

  @override
  void initState() {
    super.initState();
    final today = _today;
    _focused = today;
    _selected = _focused;
    _load();
  }

  Future<void> _load({bool logSelection = false}) async {
    final request = ++_request;
    final focused = _focused;
    final selected = _selected;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await initializeDateFormatting('fr_FR');
      final first = DateTime(focused.year, focused.month);
      final visibleStart = DateTime(
        first.year,
        first.month,
        1 - first.weekday + 1,
      );
      final visibleEnd = DateTime(
        visibleStart.year,
        visibleStart.month,
        visibleStart.day + 41,
      );
      final entries = await _service.getCalendarEntries();
      final logs = await _service.getLoggedDays(visibleStart, visibleEnd);
      final details = await _service.getDayDetail(selected);
      if (kDebugMode && logSelection) {
        debugPrint(
          'Calendrier: jour sélectionné $selected, isUtc=${selected.isUtc}, ${details.length} challenges',
        );
      }
      if (!mounted || request != _request) return;
      setState(() {
        _entries = entries;
        _loggedDays = logs;
        _details = details;
        _loading = false;
        _hasLoaded = true;
      });
    } catch (e, s) {
      debugPrint('ERREUR CALENDRIER CHALLENGES : $e\n$s');
      if (!mounted || request != _request) return;
      setState(() {
        _error = 'Impossible de charger le calendrier';
        _loading = false;
      });
    }
  }

  void _select(
    DateTime selected,
    DateTime focused, {
    bool logSelection = false,
  }) {
    setState(() {
      _selected = _dateOnly(selected);
      _focused = _dateOnly(focused);
    });
    _load(logSelection: logSelection);
  }

  void _changeMonth(int months) {
    final next = DateTime(_focused.year, _focused.month + months, 1);
    if (next.isBefore(_first) || next.isAfter(_last)) return;
    _select(next, next);
  }

  Color _color(MyChallenge entry) => switch (entry.participation.status) {
    ParticipantStatus.completed => AppTheme.success,
    ParticipantStatus.abandoned => AppTheme.textSecondary,
    ParticipantStatus.joined => _palette[entry.challenge.id! % _palette.length],
  };

  bool _runsOn(MyChallenge entry, DateTime day) {
    final key = ChallengeTaskLog.dateKey(_dateOnly(day));
    return key.compareTo(ChallengeTaskLog.dateKey(entry.challenge.startDate)) >=
            0 &&
        key.compareTo(ChallengeTaskLog.dateKey(entry.challenge.endDate)) <= 0;
  }

  Future<void> _openDetail(int id) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.challengeDetail,
      arguments: id,
    );
    if (!mounted) return;
    await widget.onDetailClosed?.call();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const Center(child: AppLoader(size: 48));
    }
    if (_error != null && !_hasLoaded) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Center(child: Text(_error!)),
            Center(
              child: TextButton(
                onPressed: _load,
                child: const Text('Réessayer'),
              ),
            ),
          ],
        ),
      );
    }
    final details = _details.where(
      (item) => _shown.contains(item.entry.participation.status),
    );
    final dateText = DateFormat('EEEE d MMMM', 'fr_FR').format(_selected);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: challengeCardDecoration(),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Mois précédent',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMM('fr_FR').format(_focused),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sectionTitle.copyWith(fontSize: 15),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mois suivant',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    TextButton(
                      onPressed: () => _select(_today, _today),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 36),
                        shape: const StadiumBorder(),
                        backgroundColor: AppTheme.lavender,
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Aujourd’hui'),
                    ),
                  ],
                ),
                TableCalendar<MyChallenge>(
                  firstDay: _first,
                  lastDay: _last,
                  focusedDay: _focused,
                  currentDay: _today,
                  locale: 'fr_FR',
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarFormat: CalendarFormat.month,
                  headerVisible: false,
                  sixWeekMonthsEnforced: true,
                  rowHeight: 44,
                  daysOfWeekHeight: 22,
                  selectedDayPredicate: (day) =>
                      isSameDay(_dateOnly(day), _selected),
                  onDaySelected: (selected, focused) =>
                      _select(selected, focused, logSelection: true),
                  onPageChanged: (day) {
                    final focused = _dateOnly(day);
                    final selected =
                        _selected.year == focused.year &&
                            _selected.month == focused.month
                        ? _selected
                        : focused;
                    _select(selected, focused);
                  },
                  eventLoader: (day) => _entries
                      .where(
                        (entry) =>
                            _shown.contains(entry.participation.status) &&
                            _runsOn(entry, day),
                      )
                      .toList(),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.purpleLight.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    outsideTextStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders<MyChallenge>(
                    markerBuilder: (context, day, entries) {
                      final logged =
                          _loggedDays[ChallengeTaskLog.dateKey(
                            _dateOnly(day),
                          )] ??
                          0;
                      if (entries.isEmpty && logged == 0) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        bottom: 1,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final entry in entries.take(3))
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _color(entry),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (logged > 0)
                              const Icon(
                                Icons.check_circle,
                                color: AppTheme.accent,
                                size: 9,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final status in ParticipantStatus.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FilterChip(
                            label: Center(
                              child: Text(
                                status.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            labelStyle: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                            ),
                            showCheckmark: false,
                            selected: _shown.contains(status),
                            selectedColor: AppTheme.lavender,
                            backgroundColor: AppTheme.surface,
                            side: const BorderSide(color: AppTheme.borderColor),
                            shape: const StadiumBorder(),
                            visualDensity: VisualDensity.compact,
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _shown.add(status);
                              } else {
                                _shown.remove(status);
                              }
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${dateText[0].toUpperCase()}${dateText.substring(1)}',
            style: AppTheme.sectionTitle,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: AppLoader(size: 32)),
            )
          else if (_error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Réessayer')),
              ],
            )
          else if (details.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucun challenge ce jour'),
            ),
          if (!_loading && _error == null)
            for (final detail in details) _detailCard(detail),
          if (!_loading && _error == null && _entries.isEmpty) ...[
            const Text('Rejoignez un challenge pour le voir ici'),
            Center(
              child: OutlinedButton(
                onPressed: widget.onDiscover,
                child: const Text('Découvrir'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailCard(CalendarDayDetail detail) {
    final entry = detail.entry;
    final challenge = entry.challenge;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: challengeCardDecoration(),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () => _openDetail(challenge.id!),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(challenge.title, style: AppTheme.sectionTitle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChallengeChip(
                      label: entry.participation.status.label,
                      icon: Icons.flag_outlined,
                      color: _color(entry),
                    ),
                    ChallengeChip(
                      label:
                          'Jour ${detail.day.dayNumber}/${challenge.totalDays}',
                      icon: Icons.calendar_today,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
