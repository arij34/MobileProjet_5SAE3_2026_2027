import '../../users/models/user_gender.dart';
import 'nutrition_enums.dart';
import 'nutrition_tables.dart';

/// Profil nutritionnel d'un utilisateur : données corporelles + objectifs.
/// Complète le compte existant sans dupliquer : l'âge, le sexe, la taille et le
/// poids peuvent être pré-remplis depuis le profil du module Utilisateurs.
class NutritionProfile {
  final int? id;
  final int userId;
  final int? age;
  final UserGender? sex;
  final double? heightCm;
  final double? weightKg;
  final NutritionActivityLevel activityLevel;
  final NutritionGoal goal;
  final double dailyCaloriesGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatsGoal;
  final String foodPreferences;
  final String allergies;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NutritionProfile({
    this.id,
    required this.userId,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.activityLevel = NutritionActivityLevel.moderate,
    this.goal = NutritionGoal.maintain,
    this.dailyCaloriesGoal = 0,
    this.proteinGoal = 0,
    this.carbsGoal = 0,
    this.fatsGoal = 0,
    this.foodPreferences = '',
    this.allergies = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// IMC = poids / taille² (taille en mètres). Null si données manquantes.
  double? get bmi {
    final h = heightCm;
    final w = weightKg;
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  /// Liste d'allergies normalisée (minuscules, sans vide) pour la détection.
  List<String> get allergyList => allergies
      .split(RegExp('[,;\n]'))
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList();

  bool get isComplete =>
      age != null && sex != null && heightCm != null && weightKg != null;

  Map<String, dynamic> toMap() => {
        if (id != null) NutritionProfileTable.colId: id,
        NutritionProfileTable.colUserId: userId,
        NutritionProfileTable.colAge: age,
        NutritionProfileTable.colSex: sex?.value,
        NutritionProfileTable.colHeight: heightCm,
        NutritionProfileTable.colWeight: weightKg,
        NutritionProfileTable.colActivityLevel: activityLevel.value,
        NutritionProfileTable.colGoal: goal.value,
        NutritionProfileTable.colDailyCaloriesGoal: dailyCaloriesGoal,
        NutritionProfileTable.colProteinGoal: proteinGoal,
        NutritionProfileTable.colCarbsGoal: carbsGoal,
        NutritionProfileTable.colFatsGoal: fatsGoal,
        NutritionProfileTable.colFoodPreferences: foodPreferences,
        NutritionProfileTable.colAllergies: allergies,
        NutritionProfileTable.colCreatedAt: createdAt.toIso8601String(),
        NutritionProfileTable.colUpdatedAt: updatedAt.toIso8601String(),
      };

  factory NutritionProfile.fromMap(Map<String, dynamic> map) => NutritionProfile(
        id: map[NutritionProfileTable.colId] as int?,
        userId: map[NutritionProfileTable.colUserId] as int,
        age: map[NutritionProfileTable.colAge] as int?,
        sex: UserGender.fromValue(map[NutritionProfileTable.colSex] as String?),
        heightCm:
            (map[NutritionProfileTable.colHeight] as num?)?.toDouble(),
        weightKg:
            (map[NutritionProfileTable.colWeight] as num?)?.toDouble(),
        activityLevel: NutritionActivityLevel.fromValue(
            map[NutritionProfileTable.colActivityLevel] as String?),
        goal: NutritionGoal.fromValue(
            map[NutritionProfileTable.colGoal] as String?),
        dailyCaloriesGoal:
            ((map[NutritionProfileTable.colDailyCaloriesGoal] as num?) ?? 0)
                .toDouble(),
        proteinGoal:
            ((map[NutritionProfileTable.colProteinGoal] as num?) ?? 0)
                .toDouble(),
        carbsGoal:
            ((map[NutritionProfileTable.colCarbsGoal] as num?) ?? 0).toDouble(),
        fatsGoal:
            ((map[NutritionProfileTable.colFatsGoal] as num?) ?? 0).toDouble(),
        foodPreferences:
            (map[NutritionProfileTable.colFoodPreferences] as String?) ?? '',
        allergies:
            (map[NutritionProfileTable.colAllergies] as String?) ?? '',
        createdAt: DateTime.parse(
            map[NutritionProfileTable.colCreatedAt] as String),
        updatedAt: DateTime.parse(
            map[NutritionProfileTable.colUpdatedAt] as String),
      );

  NutritionProfile copyWith({
    int? age,
    UserGender? sex,
    double? heightCm,
    double? weightKg,
    NutritionActivityLevel? activityLevel,
    NutritionGoal? goal,
    double? dailyCaloriesGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatsGoal,
    String? foodPreferences,
    String? allergies,
    DateTime? updatedAt,
  }) =>
      NutritionProfile(
        id: id,
        userId: userId,
        age: age ?? this.age,
        sex: sex ?? this.sex,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        goal: goal ?? this.goal,
        dailyCaloriesGoal: dailyCaloriesGoal ?? this.dailyCaloriesGoal,
        proteinGoal: proteinGoal ?? this.proteinGoal,
        carbsGoal: carbsGoal ?? this.carbsGoal,
        fatsGoal: fatsGoal ?? this.fatsGoal,
        foodPreferences: foodPreferences ?? this.foodPreferences,
        allergies: allergies ?? this.allergies,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
