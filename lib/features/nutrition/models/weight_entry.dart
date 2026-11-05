import 'nutrition_tables.dart';

/// Un relevé de poids daté.
class WeightEntry {
  final int? id;
  final int userId;
  final double weight;
  final DateTime recordedAt;

  const WeightEntry({
    this.id,
    required this.userId,
    required this.weight,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) WeightHistoryTable.colId: id,
        WeightHistoryTable.colUserId: userId,
        WeightHistoryTable.colWeight: weight,
        WeightHistoryTable.colRecordedAt: recordedAt.toIso8601String(),
      };

  factory WeightEntry.fromMap(Map<String, dynamic> map) => WeightEntry(
        id: map[WeightHistoryTable.colId] as int?,
        userId: map[WeightHistoryTable.colUserId] as int,
        weight: ((map[WeightHistoryTable.colWeight] as num?) ?? 0).toDouble(),
        recordedAt:
            DateTime.parse(map[WeightHistoryTable.colRecordedAt] as String),
      );
}
