import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({
    super.key,
    required this.userId,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Selamat Pagi';
    } else if (hour < 15) {
      return 'Selamat Siang';
    } else if (hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM y', 'id_ID').format(now);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final nama = _userData?['nama']?.toString() ?? '-';
    final divisi = _userData?['divisi']?.toString() ?? '-';
    final nipp = _userData?['nipp']?.toString() ?? '-';
    final noTelp = _userData?['noTelp']?.toString() ?? '-';
    final email = _userData?['email']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header dengan Logo
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/logo-pelindo.webp',
                      height: 32,
                    ),
                  ],
                ),
              ),

              // Back Button + Avatar + Greeting (SATU CONTAINER ABU-ABU)
              Container(
                width: double.infinity,
                color: Colors.grey.shade50,
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Avatar
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange.shade400,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: 70,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Greeting
                    Text(
                      '${_getGreeting()} ${nama.split(' ').first}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Date
                    Text(
                      _getCurrentDate(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Profile Info Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoItem(nama),
                      _buildDivider(),
                      _buildInfoItem(divisi),
                      _buildDivider(),
                      _buildInfoItem(nipp),
                      _buildDivider(),
                      _buildInfoItem(noTelp),
                      _buildDivider(),
                      _buildInfoItem(email),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Version
              Text(
                'Version : 1.1.1.1',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),

              const SizedBox(height: 20),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _showLogoutConfirmation(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade300,
      indent: 40,
      endIndent: 40,
    );
  }

Future<void> _showLogoutConfirmation(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Keluar Akun',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: const Text(
        'Apakah Anda yakin ingin keluar dari akun ini?',
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
          ),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context); // Tutup dialog
            
            // ✅ HANYA SIGNOUT - BIARKAN AuthWrapper HANDLE ROUTING
            await FirebaseAuth.instance.signOut();
            
            // ✅ HAPUS Navigator.pushNamedAndRemoveUntil
            // AuthWrapper akan otomatis detect user = null
            // dan redirect ke LoginPage via StreamBuilder
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
}
}