import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/approval_notification_service.dart';

class PublicRoomApprovalPage extends StatefulWidget {
  final String bookingId;
  final String token;

  const PublicRoomApprovalPage({
    super.key,
    required this.bookingId,
    required this.token,
  });

  @override
  State<PublicRoomApprovalPage> createState() => _PublicRoomApprovalPageState();
}

class _PublicRoomApprovalPageState extends State<PublicRoomApprovalPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _tokenData;

  // State setelah proses selesai
  bool _isDone = false;
  bool _doneIsApproved = true;
  String _doneMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeApproval();
  }

  Future<void> _initializeApproval() async {
    try {
      setState(() => _isLoading = true);

      // Validasi token dari Firestore
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

      // Pastikan token ini memang untuk booking ruang (bukan kendaraan)
      final bookingType = _tokenData!['bookingType'] as String?;
      if (bookingType != null && bookingType != 'room') {
        setState(() {
          _error = 'Link ini bukan untuk approval ruang meeting';
          _isLoading = false;
        });
        return;
      }

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
      final bookingDoc = await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        setState(() {
          _error = 'Data peminjaman ruang tidak ditemukan';
          _isLoading = false;
        });
        return;
      }

      _bookingData = {
        'id': bookingDoc.id,
        ...bookingDoc.data()!,
      };

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data: $e';
        _isLoading = false;
      });
    }
  }

  // ─── Handle Approve ───────────────────────────────────────────────────────
  Future<void> _handleApprove() async {
    final confirmed = await _showConfirmDialog(
      title: 'Setujui Peminjaman',
      message: 'Apakah Anda yakin ingin menyetujui peminjaman ruang meeting ini?',
      confirmText: 'Setujui',
      isApprove: true,
    );

    if (confirmed != true) return;

    try {
      setState(() => _isProcessing = true);

      // Reload data booking terbaru dari Firestore
      final latestBookingDoc = await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .get();

      if (!latestBookingDoc.exists) {
        _showSnackBar('Data peminjaman tidak ditemukan', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      final latestBookingData = latestBookingDoc.data()!;
      final latestStatus = latestBookingData['status'] ?? 'SUBMITTED';

      // Ambil data user dari token
      final userId = _tokenData!['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
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

      // Tentukan alur approval berdasarkan role
      // Room: SUBMITTED → APPROVAL_1 (Manager Divisi)
      //               → APPROVAL_2 (Operator Ruang)
      //               → APPROVAL_3 (Manager Umum/Admin) → APPROVED
      String expectedStatus;
      String newStatus;
      String actionText;

      final isManagerDivisi = role == 'user' &&
          userJabatan.toLowerCase().contains('manager');

      if (isManagerDivisi) {
        expectedStatus = 'SUBMITTED';
        newStatus = 'APPROVAL_1';
        actionText = 'Disetujui Manager Divisi';
      } else if (role == 'operator') {
        expectedStatus = 'APPROVAL_1';
        newStatus = 'APPROVAL_2';
        actionText = 'Diverifikasi Operator';
      } else if (role == 'admin' || role == 'manager_umum') {
        expectedStatus = 'APPROVAL_2';
        newStatus = 'APPROVAL_3';
        actionText = 'Disetujui Manager Umum';
      } else {
        _showSnackBar('Role tidak memiliki izin untuk approval ini', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      // Validasi status saat ini
      if (latestStatus != expectedStatus) {
        if (latestStatus == newStatus) {
          _showSnackBar(
            'Peminjaman ini sudah disetujui sebelumnya (Status: ${_getStatusText(latestStatus)})',
            isError: true,
          );
        } else if (['APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'APPROVED']
            .contains(latestStatus)) {
          _showSnackBar(
            'Peminjaman sudah di-approve oleh approver lain (Status: ${_getStatusText(latestStatus)})',
            isError: true,
          );
        } else if (latestStatus == 'CANCELLED' || latestStatus == 'REJECTED') {
          _showSnackBar('Peminjaman ini sudah dibatalkan/ditolak', isError: true);
        } else {
          _showSnackBar(
            'Status peminjaman tidak sesuai. Status saat ini: ${_getStatusText(latestStatus)}',
            isError: true,
          );
        }

        setState(() => _isProcessing = false);

        // Tandai token tidak valid karena status sudah berubah
        await FirebaseFirestore.instance
            .collection('approval_tokens')
            .doc(widget.token)
            .update({
          'used': true,
          'usedAt': Timestamp.now(),
          'invalidReason': 'Status sudah berubah sebelum approval dilakukan',
        });

        return;
      }

      // STEP 1: Kirim notifikasi WA ke approver berikutnya
      try {
        final bookingDataWithId = {
          'id': widget.bookingId,
          ...latestBookingData,
        };

        if (newStatus == 'APPROVAL_1') {
          // Manager Divisi approve → kirim ke Operator
          print('📨 [Room] Mengirim notifikasi WA ke Operator...');
          final success = await ApprovalNotificationService
              .sendRoomApprovalNotificationToOperator(
            bookingId: widget.bookingId,
            bookingData: bookingDataWithId,
          );
          print(success
              ? '✅ [Room] Notifikasi ke Operator berhasil'
              : '❌ [Room] Notifikasi ke Operator gagal');
        } else if (newStatus == 'APPROVAL_2') {
          // Operator approve → kirim ke Manager Umum
          print('📨 [Room] Mengirim notifikasi WA ke Manager Umum...');
          final success = await ApprovalNotificationService
              .sendRoomApprovalNotificationToManagerUmum(
            bookingId: widget.bookingId,
            bookingData: bookingDataWithId,
          );
          print(success
              ? '✅ [Room] Notifikasi ke Manager Umum berhasil'
              : '❌ [Room] Notifikasi ke Manager Umum gagal');
        } else if (newStatus == 'APPROVAL_3') {
          // Manager Umum approve → approval penuh, kirim ke peminjam
          print('📨 [Room] Mengirim notifikasi disetujui ke peminjam...');
          final success = await ApprovalNotificationService
              .sendRoomApprovedNotificationToPeminjam(
            bookingId: widget.bookingId,
            bookingData: bookingDataWithId,
          );
          print(success
              ? '✅ [Room] Notifikasi ke peminjam berhasil'
              : '❌ [Room] Notifikasi ke peminjam gagal');
        }
      } catch (e) {
        print('⚠️ [Room] Error kirim notifikasi WA: $e');
        // Lanjutkan proses approval meski notifikasi gagal
      }

      // STEP 2: Update status Firestore
      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .update({
        'status': newStatus,
        'updatedAt': Timestamp.now(),
        'lastApprovalBy': userName,
        'lastApprovalRole': role,
        'lastApprovalJabatan': userJabatan,
      });

      // STEP 3: Catat approval history
      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'APPROVED',
        'oldStatus': latestStatus,
        'newStatus': newStatus,
        'actionBy': userName,
        'actionRole': role,
        'actionJabatan': userJabatan,
        'userId': userId,
        'timestamp': Timestamp.now(),
        'note': '$actionText oleh $userName',
      });

      // STEP 4: Mark token as used
      await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(widget.token)
          .update({
        'used': true,
        'usedAt': Timestamp.now(),
      });

      _setDoneState(
        isApproved: true,
        message: newStatus == 'APPROVAL_3'
            ? 'Peminjaman ruang meeting telah disetujui penuh!'
            : 'Peminjaman diteruskan ke approver berikutnya.',
      );
    } catch (e) {
      _showSnackBar('Gagal menyetujui: $e', isError: true);
      setState(() => _isProcessing = false);
    }
  }

  // ─── Handle Reject ────────────────────────────────────────────────────────
  Future<void> _handleReject() async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.isEmpty) return;

    try {
      setState(() => _isProcessing = true);

      final userId = _tokenData!['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userData = userDoc.data()!;
      final role = userData['role'] ?? 'user';
      final userName = userData['nama'] ?? '';
      final userJabatan = userData['jabatan'] ?? '';

      final currentStatus = _bookingData!['status'] ?? 'SUBMITTED';

      // Update status ke REJECTED
      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'REJECTED',
        'rejectionReason': reason,
        'rejectedBy': userName,
        'rejectedRole': role,
        'rejectedJabatan': userJabatan,
        'updatedAt': Timestamp.now(),
      });

      // Catat di approval history
      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'REJECTED',
        'oldStatus': currentStatus,
        'newStatus': 'REJECTED',
        'actionBy': userName,
        'actionRole': role,
        'actionJabatan': userJabatan,
        'userId': userId,
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

      // Kirim notifikasi WA penolakan ke peminjam
      print('📨 [Room] Mengirim notifikasi penolakan ke peminjam...');
      await ApprovalNotificationService.sendRoomRejectedNotificationToPeminjam(
        bookingId: widget.bookingId,
        bookingData: _bookingData!,
        rejectedBy: userName,
        reason: reason,
      );

      _setDoneState(
        isApproved: false,
        message: 'Peminjaman ruang meeting berhasil ditolak.',
      );
    } catch (e) {
      _showSnackBar('Gagal menolak: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ─── Dialogs & helpers ────────────────────────────────────────────────────
  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isApprove = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              backgroundColor: isApprove ? Colors.green.shade600 : Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tolak Peminjaman Ruang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan alasan penolakan:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                hintText: 'Contoh: Ruang sudah terpakai di jadwal tersebut',
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
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alasan harus diisi')),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  void _setDoneState({required bool isApproved, required String message}) {
    if (!mounted) return;
    setState(() {
      _isDone = true;
      _doneIsApproved = isApproved;
      _doneMessage = message;
      _isProcessing = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(timestamp.toDate());
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'SUBMITTED':
        return 'Menunggu Manager Divisi';
      case 'APPROVAL_1':
        return 'Menunggu Operator';
      case 'APPROVAL_2':
        return 'Menunggu Manager Umum';
      case 'APPROVAL_3':
        return 'Disetujui Penuh';
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
      case 'CANCELLED':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Colors.orange;
      case 'APPROVAL_1':
        return Colors.blue;
      case 'APPROVAL_2':
        return Colors.purple;
      case 'APPROVAL_3':
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Icons.hourglass_empty_rounded;
      case 'APPROVAL_1':
        return Icons.check_circle_outline_rounded;
      case 'APPROVAL_2':
        return Icons.verified_outlined;
      case 'APPROVAL_3':
      case 'APPROVED':
        return Icons.check_circle_rounded;
      case 'REJECTED':
      case 'CANCELLED':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  // ─── Done Page ────────────────────────────────────────────────────────────
  Widget _buildDonePage() {
    final isApproved = _doneIsApproved;
    final Color primaryColor =
        isApproved ? Colors.green.shade600 : Colors.red.shade600;
    final Color bgColor =
        isApproved ? Colors.green.shade50 : Colors.red.shade50;
    final Color borderColor =
        isApproved ? Colors.green.shade200 : Colors.red.shade200;
    final IconData mainIcon =
        isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final String title =
        isApproved ? 'Peminjaman Disetujui' : 'Peminjaman Ditolak';

    final booking = _bookingData ?? {};
    final peminjam = booking['peminjam'] as Map<String, dynamic>? ?? {};
    final namaRuang = booking['namaRuang'] ??
        (booking['ruang'] as Map<String, dynamic>?)?['namaRuang'] ??
        'Ruang Meeting';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Approval Ruang Meeting',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Ikon utama dengan animasi
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 3),
                  ),
                  child: Icon(mainIcon, size: 56, color: primaryColor),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _doneMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
              ),

              const SizedBox(height: 32),

              // Kartu info booking ringkas
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildDoneRow(
                      Icons.badge_outlined,
                      'ID Peminjaman',
                      (booking['id'] ?? '-').toString().length > 12
                          ? (booking['id'] ?? '-')
                              .toString()
                              .substring(0, 12)
                              .toUpperCase()
                          : (booking['id'] ?? '-').toString().toUpperCase(),
                    ),
                    const SizedBox(height: 12),
                    _buildDoneRow(
                      Icons.person_outline_rounded,
                      'Peminjam',
                      peminjam['nama'] ??
                          booking['namaPeminjam'] ??
                          '-',
                    ),
                    const SizedBox(height: 12),
                    _buildDoneRow(
                      Icons.meeting_room_outlined,
                      'Ruang',
                      namaRuang,
                    ),
                    const SizedBox(height: 12),
                    _buildDoneRow(
                      Icons.event_note_outlined,
                      'Kegiatan',
                      booking['namaKegiatan'] ?? '-',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Badge link sekali pakai
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Link ini sudah tidak dapat digunakan kembali',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoneRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isDone) return _buildDonePage();

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Approval Ruang Meeting',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue.shade700),
              const SizedBox(height: 24),
              Text(
                'Memvalidasi link approval...',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Approval Ruang Meeting',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 60, color: Colors.red.shade400),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final booking = _bookingData!;
    final status = booking['status'] ?? 'SUBMITTED';
    final peminjam = booking['peminjam'] as Map<String, dynamic>? ?? {};

    final namaRuang = booking['namaRuang'] ??
        (booking['ruang'] as Map<String, dynamic>?)?['namaRuang'] ??
        'Ruang Meeting';
    final lokasiRuang = booking['lokasiRuang'] ??
        (booking['ruang'] as Map<String, dynamic>?)?['lokasi'] ??
        '-';

    final waktuMulai = booking['waktuMulai'] is Timestamp
        ? (booking['waktuMulai'] as Timestamp).toDate()
        : null;
    final waktuSelesai = booking['waktuSelesai'] is Timestamp
        ? (booking['waktuSelesai'] as Timestamp).toDate()
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Approval Ruang Meeting',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getStatusIcon(status),
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusText(status),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(status),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Menunggu persetujuan Anda',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Detail Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade100,
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.meeting_room_outlined,
                              color: Colors.blue.shade700, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Detail Peminjaman Ruang',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Info peminjam
                    _buildDetailItem('ID Peminjaman', booking['id'] ?? '-'),
                    _buildDetailItem(
                      'Nama Peminjam',
                      peminjam['nama'] ?? booking['namaPeminjam'] ?? '-',
                    ),
                    _buildDetailItem(
                      'Divisi',
                      peminjam['divisi'] ?? booking['divisi'] ?? '-',
                    ),
                    _buildDetailItem(
                      'Jabatan',
                      peminjam['jabatan'] ?? '-',
                    ),

                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 8),

                    // Info ruang
                    _buildDetailItem('Ruang', namaRuang),
                    _buildDetailItem('Lokasi', lokasiRuang),
                    _buildDetailItem(
                        'Kegiatan', booking['namaKegiatan'] ?? '-'),
                    _buildDetailItem(
                        'Jenis Rapat', booking['jenisRapat'] ?? '-'),
                    _buildDetailItem(
                      'Jumlah Peserta',
                      '${booking['peserta'] ?? '-'} orang',
                    ),
                    // Konsumsi
                    _buildDetailItem(
                        'Konsumsi',
                        (booking['konsumsi'] as List?)?.isNotEmpty == true
                            ? (booking['konsumsi'] as List).join(', ')
                            : 'Tidak ada',
                    ),

                    // Catatan Konsumsi (hanya tampil kalau ada isinya)
                    if ((booking['konsumsiNote'] ?? '').toString().isNotEmpty)
                      _buildDetailItem(
                          'Catatan Konsumsi',
                          booking['konsumsiNote'].toString(),
                      ),

                    // Layout Ruangan
                    _buildDetailItem(
                        'Layout Ruangan',
                        (booking['layoutRuangan'] ?? '').toString().isNotEmpty
                            ? booking['layoutRuangan'].toString()
                            : 'Tidak ada catatan',
                    ),


                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 16),

                    // Jadwal
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mulai',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                waktuMulai != null
                                    ? DateFormat('dd MMMM yyyy', 'id_ID')
                                        .format(waktuMulai)
                                    : '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                waktuMulai != null
                                    ? DateFormat('HH:mm', 'id_ID')
                                        .format(waktuMulai)
                                    : '-',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_rounded,
                              color: Colors.grey.shade600, size: 20),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Selesai',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                waktuSelesai != null
                                    ? DateFormat('dd MMMM yyyy', 'id_ID')
                                        .format(waktuSelesai)
                                    : '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                waktuSelesai != null
                                    ? DateFormat('HH:mm', 'id_ID')
                                        .format(waktuSelesai)
                                    : '-',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (booking['createdAt'] != null) ...[
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Text(
                        'Diajukan pada: ${_formatTimestamp(booking['createdAt'])}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Tombol Aksi
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _handleReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(
                            color: Colors.red.shade700, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isProcessing
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.red.shade700, strokeWidth: 2),
                            )
                          : const Text(
                              'Tolak',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Setujui',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '⚠️ Link berlaku 24 jam dan hanya dapat digunakan sekali',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}