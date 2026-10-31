import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/app_loader.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Palette MyGym
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);

  // Image affichée au démarrage : changez le numéro si besoin.
  static const _logoPath = 'lib/core/assets/images/image5.png';

  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _loaderFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_violetDark, _violet],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Image animée (zoom + apparition)
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    width: 160,
                    height: 160,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _grayLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: _lilac, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: _pink.withValues(alpha: 0.35),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _logoPath,
                        fit: BoxFit.contain,
                        // Si l'image est introuvable : icône de secours
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.fitness_center,
                          size: 70,
                          color: _violetDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Titre + slogan (glissent vers le haut)
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
                      const Text(
                        'MyGym',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sport · Nutrition · Challenges',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 1,
                          color: _lilac.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Loader personnalisé
              FadeTransition(
                opacity: _loaderFade,
                child: const AppLoader(size: 44, color: _pink),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}