import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pill_decoration.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/verification_service.dart';
import 'login_screen.dart'; // pour AuthBackground

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController(); // email OU téléphone
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // 0 = saisir l'identifiant, 1 = saisir le code, 2 = nouveau mot de passe
  int _step = 0;
  User? _user;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Étape 1 : trouver le compte et envoyer le code ----------

  Future<void> _sendCode() async {
    final id = _identifierController.text.trim();

    // Si le texte contient "@", c'est un email, sinon un téléphone.
    final isEmail = id.contains('@');
    final user = isEmail
        ? await UserService.instance.getByEmail(id)
        : await UserService.instance.getByPhone(id);

    if (user == null) {
      throw AuthException(
          'Aucun compte ne correspond à cet email ou ce téléphone.');
    }

    final code = VerificationService.instance.generateCode(user.email);

    // SIMULATION de l'envoi. Plus tard, remplacer cette fenêtre par l'appel
    // à l'API qui envoie vraiment l'email ou le SMS.
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEmail ? 'Email reçu (simulation)' : 'SMS reçu (simulation)'),
        content: Text(
          'Votre code de vérification MyGym est :\n\n$code\n\n'
          'Il est valable 10 minutes.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() {
      _user = user;
      _codeController.clear();
      _step = 1;
    });
  }

  // ---------- Étape 2 : vérifier le code ----------

  void _verifyCode() {
    final error =
        VerificationService.instance.verify(_user!.email, _codeController.text);
    if (error != null) {
      _snack(error);
      return;
    }
    setState(() => _step = 2);
  }

  // ---------- Étape 3 : enregistrer le nouveau mot de passe ----------

  Future<void> _resetPassword() async {
    await UserService.instance
        .resetPassword(_user!.email, _passwordController.text);

    if (!mounted) return;
    _snack('Mot de passe modifié. Connectez-vous.');
    Navigator.pop(context); // retour à la connexion
  }

  // ---------- Bouton principal ----------

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      if (_step == 0) {
        await _sendCode();
      } else if (_step == 1) {
        _verifyCode();
      } else {
        await _resetPassword();
      }
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e, s) {
      debugPrint('ERREUR MOT DE PASSE OUBLIÉ : $e\n$s');
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_user == null) return;
    final code = VerificationService.instance.generateCode(_user!.email);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouveau code (simulation)'),
        content: Text(
          'Votre nouveau code de vérification est :\n\n$code',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------- Textes selon l'étape ----------

  String get _description {
    switch (_step) {
      case 0:
        return 'Entrez l\'email ou le téléphone de votre compte. '
            'Nous vous enverrons un code de vérification.';
      case 1:
        return 'Entrez le code à 6 chiffres que vous avez reçu.';
      default:
        return 'Code vérifié. Choisissez votre nouveau mot de passe.';
    }
  }

  String get _buttonLabel {
    if (_loading) return 'Veuillez patienter...';
    switch (_step) {
      case 0:
        return 'Envoyer le code';
      case 1:
        return 'Vérifier';
      default:
        return 'Réinitialiser';
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
                    const SizedBox(height: 150),
                    const Text(
                      'Mot de passe oublié',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _description,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 30),

                    // ----- Étape 1 : identifiant -----
                    if (_step == 0)
                      TextFormField(
                        controller: _identifierController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: pillDecoration('Email ou téléphone',
                            prefix: const Icon(Icons.person_outline)),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ce champ est obligatoire'
                            : null,
                      ),

                    // ----- Étape 2 : code -----
                    if (_step == 1) ...[
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: pillDecoration('Code de vérification',
                            prefix: const Icon(Icons.pin_outlined)),
                        validator: (v) => (v == null || v.trim().length != 6)
                            ? 'Le code contient 6 chiffres'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _resendCode,
                          child: const Text(
                            'Renvoyer le code',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ----- Étape 3 : nouveau mot de passe -----
                    if (_step == 2) ...[
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        decoration: pillDecoration(
                          'Nouveau mot de passe',
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Le mot de passe est obligatoire';
                          }
                          if (v.length < 6) return 'Au moins 6 caractères';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        decoration: pillDecoration('Confirmer le mot de passe',
                            prefix: const Icon(Icons.lock_outline)),
                        validator: (v) => v != _passwordController.text
                            ? 'Les mots de passe ne correspondent pas'
                            : null,
                      ),
                    ],

                    const SizedBox(height: 30),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.purpleLight,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(130, 48),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(_buttonLabel),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
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