import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class WebApprovalPage extends StatefulWidget {
  final String bookingId;
  final String token;
  
  const WebApprovalPage({
    super.key,
    required this.bookingId,
    required this.token,
  });

  @override
  State<WebApprovalPage> createState() => _WebApprovalPageState();
}

class _WebApprovalPageState extends State<WebApprovalPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _vehicleData;
  Map<String, dynamic>? _tokenData;
  User? _currentUser;

  // Controllers untuk login
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showLoginForm = false;

  @override
  void initState() {
    super.initState();
    _initializeApproval();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeApproval() async {
    try {
      setState(() => _isLoading = true);

      // 1. Validasi Token
      final tokenDoc = await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(widget.token)
          .get();

      if (!tokenDoc.exists) {
        setState(() {
          _error = 'Link tidak valid atau sudah kadaluarsa';
          _isLoading = false;
        });
        return;
      }

      _tokenData = tokenDoc.data();
      
      // Cek expiry
      final expiresAt = (_tokenData!['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        setState(() {
          _error = 'Link sudah kadaluarsa (berlaku 24 jam)';
          _isLoading = false;
        });
        return;
      }

      // Cek sudah dipakai
      if (_tokenData!['used'] == true) {
        setState(() {
          _error = 'Link sudah digunakan sebelumnya';
          _isLoading = false;
        });
        return;
      }

      // 2. Cek user login
      _currentUser = FirebaseAuth.instance.currentUser;
      
      if (_currentUser == null) {
        setState(() {
          _showLoginForm = true;
          _isLoading = false;
        });
        return;
      }

      // 3. Validasi user ID
      if (_currentUser!.uid != _tokenData!['userId']) {
        setState(() {
          _error = 'Link ini hanya untuk user yang bersangkutan.\nSilakan login dengan akun yang benar.';
          _showLoginForm = true;
          _isLoading = false;
        });
        return;
      }

      // 4. Load booking data
      await _loadBookingData();

    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookingData() async {
    try {
      // Ambil data booking
      final bookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        setState(() {
          _error = 'Data peminjaman tidak ditemukan';
          _isLoading = false;
        });
        return;
      }

      _bookingData = {
        'id': bookingDoc.id,
        ...bookingDoc.data()!,
      };

      // Ambil data kendaraan
      if (_bookingData!['vehicleId'] != null) {
        final vehicleDoc = await FirebaseFirestore.instance
            .collection('vehicles')
            .doc(_bookingData!['vehicleId'])
            .get();

        if (vehicleDoc.exists) {
          _vehicleData = vehicleDoc.data();
        }
      }

      setState(() => _isLoading = false);

    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Email dan password harus diisi', isError: true);
      return;
    }

    try {
      setState(() => _isProcessing = true);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Reload initialization setelah login
      await _initializeApproval();

    } on FirebaseAuthException catch (e) {
      String message = 'Login gagal';
      if (e.code == 'user-not-found') {
        message = 'Email tidak terdaftar';
      } else if (e.code == 'wrong-password') {
        message = 'Password salah';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid';
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleApprove() async {
    final confirmed = await _showConfirmDialog(
      title: 'Setujui Peminjaman',
      message: 'Apakah Anda yakin ingin menyetujui peminjaman ini?',
      confirmText: 'Setujui',
      isApprove: true,
    );

    if (confirmed != true) return;

    try {
      setState(() => _isProcessing = true);

      // Ambil data user untuk role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (!userDoc.exists) {
        _showSnackBar('Data user tidak ditemukan', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      final userData = userDoc.data()!;
      final role = userData['role'] ?? 'user';
      final userName = userData['nama'] ?? '';
      final userJabatan = userData['jabatan'] ?? '';

      // Tentukan status baru
      String currentStatus = _bookingData!['status'] ?? 'SUBMITTED';
      String newStatus;
      String actionText;

      final isManagerDivisi = userJabatan.toLowerCase().contains('manager');

      if (role == 'user' && isManagerDivisi) {
        if (currentStatus != 'SUBMITTED') {
          _showSnackBar('Hanya dapat menyetujui peminjaman dengan status SUBMITTED', isError: true);
          setState(() => _isProcessing = false);
          return;
        }
        newStatus = 'APPROVAL_1';
        actionText = 'Disetujui Manager Divisi';
      } else if (role == 'operator') {
        if (currentStatus != 'APPROVAL_1') {
          _showSnackBar('Hanya dapat menyetujui peminjaman dengan status APPROVAL_1', isError: true);
          setState(() => _isProcessing = false);
          return;
        }
        newStatus = 'APPROVAL_2';
        actionText = 'Diverifikasi Operator';
      } else if (role == 'admin' || role == 'manager_umum') {
        if (currentStatus != 'APPROVAL_2') {
          _showSnackBar('Hanya dapat menyetujui peminjaman dengan status APPROVAL_2', isError: true);
          setState(() => _isProcessing = false);
          return;
        }
        newStatus = 'APPROVAL_3';
        actionText = 'Disetujui Manager Umum';
      } else {
        _showSnackBar('Role tidak memiliki izin untuk approval', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      // Update booking
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .update({
        'status': newStatus,
        'updatedAt': Timestamp.now(),
        'lastApprovalBy': userName,
        'lastApprovalRole': role,
        'lastApprovalJabatan': userJabatan,
      });

      // Tambahkan ke riwayat
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'APPROVED',
        'oldStatus': currentStatus,
        'newStatus': newStatus,
        'actionBy': userName,
        'actionRole': role,
        'actionJabatan': userJabatan,
        'userId': _currentUser!.uid,
        'timestamp': Timestamp.now(),
        'note': '$actionText oleh $userName',
      });

      // Mark token as used
      await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(widget.token)
          .update({
        'used': true,
        'usedAt': Timestamp.now(),
      });

      // Show success
      setState(() {
        _isProcessing = false;
        _error = null;
      });

      _showSuccessDialog('Peminjaman berhasil disetujui!');

    } catch (e) {
      _showSnackBar('Gagal menyetujui: $e', isError: true);
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.isEmpty) return;

    try {
      setState(() => _isProcessing = true);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      final userData = userDoc.data()!;
      final role = userData['role'] ?? 'user';
      final userName = userData['nama'] ?? '';
      final userJabatan = userData['jabatan'] ?? '';

      // Update booking
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'CANCELLED',
        'rejectionReason': reason,
        'rejectedBy': userName,
        'rejectedRole': role,
        'rejectedJabatan': userJabatan,
        'updatedAt': Timestamp.now(),
      });

      // Tambahkan ke riwayat
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'REJECTED',
        'oldStatus': _bookingData!['status'],
        'newStatus': 'CANCELLED',
        'actionBy': userName,
        'actionRole': role,
        'actionJabatan': userJabatan,
        'userId': _currentUser!.uid,
        'timestamp': Timestamp.now(),
        'note': 'Ditolak oleh $userName ($role)',
        'reason': reason,
      });

      // Mark token as used
      await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(widget.token)
          .update({
        'used': true,
        'usedAt': Timestamp.now(),
      });

      _showSuccessDialog('Peminjaman berhasil ditolak!');

    } catch (e) {
      _showSnackBar('Gagal menolak: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isApprove = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRejectDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Peminjaman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan alasan penolakan:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Contoh: Kendaraan tidak tersedia',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alasan harus diisi')),
                );
                return;
              }
              Navigator.pop(context, controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Halaman ini dapat ditutup',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Reload halaman untuk menampilkan status terbaru
              _initializeApproval();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue.shade700),
              const SizedBox(height: 24),
              Text(
                'Memvalidasi link approval...',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    // Login form
    if (_showLoginForm) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 60, color: Colors.blue.shade700),
                    const SizedBox(height: 16),
                    const Text(
                      'Login untuk Approval',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ?? 'Silakan login dengan akun yang berwenang',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isProcessing,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      enabled: !_isProcessing,
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Login', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Error state
    if (_error != null && _bookingData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main approval page
    final booking = _bookingData!;
    final waktuPinjam = booking['waktuPinjam'] is Timestamp
        ? (booking['waktuPinjam'] as Timestamp).toDate()
        : null;
    final waktuKembali = booking['waktuKembali'] is Timestamp
        ? (booking['waktuKembali'] as Timestamp).toDate()
        : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        title: const Text('Approval Peminjaman Kendaraan'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.directions_car, size: 60, color: Colors.blue.shade700),
                        const SizedBox(height: 12),
                        const Text(
                          'Detail Peminjaman Kendaraan',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Text(
                            'Menunggu Persetujuan',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Detail Booking Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('ID Pemesanan', booking['id']),
                        _buildDetailRow('Nama Peminjam', booking['namaPeminjam'] ?? '-'),
                        _buildDetailRow('Divisi', booking['divisi'] ?? '-'),
                        _buildDetailRow('Kendaraan', 
                          '${_vehicleData?['nama'] ?? booking['vehicle']?['nama'] ?? '-'} (${_vehicleData?['platNomor'] ?? booking['vehicle']?['platNomor'] ?? '-'})'),
                        _buildDetailRow('Tujuan', booking['tujuan'] ?? '-'),
                        _buildDetailRow('Keperluan', booking['keperluan'] ?? '-'),
                        const Divider(height: 24),
                        _buildDetailRow('Waktu Pinjam', 
                          waktuPinjam != null ? _formatTimestamp(Timestamp.fromDate(waktuPinjam)) : '-'),
                        _buildDetailRow('Waktu Kembali', 
                          waktuKembali != null ? _formatTimestamp(Timestamp.fromDate(waktuKembali)) : '-'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleReject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Tolak', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Setujui', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  '⚠️ Link berlaku 24 jam dan hanya dapat digunakan sekali',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}