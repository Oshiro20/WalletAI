import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

/// Clave usada para registrar si el onboarding ya fue completado
const _kOnboardingDone = 'onboarding_completed';

/// Guarda el flag de onboarding completado en SharedPreferences
Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDone, true);
}

/// Lee si el usuario ya completó el onboarding
Future<bool> hasCompletedOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDone) ?? false;
}

// ─── Datos de cada slide ─────────────────────────────────────────────────────

class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final Color glowColor;
  final String title;
  final String subtitle;
  final List<String> bullets;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.glowColor,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });
}

const _pages = [
  _OnboardingPage(
    icon: Icons.wallet_rounded,
    iconColor: AppColors.primarySoft,
    glowColor: AppColors.primary,
    title: 'Tu finanzas,\nbajo control',
    subtitle: 'WalletAI es tu copiloto financiero personal.',
    bullets: [
      'Registra ingresos y gastos en segundos',
      'Organiza por categorías automáticamente',
      'Visualiza tu flujo de dinero en tiempo real',
    ],
  ),
  _OnboardingPage(
    icon: Icons.document_scanner_rounded,
    iconColor: AppColors.incomeDim,
    glowColor: AppColors.income,
    title: 'Escanea tus\nboletas con IA',
    subtitle: 'Toma una foto y olvídate del registro manual.',
    bullets: [
      'OCR inteligente extrae todos los productos',
      'Clasifica categorías automáticamente',
      'Detecta cantidades, precios y tienda',
    ],
  ),
  _OnboardingPage(
    icon: Icons.auto_graph_rounded,
    iconColor: Color(0xFF93C5FD),
    glowColor: AppColors.transfer,
    title: 'Analiza y\nproyecta',
    subtitle: 'Decisiones inteligentes con datos reales.',
    bullets: [
      'Gráficos de gastos por categoría y mes',
      'Planificador de pago de deudas (Avalancha / Bola)',
      'Metas de ahorro con seguimiento visual',
    ],
  ),
  _OnboardingPage(
    icon: Icons.smart_toy_rounded,
    iconColor: AppColors.primarySoft,
    glowColor: AppColors.primaryDim,
    title: 'Asistente IA\nsiempre disponible',
    subtitle: 'Pregunta cualquier cosa sobre tu dinero.',
    bullets: [
      'Consultas en lenguaje natural en español',
      'Consejos personalizados según tus datos',
      'Registra transacciones dictando por voz',
    ],
  ),
];

// ─── Pantalla principal ───────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _iconPulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _iconPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _iconPulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconPulse.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await markOnboardingComplete();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Fondo animado con glow del color de la página actual
          _AnimatedBackground(
            color: _pages[_currentPage].glowColor,
            currentPage: _currentPage,
          ),

          SafeArea(
            child: Column(
              children: [
                // Botón skip
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Omitir',
                      style: GoogleFonts.manrope(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Slides
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      return _OnboardingSlide(
                        page: _pages[index],
                        pulseAnim: _pulseAnim,
                        isActive: index == _currentPage,
                      );
                    },
                  ),
                ),

                // Indicadores de página
                _PageIndicators(
                  count: _pages.length,
                  current: _currentPage,
                  activeColor: _pages[_currentPage].glowColor,
                ),
                const SizedBox(height: 32),

                // Botón de acción
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _ActionButton(
                    isLast: _currentPage == _pages.length - 1,
                    color: _pages[_currentPage].glowColor,
                    onPressed: _nextPage,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slide individual ─────────────────────────────────────────────────────────

class _OnboardingSlide extends StatelessWidget {
  final _OnboardingPage page;
  final Animation<double> pulseAnim;
  final bool isActive;

  const _OnboardingSlide({
    required this.page,
    required this.pulseAnim,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono con efecto glow pulsante
          ScaleTransition(
            scale: pulseAnim,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: page.glowColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: page.glowColor.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
                border: Border.all(
                  color: page.glowColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(page.icon, size: 52, color: page.iconColor),
            ),
          ),
          const SizedBox(height: 40),

          // Título
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              page.title,
              key: ValueKey(page.title),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Subtítulo
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // Bullets
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: page.bullets
                  .map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: page.glowColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: page.iconColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              bullet,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Indicadores ─────────────────────────────────────────────────────────────

class _PageIndicators extends StatelessWidget {
  final int count;
  final int current;
  final Color activeColor;

  const _PageIndicators({
    required this.count,
    required this.current,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : AppColors.outlineVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Botón de acción ─────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final bool isLast;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.isLast,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLast ? 'Comenzar ahora' : 'Siguiente',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLast
                    ? Icons.rocket_launch_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Fondo animado ────────────────────────────────────────────────────────────

class _AnimatedBackground extends StatelessWidget {
  final Color color;
  final int currentPage;

  const _AnimatedBackground({required this.color, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.4),
          radius: 1.0,
          colors: [color.withValues(alpha: 0.08), AppColors.surface],
        ),
      ),
    );
  }
}
