import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/splash/splash_page.dart';
import 'features/auth/login_page.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'features/admin/deep_link_approval_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'features/admin/public_approval_page.dart';
import 'package:intl/date_symbol_data_local.dart'; // ✅ TAMBAHKAN INI

// ✅ CONDITIONAL IMPORT - hanya import dart:html jika di web
import 'web_url_helper_stub.dart'
    if (dart.library.html) 'web_url_helper_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ TAMBAHKAN: Initialize date formatting untuk Indonesia
  await initializeDateFormatting('id_ID', null);
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PintraApp());
}

class PintraApp extends StatefulWidget {
  const PintraApp({super.key});

  @override
  State<PintraApp> createState() => _PintraAppState();
}

class _PintraAppState extends State<PintraApp> {
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initDeepLinks();
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        print('🔗 Initial link detected: $initialLink');
        _handleDeepLink(initialLink.toString());
      }
    } catch (e) {
      print('❌ Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) {
          print('🔗 New link detected: $uri');
          _handleDeepLink(uri.toString());
        }
      },
      onError: (err) {
        print('❌ Error listening to links: $err');
      },
    );
  }

  void _handleDeepLink(String link) {
    try {
      final uri = Uri.parse(link);
      
      print('🔍 Parsing link - host: ${uri.host}, path: ${uri.path}');
      
      if (uri.host == 'approval' && uri.pathSegments.isNotEmpty) {
        final bookingId = uri.pathSegments[0];
        final token = uri.queryParameters['token'];
        
        print('📋 Booking ID: $bookingId');
        print('🔑 Token: $token');
        
        if (token != null && token.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => DeepLinkApprovalHandler(
                  bookingId: bookingId,
                  token: token,
                ),
              ),
            );
          });
        } else {
          print('⚠️ Token tidak ditemukan di link');
        }
      } else {
        print('⚠️ Format link tidak valid');
      }
    } catch (e) {
      print('❌ Error handling deep link: $e');
    }
  }

  // ✅ FUNGSI untuk cek initial web route
  Widget _getInitialPage() {
    if (kIsWeb) {
      try {
        final currentUrl = getCurrentUrl();
        final uri = Uri.parse(currentUrl);
        
        print('🌐 Initial web URL: $currentUrl');
        print('🌐 Path: ${uri.path}');
        print('🌐 Query: ${uri.queryParameters}');
        
        if (uri.path.contains('/approval')) {
          final bookingId = uri.queryParameters['bookingId'];
          final token = uri.queryParameters['token'];
          
          print('📋 Found bookingId: $bookingId');
          print('🔑 Found token: $token');
          
          if (bookingId != null && token != null) {
            return PublicApprovalPage( // ✅ GANTI INI
              bookingId: bookingId,
              token: token,
            );
          }
        }
      } catch (e) {
        print('❌ Error parsing web URL: $e');
      }
    }
    
    return const SplashPage();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PINTRA',
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        fontFamily: 'Poppins',
      ),
      
      home: _getInitialPage(),
      
      onGenerateRoute: (settings) {
        if (kIsWeb && settings.name != null) {
          final uri = Uri.parse(settings.name!);
          
          if (uri.path == '/approval') {
            final bookingId = uri.queryParameters['bookingId'];
            final token = uri.queryParameters['token'];
            
            if (bookingId != null && token != null) {
              return MaterialPageRoute(
                builder: (_) => PublicApprovalPage( // ✅ GANTI INI
                  bookingId: bookingId,
                  token: token,
                ),
                settings: settings,
              );
            }
          }
        }
        
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const SplashPage(),
              settings: settings,
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginPage(),
              settings: settings,
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const SplashPage(),
              settings: settings,
            );
        }
      },
      
      routes: {
        '/login': (context) => const LoginPage(),
      },
    );
  }
}