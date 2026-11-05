import 'equipment_category.dart';
import 'equipment_state.dart';
import 'gym_equipment_table.dart';

/// Un équipement appartenant à une salle (tapis, haltères, vélos...).
class GymEquipment {
  final int? id;
  final int gymId;
  final String name;
  final EquipmentCategory category;
  final int quantity;
  final EquipmentState state;
  final String? photoPath;
  final DateTime createdAt;

  const GymEquipment({
    this.id,
    required this.gymId,
    required this.name,
    this.category = EquipmentCategory.other,
    this.quantity = 1,
    this.state = EquipmentState.good,
    this.photoPath,
    required this.createdAt,
  });

  bool get isUsable => state != EquipmentState.outOfOrder;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) GymEquipmentTable.colId: id,
      GymEquipmentTable.colGymId: gymId,
      GymEquipmentTable.colName: name,
      GymEquipmentTable.colCategory: category.value,
      GymEquipmentTable.colQuantity: quantity,
      GymEquipmentTable.colState: state.value,
      GymEquipmentTable.colPhotoPath: photoPath,
      GymEquipmentTable.colCreatedAt: createdAt.toIso8601String(),
    };
  }

  factory GymEquipment.fromMap(Map<String, dynamic> map) {
    return GymEquipment(
      id: map[GymEquipmentTable.colId] as int?,
      gymId: map[GymEquipmentTable.colGymId] as int,
      name: map[GymEquipmentTable.colName] as String,
      category: EquipmentCategory.fromValue(
          map[GymEquipmentTable.colCategory] as String?),
      quantity: (map[GymEquipmentTable.colQuantity] as int?) ?? 1,
      state:
          EquipmentState.fromValue(map[GymEquipmentTable.colState] as String?),
      photoPath: map[GymEquipmentTable.colPhotoPath] as String?,
      createdAt: DateTime.parse(map[GymEquipmentTable.colCreatedAt] as String),
    );
  }

  GymEquipment copyWith({
    int? id,
    int? gymId,
    String? name,
    EquipmentCategory? category,
    int? quantity,
    EquipmentState? state,
    String? photoPath,
    DateTime? createdAt,
  }) {
    return GymEquipment(
      id: id ?? this.id,
      gymId: gymId ?? this.gymId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      state: state ?? this.state,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
