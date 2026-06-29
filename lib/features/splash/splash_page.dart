import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _progressValue;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    // Controller untuk logo muncul (0.6 detik)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Controller untuk progress bar (3 detik penuh)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    );

    // Controller untuk pulse effect pada logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Logo scale: dari 0.7 → 1.0
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // Logo opacity: dari 0 → 1
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Progress bar: dari 0 → 1
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Pulse scale: 1.0 → 1.05 (subtle glow effect)
    _pulseScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Mulai animasi logo, lalu progress bar
    _logoController.forward().then((_) {
      _progressController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Bagian tengah: Logo ──
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo dengan animasi scale + opacity + pulse
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _logoController,
                        _pulseController,
                      ]),
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value * _pulseScale.value,
                            child: child,
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/images/logo-pintra.gif',
                        width: 600,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Teks versi / tagline
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, _) {
                        return Opacity(
                          opacity: _logoOpacity.value,
                          child: Column(
                            children: [
                              Text(
                                'Platform Infrastruktur Terpadu',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Bagian bawah: Progress bar + teks ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) {
                  final progress = _progressValue.value;

                  // Label teks berdasarkan progress
                  String label;
                  if (progress < 0.4) {
                    label = 'Memuat aplikasi...';
                  } else if (progress < 0.75) {
                    label = 'Menyiapkan data...';
                  } else {
                    label = 'Hampir selesai...';
                  }

                  return Column(
                    children: [
                      // Progress bar custom
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade700,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Teks status + persentase
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}