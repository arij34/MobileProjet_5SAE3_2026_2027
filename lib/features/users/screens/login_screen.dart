import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../services/user_service.dart';

/// Fond avec grand cercle violet clair en haut à gauche (réutilisable).
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Positioned(
          top: -size.width * 0.35,
          left: -size.width * 0.25,
          child: Container(
            width: size.width * 1.1,
            height: size.width * 1.1,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFDCC8FA), Color(0x00FFFFFF)],
              ),
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}

/// Bouton pilule violet aligné à droite.
class PillButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const PillButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.purpleLight,
          foregroundColor: Colors.white,
          minimumSize: const Size(130, 48),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text),
            const SizedBox(width: 10),
            const Icon(Icons.login, size: 20, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true; // true = mot de passe masqué

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _pill(String label, {Widget? prefix, Widget? suffix}) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      suffixIcon: suffix,
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
      final user = await UserService.instance.login(
        _emailController.text,
        _passwordController.text,
      );

      // On mémorise l'utilisateur connecté.
      SessionManager.instance.currentUser = user;

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, s) {
      debugPrint('ERREUR CONNEXION : $e\n$s');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFE),
      body: AuthBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 150),
                  const Text(
                    'Connexion',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text("Pas encore de compte ? ",
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.register),
                        child: const Text("S'inscrire",
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _pill(
                      'Email',
                      prefix: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'L\'email est obligatoire'
                        : null,
                  ),
                  const SizedBox(height: 18),

                  // Mot de passe (avec bouton afficher / masquer)
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _pill(
                      'Mot de passe',
                      prefix: const Icon(Icons.lock_outline),
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Le mot de passe est obligatoire'
                        : null,
                  ),

                  // "Mot de passe oublié ?" sous le champ
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                                            onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.forgotPassword),
                      child: const Text(
                        'Mot de passe oublié ?',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  PillButton(
                    text: _loading ? 'Veuillez patienter...' : 'Connexion',
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}