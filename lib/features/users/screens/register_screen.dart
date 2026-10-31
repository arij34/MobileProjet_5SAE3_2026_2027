import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/password_strength.dart';
import '../../../core/widgets/password_strength_bar.dart';
import '../models/user_gender.dart';
import '../models/user_role.dart';
import '../services/proof_service.dart';
import '../services/user_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _role = UserRole.member;
  CoachType? _coachType;
  UserGender? _gender;
  String? _proofPath;
  bool _loading = false;

  // Le rôle administrateur n'est pas proposé à l'inscription.
  static final List<UserRole> _availableRoles =
      UserRole.values.where((r) => r != UserRole.admin).toList();

  bool get _needsProof => UserService.roleNeedsProof(_role);

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _pill(String label) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.7),
      border: b(const Color(0xFFBDB6C8)),
      enabledBorder: b(const Color(0xFFBDB6C8)),
      focusedBorder: b(AppTheme.purpleLight, 1.8),
      errorBorder: b(Colors.red),
      focusedErrorBorder: b(Colors.red, 1.8),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Justificatif ----------

  Future<void> _chooseProof() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final path = await ProofService.instance.pick(source);
      if (path == null) return; // annulé
      // On supprime l'ancienne image si elle est remplacée.
      await ProofService.instance.delete(_proofPath);
      if (!mounted) return;
      setState(() => _proofPath = path);
    } catch (e, s) {
      debugPrint('ERREUR JUSTIFICATIF : $e\n$s');
      _snack('Impossible de récupérer l\'image : $e');
    }
  }

  Widget _buildProofField() {
    return FormField<String>(
      validator: (_) => (_needsProof && _proofPath == null)
          ? 'Le justificatif est obligatoire'
          : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Justificatif professionnel',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Photo de votre diplôme ou de votre carte professionnelle. '
            'Elle sera examinée par l\'administrateur.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              await _chooseProof();
              state.didChange(_proofPath);
            },
            child: Container(
              width: double.infinity,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: state.hasError
                      ? Colors.red
                      : const Color(0xFFBDB6C8),
                ),
              ),
              child: _proofPath == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file,
                            size: 40, color: AppTheme.purpleLight),
                        SizedBox(height: 8),
                        Text('Ajouter le justificatif',
                            style:
                                TextStyle(color: AppTheme.textSecondary)),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Image.file(
                            File(_proofPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.edit,
                                size: 16, color: AppTheme.purpleLight),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 14),
              child: Text(
                state.errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Envoi ----------

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = await UserService.instance.register(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phone: _phoneController.text,
        role: _role,
        coachType: _coachType,
        gender: _gender,
        proofPath: _needsProof ? _proofPath : null,
      );

      if (!mounted) return;

      if (user.isPending) {
        // Responsable, nutritionniste, coach : validation par l'admin.
        _snack(
          'Compte créé. Il sera actif après validation par l\'administrateur.',
        );
        Navigator.pop(context); // retour à la connexion
      } else {
        SessionManager.instance.currentUser = user; // on connecte l'adhérent
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e, s) {
      debugPrint('ERREUR INSCRIPTION : $e\n$s');
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Écran ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFE),
      body: AuthBackground(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 200),
                    const Text(
                      'Créer un compte',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Déjà un compte ? ',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('Se connecter',
                              style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Prénom
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _pill('Prénom'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Le prénom est obligatoire'
                          : null,
                    ),
                    const SizedBox(height: 18),

                    // Nom
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _pill('Nom'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Le nom est obligatoire'
                          : null,
                    ),
                    const SizedBox(height: 18),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _pill('Email'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'L\'email est obligatoire';
                        }
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(v.trim());
                        return ok ? null : 'Email invalide';
                      },
                    ),
                    const SizedBox(height: 18),

                    // Téléphone (obligatoire)
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _pill('Téléphone'),
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

                    // Sexe
                    DropdownButtonFormField<UserGender>(
                      initialValue: _gender,
                      decoration: _pill('Sexe'),
                      items: UserGender.values
                          .map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(g.label),
                              ))
                          .toList(),
                      onChanged: (g) => setState(() => _gender = g),
                      validator: (g) =>
                          g == null ? 'Veuillez choisir votre sexe' : null,
                    ),
                    const SizedBox(height: 18),

                    // Mot de passe
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: _pill('Mot de passe'),
                      onChanged: (_) => setState(() {}), // met à jour la barre
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Le mot de passe est obligatoire';
                        }
                        if (PasswordStrength.evaluate(v).score < 3) {
                          return 'Mot de passe trop faible';
                        }
                        return null;
                      },
                    ),
                    PasswordStrengthBar(password: _passwordController.text),
                    const SizedBox(height: 18),

                    // Rôle
                    DropdownButtonFormField<UserRole>(
                      initialValue: _role,
                      decoration: _pill('Je suis'),
                      items: _availableRoles
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.label),
                              ))
                          .toList(),
                      onChanged: (r) => setState(() {
                        _role = r ?? UserRole.member;
                        if (_role != UserRole.coach) _coachType = null;
                      }),
                    ),

                    // Type de coach (seulement si rôle = coach)
                    if (_role == UserRole.coach) ...[
                      const SizedBox(height: 18),
                      DropdownButtonFormField<CoachType>(
                        initialValue: _coachType,
                        decoration: _pill('Type de coach'),
                        items: CoachType.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.label),
                                ))
                            .toList(),
                        onChanged: (t) => setState(() => _coachType = t),
                        validator: (t) =>
                            t == null ? 'Choisissez un type de coach' : null,
                      ),
                    ],

                    // Justificatif (rôles professionnels)
                    if (_needsProof) ...[
                      const SizedBox(height: 22),
                      _buildProofField(),
                      const SizedBox(height: 12),
                      const Text(
                        'Ce type de compte doit être validé par l\'administrateur avant la première connexion.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 30),
                    PillButton(
                      text: _loading ? 'Veuillez patienter...' : "S'inscrire",
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            // Bouton retour en haut à gauche
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}