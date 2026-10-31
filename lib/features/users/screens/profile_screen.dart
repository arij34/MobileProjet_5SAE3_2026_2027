import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pill_decoration.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/xp_card.dart';
import '../models/level_system.dart';
import '../models/profile_completion.dart';
import '../models/user.dart';
import '../models/user_gender.dart';
import '../models/user_goal.dart';
import '../services/avatar_service.dart';
import '../services/user_service.dart';
import '../services/xp_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late User _user;

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _birthController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  DateTime? _birthDate;
  UserGoal? _goal;
  UserGender? _gender;
  bool _saving = false;

  // Ce que ce rôle a le droit de voir (voir permissions.dart)
  bool get _showProgress =>
      Permissions.can(_user, Permission.viewOwnProgress);
  bool get _showSportProfile =>
      Permissions.can(_user, Permission.editSportProfile);

  @override
  void initState() {
    super.initState();
    _user = SessionManager.instance.currentUser!;

    _firstNameController = TextEditingController(text: _user.firstName);
    _lastNameController = TextEditingController(text: _user.lastName);
    _phoneController = TextEditingController(text: _user.phone);

    _birthDate = _user.birthDate;
    _birthController = TextEditingController(
        text: _birthDate == null ? '' : _fmtDate(_birthDate!));
    _heightController = TextEditingController(
        text: _user.heightCm == null ? '' : _fmtNumber(_user.heightCm!));
    _weightController = TextEditingController(
        text: _user.weightKg == null ? '' : _fmtNumber(_user.weightKg!));
    _goal = _user.goal;
    _gender = _user.gender;

    // Rattrape les XP des comptes dont le profil était déjà rempli
    // avant l'existence du système d'XP.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRewards());
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _birthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ---------- Petits outils ----------

  String get _initial =>
      _user.firstName.isEmpty ? '?' : _user.firstName[0].toUpperCase();

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// 170.0 -> "170" ; 72.5 -> "72.5"
  String _fmtNumber(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Texte -> nombre (accepte la virgule). Vide ou invalide -> null.
  double? _parse(String text) {
    final t = text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Utilisateur et XP ----------

  /// Recharge l'utilisateur depuis la base (XP, photo...) et met la session à jour.
  Future<void> _reloadUser() async {
    final fresh = await UserService.instance.getById(_user.id!);
    if (fresh == null) return;
    SessionManager.instance.currentUser = fresh;
    if (mounted) setState(() => _user = fresh);
  }

  /// Donne les XP des étapes de profil (une seule fois chacune).
  /// Les rôles sans progression (administrateur) ne gagnent pas d'XP.
  Future<void> _checkRewards() async {
    if (!_showProgress) return;

    final u = _user;
    final id = u.id!;
    var gained = 0;

    if (u.photoUrl != null && u.photoUrl!.isNotEmpty) {
      gained += await XpService.instance
          .awardOnce(id, 'photo', 10, 'Photo de profil choisie');
    }
    if (u.heightCm != null && u.weightKg != null && u.goal != null) {
      gained += await XpService.instance
          .awardOnce(id, 'sport_profile', 15, 'Profil sportif renseigné');
    }
    if (ProfileCompletion.of(u).percent >= 100) {
      gained += await XpService.instance
          .awardOnce(id, 'profile_complete', 50, 'Profil complété à 100 %');
    }

    if (gained > 0) {
      await _reloadUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _snack('+$gained XP gagnés !');
    }
  }

  // ---------- Photo de profil (API DiceBear) ----------

  Future<void> _chooseAvatar() async {
    final seed = '${_user.firstName}${_user.id}';

    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choisir un avatar',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              const Text('Avatars générés par l\'API DiceBear',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                children: AvatarService.styles.map((style) {
                  final url = AvatarService.urlFor(style, seed);
                  return InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(sheetContext, url),
                    child: Center(
                      child: UserAvatar(
                          photoUrl: url, initial: _initial, radius: 40),
                    ),
                  );
                }).toList(),
              ),
              if (_user.photoUrl != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  // '' = retirer la photo
                  onPressed: () => Navigator.pop(sheetContext, ''),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Retirer la photo',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (choice == null) return; // fenêtre fermée sans choisir
    await _setPhoto(choice.isEmpty ? null : choice);
  }

  Future<void> _setPhoto(String? url) async {
    try {
      await UserService.instance.updatePhoto(_user.id!, url);

      await _reloadUser();
      _snack(url == null ? 'Photo retirée.' : 'Photo mise à jour.');
      await _checkRewards();
    } catch (e, s) {
      debugPrint('ERREUR PHOTO : $e\n$s');
      _snack('Erreur : $e');
    }
  }

  // ---------- Actions ----------

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final first = DateTime(1940);
    final last = DateTime(now.year - 13, now.month, now.day); // 13 ans minimum

    // La date initiale doit rester entre first et last, sinon le sélecteur plante.
    var initial = _birthDate ?? DateTime(now.year - 20);
    if (initial.isAfter(last)) initial = last;
    if (initial.isBefore(first)) initial = first;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthController.text = _fmtDate(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await UserService.instance.updateProfile(
        _user.id!,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        birthDate: _birthDate,
        // Profil sportif : seulement pour les rôles autorisés.
        heightCm: _showSportProfile ? _parse(_heightController.text) : null,
        weightKg: _showSportProfile ? _parse(_weightController.text) : null,
        goal: _showSportProfile ? _goal : null,
        gender: _gender,
      );

      await _reloadUser();
      _snack('Profil mis à jour.');
      await _checkRewards();
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e, s) {
      debugPrint('ERREUR PROFIL : $e\n$s');
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(userId: _user.id!),
    );
    if (ok == true) _snack('Mot de passe modifié.');
  }

  void _logout() {
    SessionManager.instance.logout();
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.login, (route) => false);
  }

  // ---------- Carte "profil complété" ----------

  Widget _buildCompletionCard() {
    final c = ProfileCompletion.of(_user);
    final color = c.percent >= 100
        ? Colors.green
        : (c.percent >= 60 ? AppTheme.purpleLight : Colors.orange);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Profil complété',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${c.percent} %',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: c.percent / 100,
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            c.missing.isEmpty
                ? 'Bravo, votre profil est complet !'
                : 'À compléter : ${c.missing.join(', ')}',
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ---------- Carte niveau / XP ----------

  Widget _buildXpCard() {
    final info = LevelSystem.fromXp(_user.xp);
    return XpCard(
      level: info.level,
      title: info.title,
      totalXp: _user.xp,
      xpInLevel: info.xpInLevel,
      xpForNext: info.xpForNext,
      onTap: () => Navigator.pushNamed(context, AppRoutes.history),
    );
  }

  Widget _sectionTitle(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
        ),
      );

  // ---------- Écran ----------

  @override
  Widget build(BuildContext context) {
    // Sexe et âge (l'âge est calculé à partir de la date de naissance)
    final identity = [
      if (_user.gender != null) _user.gender!.label,
      if (_user.age != null) '${_user.age} ans',
    ].join(' · ');

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFE),
      appBar: AppBar(
        title: const Text('Mon profil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar cliquable (petit crayon en bas à droite)
              GestureDetector(
                onTap: _chooseAvatar,
                child: Stack(
                  children: [
                    UserAvatar(
                      photoUrl: _user.photoUrl,
                      initial: _initial,
                      radius: 46,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.purpleLight),
                        ),
                        child: const Icon(Icons.edit,
                            size: 16, color: AppTheme.purpleLight),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(_user.fullName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(_user.email,
                  style: const TextStyle(color: AppTheme.textSecondary)),
              if (identity.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(identity,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(_user.role.label)),
                  if (_user.coachType != null)
                    Chip(label: Text(_user.coachType!.label)),
                  Chip(label: Text(_user.status.label)),
                ],
              ),
              const SizedBox(height: 16),

              // Profil complété et XP : selon la permission viewOwnProgress
              if (_showProgress) ...[
                _buildCompletionCard(),
                const SizedBox(height: 14),
                _buildXpCard(),
              ],
              const SizedBox(height: 24),

              // ----- Informations personnelles -----
              _sectionTitle('Informations personnelles'),
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: pillDecoration('Prénom'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Le prénom est obligatoire'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: pillDecoration('Nom'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Le nom est obligatoire'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: pillDecoration('Téléphone'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Le numéro de téléphone est obligatoire';
                  }
                  if (!RegExp(r'^[0-9+ ]{8,15}$').hasMatch(v.trim())) {
                    return 'Numéro de téléphone invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<UserGender>(
                initialValue: _gender,
                decoration: pillDecoration('Sexe'),
                items: UserGender.values
                    .map((g) =>
                        DropdownMenuItem(value: g, child: Text(g.label)))
                    .toList(),
                onChanged: (g) => setState(() => _gender = g),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _birthController,
                readOnly: true,
                onTap: _pickBirthDate,
                decoration: pillDecoration(
                  'Date de naissance (facultatif)',
                  suffix: const Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 28),

              // ----- Profil sportif : selon la permission editSportProfile -----
              if (_showSportProfile) ...[
                _sectionTitle('Profil sportif (facultatif)'),
                TextFormField(
                  controller: _heightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: pillDecoration('Taille (cm)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = _parse(v);
                    if (n == null || n < 100 || n > 250) {
                      return 'Taille invalide (100 à 250 cm)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: pillDecoration('Poids (kg)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = _parse(v);
                    if (n == null || n < 30 || n > 300) {
                      return 'Poids invalide (30 à 300 kg)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<UserGoal>(
                  initialValue: _goal,
                  decoration: pillDecoration('Objectif sportif'),
                  items: UserGoal.values
                      .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g.label)))
                      .toList(),
                  onChanged: (g) => setState(() => _goal = g),
                ),
                const SizedBox(height: 28),
              ],

              // ----- Boutons -----
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.purpleLight,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(130, 48),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Changer le mot de passe'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(130, 48),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Se déconnecter',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boîte de dialogue : ancien mot de passe + nouveau mot de passe.
class _ChangePasswordDialog extends StatefulWidget {
  final int userId;
  const _ChangePasswordDialog({required this.userId});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await UserService.instance.changePassword(
        widget.userId,
        _oldController.text,
        _newController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Changer le mot de passe'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _oldController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Ancien mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Champ obligatoire' : null,
              ),
              TextFormField(
                controller: _newController,
                obscureText: _obscure,
                decoration:
                    const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ obligatoire';
                  if (v.length < 6) return 'Au moins 6 caractères';
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'Confirmer'),
                validator: (v) => v != _newController.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_loading ? '...' : 'Valider'),
        ),
      ],
    );
  }
}