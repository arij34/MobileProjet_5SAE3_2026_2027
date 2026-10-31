import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user_role.dart';
import '../services/user_service.dart';
import 'login_screen.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/utils/password_strength.dart';
import '../../../core/widgets/password_strength_bar.dart';
import '../models/user_gender.dart';

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
  bool _loading = false;
  UserGender? _gender;

  // Le rôle administrateur n'est pas proposé à l'inscription.
  static final List<UserRole> _availableRoles =
      UserRole.values.where((r) => r != UserRole.admin).toList();

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
      );

      if (!mounted) return;

      if (user.isPending) {
        // Responsable, nutritionniste, coach : validation par l'admin.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Compte créé. Il sera actif après validation par l\'administrateur.',
            ),
          ),
        );
        Navigator.pop(context); // retour à la connexion
      } else {
        SessionManager.instance.currentUser = user; // on connecte l'adhérent
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, s) {
      debugPrint('ERREUR INSCRIPTION : $e\n$s');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

                    // Genre
                    DropdownButtonFormField<UserGender>(
                      initialValue: _gender,
                      decoration: _pill('Genre'),
                      items: UserGender.values
                          .map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(g.label),
                              ))
                          .toList(),
                      onChanged: (g) => setState(() {
                        _gender = g;
                      }),
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

                    // Barre de force, juste sous le champ
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

                    if (_role != UserRole.member) ...[
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