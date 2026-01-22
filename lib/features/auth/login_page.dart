import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../dashboard/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nippController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Simpan login info ke SharedPreferences jika rememberMe true
  Future<void> _saveLoginInfo(String nipp, String password) async {
    // TODO: Implementasi SharedPreferences jika diperlukan
    // final prefs = await SharedPreferences.getInstance();
    // if (_rememberMe) {
    //   await prefs.setString('nipp', nipp);
    //   await prefs.setString('password', password);
    //   await prefs.setBool('rememberMe', true);
    // } else {
    //   await prefs.remove('nipp');
    //   await prefs.remove('password');
    //   await prefs.setBool('rememberMe', false);
    // }
  }

  // Load saved login info jika rememberMe true
  Future<void> _loadSavedLoginInfo() async {
    // TODO: Implementasi SharedPreferences jika diperlukan
    // final prefs = await SharedPreferences.getInstance();
    // if (prefs.getBool('rememberMe') ?? false) {
    //   final savedNipp = prefs.getString('nipp');
    //   final savedPassword = prefs.getString('password');
    //   if (savedNipp != null && savedPassword != null) {
    //     _nippController.text = savedNipp;
    //     _passwordController.text = savedPassword;
    //     _rememberMe = true;
    //   }
    // }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedLoginInfo();
  }

  Future<void> loginWithNipp() async {
  setState(() => _isLoading = true);
  
  try {
    final nipp = _nippController.text.trim();
    final password = _passwordController.text.trim();

    // Validasi input
    if (nipp.isEmpty || password.isEmpty) {
      throw 'NIPP dan Password wajib diisi';
    }

    // Simpan login info jika rememberMe dicentang
    await _saveLoginInfo(nipp, password);

    // 1. Cari user berdasarkan NIPP di Firestore
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('nipp', isEqualTo: nipp)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw 'NIPP tidak terdaftar';
    }

    final userDoc = snap.docs.first;
    final userData = userDoc.data();
    final email = userData['email'];
    final role = userData['role'];
    final userId = userDoc.id;
    final userName = userData['nama'] ?? 'User';
    final userDivision = userData['divisi'] ?? ''; // AMBIL DIVISI DI SINI

    // 2. Verifikasi password (password harus sama dengan NIPP)
    if (password != nipp) {
      throw 'Password salah. Password harus sama dengan NIPP';
    }

    // 3. Login dengan Firebase Auth menggunakan email
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (!mounted) return;

    // 4. Navigasi ke DashboardPage dengan SEMUA data yang diperlukan
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardPage(
          role: role,
          userName: userName,
          userId: userId,
          userDivision: userDivision, // PASS DIVISI KE DASHBOARD
        ),
      ),
    );

    // 5. Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Login berhasil! Selamat datang, $userName'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

  } on FirebaseAuthException catch (e) {
    // Handle Firebase Auth errors
    String errorMessage;
    switch (e.code) {
      case 'user-not-found':
        errorMessage = 'Email tidak terdaftar di sistem autentikasi';
        break;
      case 'wrong-password':
        errorMessage = 'Password salah';
        break;
      case 'too-many-requests':
        errorMessage = 'Terlalu banyak percobaan. Coba lagi nanti';
        break;
      default:
        errorMessage = 'Terjadi kesalahan autentikasi: ${e.message}';
    }
    _showErrorSnackbar(errorMessage);
    
  } on FirebaseException catch (e) {
    // Handle Firestore errors
    _showErrorSnackbar('Terjadi kesalahan database: ${e.message}');
    
  } catch (e) {
    // Handle other errors
    _showErrorSnackbar(e.toString());
    
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  // Helper untuk menampilkan error snackbar
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Validasi NIPP format
  bool _isValidNIPP(String nipp) {
    // Cek apakah NIPP hanya berisi angka
    final regex = RegExp(r'^[0-9]+$');
    return regex.hasMatch(nipp);
  }

  // Handler untuk forgot password
  Future<void> _handleForgotPassword() async {
    final nipp = _nippController.text.trim();
    
    if (nipp.isEmpty) {
      _showErrorSnackbar('Silakan masukkan NIPP terlebih dahulu');
      return;
    }

    if (!_isValidNIPP(nipp)) {
      _showErrorSnackbar('Format NIPP tidak valid');
      return;
    }

    try {
      // Cari user berdasarkan NIPP
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('nipp', isEqualTo: nipp)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        throw 'NIPP tidak terdaftar';
      }

      final userData = snap.docs.first.data();
      final email = userData['email'];

      // Kirim password reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      // Tampilkan dialog konfirmasi
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset Password Terkirim'),
          content: Text(
            'Link reset password telah dikirim ke email: $email\n\n'
            'Silakan cek email Anda dan ikuti instruksi untuk reset password.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

    } catch (e) {
      _showErrorSnackbar('Gagal mengirim reset password: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.vertical,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan logo dan help
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        'assets/images/logo-pelindo.webp',
                        height: 32,
                        color: Colors.blue.shade800,
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/faq');
                        },
                        icon: Icon(
                          Icons.help_outline,
                          color: Colors.grey.shade600,
                          size: 24,
                        ),
                        tooltip: 'Bantuan',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Logo aplikasi
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo-pintra.png',
                        width: 320,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Form login
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      // NIPP Field
                      TextFormField(
                        controller: _nippController,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade900,
                        ),
                        decoration: InputDecoration(
                          labelText: 'NIPP',
                          labelStyle: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: Colors.blue.shade700,
                          ),
                          hintText: 'Masukkan NIPP Anda',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.badge_outlined,
                            color: Colors.grey.shade500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.blue.shade700,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          // Validasi real-time: hanya angka
                          if (value.isNotEmpty && !_isValidNIPP(value)) {
                            // Bisa tambahkan visual feedback di sini
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade900,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: Colors.blue.shade700,
                          ),
                          hintText: 'Masukkan password (sama dengan NIPP)',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Colors.grey.shade500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.blue.shade700,
                              width: 2,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade500,
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            loginWithNipp();
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Remember Me & Forgot Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Transform.scale(
                                scale: 0.9,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (v) {
                                    setState(() => _rememberMe = v!);
                                    if (!v!) {
                                      // Jika rememberMe di-uncheck, hapus saved login info
                                      _saveLoginInfo('', '');
                                    }
                                  },
                                  activeColor: Colors.blue.shade700,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ingat saya',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _handleForgotPassword,
                            child: Text(
                              'Lupa password?',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : loginWithNipp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Masuk',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Informasi login
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.shade100,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Password sama dengan NIPP Anda. Untuk pertama kali login, gunakan NIPP sebagai password.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Footer
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Divider(
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sistem Peminjaman Kendaraan Operasional',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '© 2024 PT Pelabuhan Indonesia (Persero)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Versi 1.0.0',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nippController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}