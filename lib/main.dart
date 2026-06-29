import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'firebase_options.dart';
import 'features/splash/splash_page.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/dashboard_page.dart'; 
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'features/admin/deep_link_approval_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'features/admin/public_approval_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/services/auto_cancel_service.dart';
import 'features/admin/public_cancellation_approval_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/ruang_meeting/room_display_page.dart';
import 'features/ruang_meeting/public_room_approval_page.dart';
import 'features/ruang_meeting/public_room_cancellation_approval_page.dart';
import 'features/gym/public_gym_approval_page.dart';
import 'web_url_helper_stub.dart'

    if (dart.library.html) 'web_url_helper_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('id_ID', null);
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  AutoCancelService.checkAndCancelExpiredBookings();

  AutoCancelService.checkAndSendReturnReminders();
  
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

Widget _getInitialPage() {
  if (kIsWeb) {
    try {
      final currentUrl = getCurrentUrl();
      final uri = Uri.parse(currentUrl);

      if (uri.path.contains('/room-cancellation-approval')) {
        final bookingId = uri.queryParameters['bookingId'];
        final token = uri.queryParameters['token'];
        final requestedBy = Uri.decodeComponent(uri.queryParameters['requestedBy'] ?? '');
        final reason = Uri.decodeComponent(uri.queryParameters['reason'] ?? '');

        if (bookingId != null && token != null) {
          return PublicRoomCancellationApprovalPage(
            bookingId: bookingId,
            token: token,
            requestedBy: requestedBy,
            reason: reason,
          );
        }
      }

      if (uri.path == '/display') {
        return const RoomDisplayPage();
      } else if (uri.path.contains('/room-cancellation-approval')) {
        final bookingId = uri.queryParameters['bookingId'];
        final token = uri.queryParameters['token'];
        final requestedBy = Uri.decodeComponent(uri.queryParameters['requestedBy'] ?? '');
        final reason = Uri.decodeComponent(uri.queryParameters['reason'] ?? '');
        if (bookingId != null && token != null) {
          return PublicRoomCancellationApprovalPage(
            bookingId: bookingId, token: token,
            requestedBy: requestedBy, reason: reason,
          );
        }
      } else if (uri.path.contains('/cancellation-approval')) {
        final bookingId = uri.queryParameters['bookingId'];
        final token = uri.queryParameters['token'];
        final requestedBy = Uri.decodeComponent(uri.queryParameters['requestedBy'] ?? '');
        final reason = Uri.decodeComponent(uri.queryParameters['reason'] ?? '');
        if (bookingId != null && token != null) {
          return PublicCancellationApprovalPage(
            bookingId: bookingId, token: token,
            requestedBy: requestedBy, reason: reason,
          );
        }
      } else if (uri.path.contains('/gym-approval')) {
        final bookingId = uri.queryParameters['bookingId'];
        final token = uri.queryParameters['token'];
        if (bookingId != null && token != null) {
          return PublicGymApprovalPage(bookingId: bookingId, token: token);
        }
      } else if (uri.path.contains('/room-approval')) {
        final bookingId = uri.queryParameters['bookingId'];
        final token = uri.queryParameters['token'];
        if (bookingId != null && token != null) {
          return PublicRoomApprovalPage(bookingId: bookingId, token: token);
        }
      } else if (uri.path.contains('/approval')) {
        final bookingId = uri.queryParameters['bookingId'];
        final token = uri.queryParameters['token'];
        if (bookingId != null && token != null) {
          return PublicApprovalPage(bookingId: bookingId, token: token);
        }
      }
    } catch (e) {
      print('❌ Error parsing web URL: $e');
    }
  }

  return const AuthWrapper();
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
        localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        fontFamily: 'Poppins',
      ),
      
      home: _getInitialPage(),
      
      onGenerateRoute: (settings) {
        if (kIsWeb && settings.name != null) {
          final uri = Uri.parse(settings.name!);
          
            if (uri.path == '/display') {
            return MaterialPageRoute(
              builder: (_) => const RoomDisplayPage(),
              settings: settings,
            );
          }

          if (uri.path == '/room-approval') {
            final bookingId = uri.queryParameters['bookingId'];
            final token = uri.queryParameters['token'];

            if (bookingId != null && token != null) {
              return MaterialPageRoute(
                builder: (_) => PublicRoomApprovalPage(
                  bookingId: bookingId,
                  token: token,
                ),
                settings: settings,
              );
            }
          }

          if (uri.path == '/approval') {
            final bookingId = uri.queryParameters['bookingId'];
            final token = uri.queryParameters['token'];
            
            if (bookingId != null && token != null) {
              return MaterialPageRoute(
                builder: (_) => PublicApprovalPage(
                  bookingId: bookingId,
                  token: token,
                ),
                settings: settings,
              );
            }
          }

          if (uri.path == '/room-cancellation-approval') {
            final bookingId = uri.queryParameters['bookingId'];
            final token = uri.queryParameters['token'];
            final requestedBy = Uri.decodeComponent(uri.queryParameters['requestedBy'] ?? '');
            final reason = Uri.decodeComponent(uri.queryParameters['reason'] ?? '');

            if (bookingId != null && token != null) {
              return MaterialPageRoute(
                builder: (_) => PublicRoomCancellationApprovalPage(
                  bookingId: bookingId,
                  token: token,
                  requestedBy: requestedBy,
                  reason: reason,
                ),
                settings: settings,
              );
            }
          }
          if (uri.path == '/gym-approval') {
            final bookingId = uri.queryParameters['bookingId'];
            final token = uri.queryParameters['token'];
            if (bookingId != null && token != null) {
              return MaterialPageRoute(
                builder: (_) => PublicGymApprovalPage(bookingId: bookingId, token: token),
                settings: settings,
              );
            }
          }

        }
        
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const AuthWrapper(),
              settings: settings,
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginPage(),
              settings: settings,
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const AuthWrapper(),
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Tampilkan splash selama 1 detik
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan splash dulu
    if (_showSplash) {
      return const SplashPage();
    }

    // Setelah splash, cek auth
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Masih loading auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPage();
        }

        // Jika user sudah login
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              // Loading user data
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashPage();
              }

              // Jika data user tidak ada
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                FirebaseAuth.instance.signOut();
                return const LoginPage();
              }

              // Ambil data user
              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
              final role = userData['role'] ?? 'user';
              final userName = userData['nama'] ?? 'User';
              final userId = snapshot.data!.uid;
              final userDivision = userData['divisi'] ?? '';

              // Ke Dashboard
              return DashboardPage(
                role: role,
                userName: userName,
                userId: userId,
                userDivision: userDivision,
              );
            },
          );
        }

        // ✅ PENTING: Jika user belum login, ke LoginPage (BUKAN SplashPage)
        return const LoginPage();
      },
    );
  }
}