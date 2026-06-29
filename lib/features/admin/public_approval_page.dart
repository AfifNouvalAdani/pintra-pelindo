import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/approval_notification_service.dart';
import '../services/auto_cancel_service.dart';

class PublicApprovalPage extends StatefulWidget {
  final String bookingId;
  final String token;
  
  const PublicApprovalPage({
    super.key,
    required this.bookingId,
    required this.token,
  });

  @override
  State<PublicApprovalPage> createState() => _PublicApprovalPageState();
}

class _PublicApprovalPageState extends State<PublicApprovalPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _vehicleData;
  Map<String, dynamic>? _tokenData;

  // State setelah proses selesai
  bool _isDone = false;
  bool _doneIsApproved = true; // true = disetujui, false = ditolak
  String _doneMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeApproval();
  }

  Future<void> _initializeApproval() async {
    try {
      setState(() => _isLoading = true);

      await AutoCancelService.checkAndCancelSingleBooking(widget.bookingId);

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

  // ─── Cek konflik kendaraan (khusus operator → APPROVAL_2) ────────────────
  /// Mengembalikan nama peminjam yang konflik, atau null jika tidak ada konflik.
  Future<String?> _checkVehicleConflict({
    required String vehicleId,
    required DateTime waktuPinjam,
    required DateTime waktuKembali,
  }) async {
    final conflictSnapshot = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: ['APPROVAL_2', 'APPROVAL_3', 'ON_GOING'])
        .get();

    for (final doc in conflictSnapshot.docs) {
      // Lewati booking ini sendiri
      if (doc.id == widget.bookingId) continue;

      final data = doc.data();
      final dynamic otherRawStart = data['waktuPinjam'];
      final dynamic otherRawEnd   = data['waktuKembali'];

      if (otherRawStart == null || otherRawEnd == null) continue;

      final DateTime otherStart = otherRawStart is Timestamp
          ? otherRawStart.toDate()
          : otherRawStart as DateTime;
      final DateTime otherEnd = otherRawEnd is Timestamp
          ? otherRawEnd.toDate()
          : otherRawEnd as DateTime;

      // Overlap: A bentrok B jika A.start < B.end && A.end > B.start
      if (waktuPinjam.isBefore(otherEnd) && waktuKembali.isAfter(otherStart)) {
        return data['namaPeminjam'] ?? doc.id;
      }
    }
    return null; // tidak ada konflik
  }

  // ─── Dialog: kendaraan sudah digunakan (untuk Operator via WA) ───────────
  Future<void> _showVehicleConflictDialog({
    required String vehicleName,
    required String platNomor,
    required String? konflikDengan,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_car_outlined,
                  color: Colors.red.shade700, size: 22),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Kendaraan Tidak Tersedia',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info kendaraan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$vehicleName ($platNomor) sudah '
                          'disetujui untuk peminjaman lain'
                          '${konflikDengan != null ? ' atas nama $konflikDengan' : ''} '
                          'pada waktu yang bersamaan.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Penjelasan tindakan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Untuk mengganti kendaraan, approval harus dilakukan '
                          'melalui aplikasi:\n\n'
                          '1. Buka aplikasi dan masuk ke menu Approval Kendaraan\n'
                          '2. Pilih peminjaman ini\n'
                          '3. Tekan tombol "Edit Kendaraan" untuk memilih kendaraan lain\n'
                          '4. Setelah kendaraan diganti, lanjutkan proses approval',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Anda masih dapat menolak peminjaman ini menggunakan tombol di bawah.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          // Hanya tombol Tutup & Tolak — tidak ada tombol Setujui
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Langsung buka dialog tolak
              _handleReject();
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Tolak Peminjaman'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Handle Approve ───────────────────────────────────────────────────────
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

      // VALIDASI 1: Reload data booking terbaru dari Firestore
      final latestBookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .get();

      if (!latestBookingDoc.exists) {
        _showSnackBar('Data peminjaman tidak ditemukan', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      final latestBookingData = latestBookingDoc.data()!;
      final latestStatus = latestBookingData['status'] ?? 'SUBMITTED';

      // Ambil user data dari token
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

      String expectedStatus;
      String newStatus;
      String actionText;

      final isManagerDivisi = userJabatan.toLowerCase().contains('manager');

      if (role == 'user' && isManagerDivisi) {
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
        _showSnackBar('Role tidak memiliki izin untuk approval', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      if (latestStatus != expectedStatus) {
        if (latestStatus == newStatus) {
          _showSnackBar(
            'Peminjaman ini sudah disetujui sebelumnya (Status: ${_getStatusText(latestStatus)})',
            isError: true,
          );
        } else if (['APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'ON_GOING', 'DONE']
            .contains(latestStatus)) {
          _showSnackBar(
            'Peminjaman sudah di-approve oleh approver lain (Status: ${_getStatusText(latestStatus)})',
            isError: true,
          );
        } else if (latestStatus == 'CANCELLED') {
          _showSnackBar('Peminjaman ini sudah dibatalkan sebelumnya', isError: true);
        } else {
          _showSnackBar(
            'Status peminjaman tidak sesuai. Status saat ini: ${_getStatusText(latestStatus)}',
            isError: true,
          );
        }

        setState(() => _isProcessing = false);

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

      // ─── PENGECEKAN KONFLIK KENDARAAN (khusus Operator → APPROVAL_2) ────
      if (role == 'operator') {
        final vehicleId = latestBookingData['vehicleId'] as String?;

        // Kendaraan belum dipilih
        if (vehicleId == null || vehicleId.isEmpty) {
          setState(() => _isProcessing = false);
          await _showNoVehicleDialog();
          return;
        }

        final dynamic rawWaktuPinjam  = latestBookingData['waktuPinjam'];
        final dynamic rawWaktuKembali = latestBookingData['waktuKembali'];

        if (rawWaktuPinjam == null || rawWaktuKembali == null) {
          _showSnackBar('Data waktu peminjaman tidak valid, hubungi admin',
              isError: true);
          setState(() => _isProcessing = false);
          return;
        }

        final DateTime waktuPinjam = rawWaktuPinjam is Timestamp
            ? rawWaktuPinjam.toDate()
            : rawWaktuPinjam as DateTime;
        final DateTime waktuKembali = rawWaktuKembali is Timestamp
            ? rawWaktuKembali.toDate()
            : rawWaktuKembali as DateTime;

        print('🔍 [PublicApproval] Cek konflik vehicleId: $vehicleId');
        print('🕐 Waktu: $waktuPinjam — $waktuKembali');

        final konflikDengan = await _checkVehicleConflict(
          vehicleId: vehicleId,
          waktuPinjam: waktuPinjam,
          waktuKembali: waktuKembali,
        );

        if (konflikDengan != null) {
          print('❌ Konflik dengan: $konflikDengan');
          setState(() => _isProcessing = false);

          // Tandai token tetap belum dipakai agar operator bisa tolak nanti,
          // tapi jangan proses approve
          await _showVehicleConflictDialog(
            vehicleName: _vehicleData?['nama'] ??
                (latestBookingData['vehicle'] as Map<String, dynamic>?)?['nama'] ??
                'Kendaraan',
            platNomor: _vehicleData?['platNomor'] ??
                (latestBookingData['vehicle'] as Map<String, dynamic>?)?['platNomor'] ??
                '-',
            konflikDengan: konflikDengan,
          );
          return;
        }

        print('✅ Tidak ada konflik, lanjut approve');
      }
      // ─────────────────────────────────────────────────────────────────────

      // STEP 1: Kirim notifikasi WA ke approver berikutnya
      try {
        if (newStatus == 'APPROVAL_1') {
          print('📨 Mengirim notifikasi WA ke Operator...');
          final success = await ApprovalNotificationService
              .sendApprovalNotificationToOperator(
            bookingId: widget.bookingId,
            bookingData: latestBookingData,
          );
          print(success
              ? '✅ Notifikasi WA berhasil dikirim ke Operator'
              : '❌ Gagal');
        } else if (newStatus == 'APPROVAL_2') {
          print('📨 Mengirim notifikasi WA ke Manager Umum...');
          final success = await ApprovalNotificationService
              .sendApprovalNotificationToManagerUmum(
            bookingId: widget.bookingId,
            bookingData: latestBookingData,
          );
          print(success
              ? '✅ Notifikasi WA berhasil dikirim ke Manager Umum'
              : '❌ Gagal');
        } else if (newStatus == 'APPROVAL_3') {
          print('📨 Mengirim notifikasi WA approval penuh ke peminjam...');
          final success = await ApprovalNotificationService
              .sendApprovedNotificationToPeminjam(
            bookingId: widget.bookingId,
            bookingData: latestBookingData,
          );
          print(success
              ? '✅ Notifikasi WA berhasil dikirim ke peminjam'
              : '❌ Gagal');
        }
      } catch (e) {
        print('⚠️ Error notifikasi WA: $e');
      }

      // STEP 2: Update status Firestore
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

      // STEP 3: Catat approval history
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
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

      // STEP 5: Update UI
      setState(() {
        _isProcessing = false;
        _error = null;
      });

      _setDoneState(isApproved: true, message: 'Peminjaman berhasil disetujui!');

    } catch (e) {
      _showSnackBar('Gagal menyetujui: $e', isError: true);
      setState(() => _isProcessing = false);
    }
  }

  // ─── Dialog: kendaraan belum dipilih ─────────────────────────────────────
  Future<void> _showNoVehicleDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_car_outlined,
                  color: Colors.orange.shade700, size: 22),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Kendaraan Belum Dipilih',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Peminjaman ini belum memiliki kendaraan yang dialokasikan.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Silakan buka aplikasi, masuk ke menu Approval Kendaraan, '
                      'dan pilih kendaraan menggunakan tombol "Edit Kendaraan" '
                      'sebelum melakukan approval.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
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
        'userId': userId,
        'timestamp': Timestamp.now(),
        'note': 'Ditolak oleh $userName ($role)',
        'reason': reason,
      });

      await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(widget.token)
          .update({
        'used': true,
        'usedAt': Timestamp.now(),
      });

      print('📨 Mengirim notifikasi WA penolakan ke peminjam...');
      await ApprovalNotificationService.sendRejectedNotificationToPeminjam(
        bookingId: widget.bookingId,
        bookingData: _bookingData!,
        rejectedBy: userName,
        reason: reason,
      );

      _setDoneState(isApproved: false, message: 'Peminjaman berhasil ditolak!');

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

  String _getStatusText(String status) {
    switch (status) {
      case 'SUBMITTED':
        return 'Menunggu Manager Divisi';
      case 'APPROVAL_1':
        return 'Menunggu Operator';
      case 'APPROVAL_2':
        return 'Menunggu Manager Umum';
      case 'APPROVAL_3':
        return 'Disetujui';
      case 'ON_GOING':
        return 'Sedang Digunakan';
      case 'DONE':
        return 'Selesai';
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
        return Colors.green;
      case 'ON_GOING':
        return Colors.green.shade800;
      case 'DONE':
        return Colors.grey;
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
        return Icons.thumb_up_alt_outlined;
      case 'ON_GOING':
        return Icons.directions_car;
      case 'DONE':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.info_outline_rounded;
    }
  }

  // ─── Halaman selesai (menggantikan seluruh UI setelah approve/reject) ─────
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

    // Info booking ringkas
    final booking = _bookingData ?? {};
    final vehicleName = _vehicleData?['nama'] ??
        (booking['vehicle'] as Map<String, dynamic>?)?['nama'] ??
        '-';
    final platNomor = _vehicleData?['platNomor'] ??
        (booking['vehicle'] as Map<String, dynamic>?)?['platNomor'] ??
        '-';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Approval Peminjaman',
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

              // ── Ikon utama ──
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
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

              // ── Judul ──
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),

              const SizedBox(height: 8),

              // ── Sub-teks ──
              Text(
                _doneMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
              ),

              const SizedBox(height: 32),

              // ── Kartu info booking ──
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
                    _buildDoneRow(Icons.badge_outlined, 'ID Peminjaman',
                        (booking['id'] ?? '-').toString().length > 12
                            ? (booking['id'] ?? '-').toString().substring(0, 12).toUpperCase()
                            : (booking['id'] ?? '-').toString().toUpperCase()),
                    const SizedBox(height: 12),
                    _buildDoneRow(Icons.person_outline_rounded, 'Peminjam',
                        booking['namaPeminjam'] ?? '-'),
                    const SizedBox(height: 12),
                    _buildDoneRow(Icons.directions_car_outlined, 'Kendaraan',
                        '$vehicleName ($platNomor)'),
                    const SizedBox(height: 12),
                    _buildDoneRow(Icons.location_on_outlined, 'Tujuan',
                        booking['tujuan'] ?? '-'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Badge "Link sekali pakai" ──
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
    // Tampilkan halaman selesai setelah approve/reject berhasil
    if (_isDone) return _buildDonePage();
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Approval Peminjaman',
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
            'Approval Peminjaman',
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
                Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
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

    final booking = _bookingData!;
    final status = booking['status'] ?? 'SUBMITTED';
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);
    final waktuPinjam = booking['waktuPinjam'] is Timestamp
        ? (booking['waktuPinjam'] as Timestamp).toDate()
        : null;
    final waktuKembali = booking['waktuKembali'] is Timestamp
        ? (booking['waktuKembali'] as Timestamp).toDate()
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Approval Peminjaman',
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(status),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Menunggu persetujuan Anda',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Detail Peminjaman Card
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
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_car_filled_outlined,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Detail Peminjaman',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _buildDetailItem('ID Peminjaman', booking['id']),
                    _buildDetailItem('Nama Peminjam', booking['namaPeminjam'] ?? '-'),
                    _buildDetailItem('Divisi', booking['divisi'] ?? '-'),
                    _buildDetailItem(
                      'Kendaraan',
                      '${_vehicleData?['nama'] ?? booking['vehicle']?['nama'] ?? '-'}'
                      ' (${_vehicleData?['platNomor'] ?? booking['vehicle']?['platNomor'] ?? '-'})',
                    ),
                    _buildDetailItem('Tujuan', booking['tujuan'] ?? '-'),
                    _buildDetailItem('Keperluan', booking['keperluan'] ?? '-'),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal Pinjam',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                waktuPinjam != null
                                    ? DateFormat('dd MMMM yyyy', 'id_ID')
                                        .format(waktuPinjam)
                                    : '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                waktuPinjam != null
                                    ? DateFormat('HH:mm', 'id_ID')
                                        .format(waktuPinjam)
                                    : '-',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade700),
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
                                'Tanggal Kembali',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                waktuKembali != null
                                    ? DateFormat('dd MMMM yyyy', 'id_ID')
                                        .format(waktuKembali)
                                    : '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                waktuKembali != null
                                    ? DateFormat('HH:mm', 'id_ID')
                                        .format(waktuKembali)
                                    : '-',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (booking['createdAt'] != null) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey),
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

              // Action Buttons
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
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.red, strokeWidth: 2),
                            )
                          : const Text('Tolak',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
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
                          : const Text('Setujui',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
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
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
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