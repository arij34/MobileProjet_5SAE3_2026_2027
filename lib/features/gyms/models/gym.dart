import 'gym_status.dart';
import 'gym_table.dart';

class Gym {
  final int? id;
  final int ownerId; // responsable de la salle (users.id)
  final String name;
  final String description;
  final String address;
  final String city;
  final double? latitude;
  final double? longitude;
  final String phone;
  final String openingHours;
  final int capacity;
  final double priceMonthly;
  final GymStatus status;
  final String? photoPath;
  final DateTime createdAt;

  const Gym({
    this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    required this.address,
    required this.city,
    this.latitude,
    this.longitude,
    this.phone = '',
    this.openingHours = '',
    this.capacity = 0,
    this.priceMonthly = 0,
    this.status = GymStatus.open,
    this.photoPath,
    required this.createdAt,
  });

  bool get isOpen => status == GymStatus.open;
  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) GymTable.colId: id,
      GymTable.colOwnerId: ownerId,
      GymTable.colName: name,
      GymTable.colDescription: description,
      GymTable.colAddress: address,
      GymTable.colCity: city,
      GymTable.colLatitude: latitude,
      GymTable.colLongitude: longitude,
      GymTable.colPhone: phone,
      GymTable.colOpeningHours: openingHours,
      GymTable.colCapacity: capacity,
      GymTable.colPriceMonthly: priceMonthly,
      GymTable.colStatus: status.value,
      GymTable.colPhotoPath: photoPath,
      GymTable.colCreatedAt: createdAt.toIso8601String(),
    };
  }

  factory Gym.fromMap(Map<String, dynamic> map) {
    return Gym(
      id: map[GymTable.colId] as int?,
      ownerId: map[GymTable.colOwnerId] as int,
      name: map[GymTable.colName] as String,
      description: (map[GymTable.colDescription] as String?) ?? '',
      address: map[GymTable.colAddress] as String,
      city: map[GymTable.colCity] as String,
      latitude: (map[GymTable.colLatitude] as num?)?.toDouble(),
      longitude: (map[GymTable.colLongitude] as num?)?.toDouble(),
      phone: (map[GymTable.colPhone] as String?) ?? '',
      openingHours: (map[GymTable.colOpeningHours] as String?) ?? '',
      capacity: (map[GymTable.colCapacity] as int?) ?? 0,
      priceMonthly: ((map[GymTable.colPriceMonthly] as num?) ?? 0).toDouble(),
      status: GymStatus.fromValue(map[GymTable.colStatus] as String?),
      photoPath: map[GymTable.colPhotoPath] as String?,
      createdAt: DateTime.parse(map[GymTable.colCreatedAt] as String),
    );
  }

  Gym copyWith({
    int? id,
    int? ownerId,
    String? name,
    String? description,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    String? phone,
    String? openingHours,
    int? capacity,
    double? priceMonthly,
    GymStatus? status,
    String? photoPath,
    DateTime? createdAt,
  }) {
    return Gym(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      openingHours: openingHours ?? this.openingHours,
      capacity: capacity ?? this.capacity,
      priceMonthly: priceMonthly ?? this.priceMonthly,
      status: status ?? this.status,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
