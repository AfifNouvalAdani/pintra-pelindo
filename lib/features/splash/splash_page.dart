import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/logo-pintra.png',
              width: 320,
            ),

            const SizedBox(height: 24),

            // Loading indicator
            CircularProgressIndicator(
              color: Colors.blue.shade700,
            ),

            const SizedBox(height: 16),
            
            Text(
              'Memuat...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}