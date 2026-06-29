import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/approval_notification_service.dart';

class PublicRoomCancellationApprovalPage extends StatefulWidget {
  final String bookingId;
  final String token;
  final String requestedBy;
  final String reason;

  const PublicRoomCancellationApprovalPage({
    super.key,
    required this.bookingId,
    required this.token,
    required this.requestedBy,
    required this.reason,
  });

  @override
  State<PublicRoomCancellationApprovalPage> createState() =>
      _PublicRoomCancellationApprovalPageState();
}

class _PublicRoomCancellationApprovalPageState
    extends State<PublicRoomCancellationApprovalPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _tokenData;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() => _isLoading = true);

      // Validasi token
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

      // Pastikan token untuk room_cancellation
      final bookingType = _tokenData!['bookingType'] as String?;
      if (bookingType != 'room_cancellation') {
        setState(() {
          _error = 'Link ini bukan untuk approval pembatalan ruang meeting';
          _isLoading = false;
        });
        return;
      }

      // Load booking
      final bookingDoc = await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        setState(() {
          _error = 'Data peminjaman tidak ditemukan';
          _isLoading = false;
        });
        return;
      }

      _bookingData = {'id': bookingDoc.id, ...bookingDoc.data()!};

      // Pastikan masih ada request pembatalan pending
      if (_bookingData!['cancellationRequested'] != true) {
        setState(() {
          _error = 'Request pembatalan tidak ditemukan atau sudah diproses';
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  // ─── Setujui Pembatalan ───────────────────────────────────────────────────

  Future<void> _handleApprove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Setujui Pembatalan'),
        content: const Text(
            'Apakah Anda yakin menyetujui pembatalan ini? Peminjam akan mendapat notifikasi WA.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Setujui Pembatalan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isProcessing = true);

      final userId = _tokenData!['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userData = userDoc.data()!;
      final adminName = userData['nama'] ?? 'Admin';
      final adminJabatan = userData['jabatan'] ?? '';

      final requestedBy =
          _bookingData!['cancellationRequestedBy'] ?? widget.requestedBy;
      final reason =
          _bookingData!['cancellationRequestReason'] ?? widget.reason;
      final currentStatus = _bookingData!['status'];

      // Update status ke CANCELLED
      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'CANCELLED',
        'cancellationReason': reason,
        'cancelledBy': requestedBy,
        'cancelledByRole': 'operator',
        'approvedCancellationBy': adminName,
        'approvedCancellationByRole': 'admin',
        'approvedCancellationAt': Timestamp.now(),
        'cancellationRequested': false,
        'updatedAt': Timestamp.now(),
      });

      // Catat di approval history
      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'CANCELLATION_APPROVED',
        'oldStatus': currentStatus,
        'newStatus': 'CANCELLED',
        'actionBy': adminName,
        'actionRole': 'admin',
        'actionJabatan': adminJabatan,
        'userId': userId,
        'timestamp': Timestamp.now(),
        'note':
            'Admin $adminName menyetujui request pembatalan ruang dari Operator $requestedBy',
        'reason': reason,
      });

      // Mark token used
      await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(widget.token)
          .update({'used': true, 'usedAt': Timestamp.now()});

      // Kirim WA ke peminjam
      await ApprovalNotificationService.sendRoomRejectedNotificationToPeminjam(
        bookingId: widget.bookingId,
        bookingData: _bookingData!,
        rejectedBy: '$requestedBy (disetujui Admin $adminName)',
        reason: reason,
      );

      _showSuccessDialog(
          'Pembatalan ruang meeting berhasil disetujui. Peminjam telah diberitahu.');
    } catch (e) {
      _showSnackBar('Gagal menyetujui: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Tolak Request Pembatalan ─────────────────────────────────────────────

  Future<void> _handleReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tolak Request Pembatalan'),
        content: const Text(
            'Request pembatalan akan ditolak. Peminjaman ruang meeting akan tetap berlanjut.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isProcessing = true);

      final userId = _tokenData!['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data()!;
      final adminName = userData['nama'] ?? 'Admin';

      // Reset flag pembatalan, status tetap tidak berubah
      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .update({
        'cancellationRequested': false,
        'cancellationRejectedBy': adminName,
        'cancellationRejectedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      // Catat di approval history
      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'CANCELLATION_REJECTED',
        'oldStatus': _bookingData!['status'],
        'newStatus': _bookingData!['status'], // status tidak berubah
        'actionBy': adminName,
        'actionRole': 'admin',
        'userId': userId,
        'timestamp': Timestamp.now(),
        'note':
            'Admin $adminName menolak request pembatalan ruang dari Operator',
      });

      // Mark token used
      await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(widget.token)
          .update({'used': true, 'usedAt': Timestamp.now()});

      _showSuccessDialog(
          'Request pembatalan ditolak. Peminjaman ruang meeting tetap berlanjut.');
    } catch (e) {
      _showSnackBar('Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initialize();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
                const SizedBox(height: 24),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    final booking = _bookingData!;
    final peminjam = booking['peminjam'] as Map<String, dynamic>? ?? {};
    final requestedBy =
        booking['cancellationRequestedBy'] ?? widget.requestedBy;
    final reason = booking['cancellationRequestReason'] ?? widget.reason;
    final namaRuang = booking['namaRuang'] ??
        booking['ruang']?['namaRuang'] ??
        'Ruang Meeting';
    final waktuMulai = booking['waktuMulai'] is Timestamp
        ? (booking['waktuMulai'] as Timestamp).toDate()
        : null;
    final waktuSelesai = booking['waktuSelesai'] is Timestamp
        ? (booking['waktuSelesai'] as Timestamp).toDate()
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner request pembatalan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Pembatalan Ruang Meeting',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Operator $requestedBy meminta pembatalan peminjaman yang sudah disetujui',
                          style: TextStyle(
                              fontSize: 13, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Alasan pembatalan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.comment_outlined,
                          color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Alasan Pembatalan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(reason,
                      style:
                          TextStyle(fontSize: 14, color: Colors.red.shade700)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Detail peminjaman
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
                  Text('Detail Peminjaman Ruang',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900)),
                  const SizedBox(height: 16),
                  _buildDetailItem('ID Peminjaman', booking['id'] ?? '-'),
                  _buildDetailItem(
                      'Nama Peminjam',
                      peminjam['nama'] ?? booking['namaPeminjam'] ?? '-'),
                  _buildDetailItem(
                      'Divisi', peminjam['divisi'] ?? booking['divisi'] ?? '-'),
                  _buildDetailItem('Jabatan', peminjam['jabatan'] ?? '-'),
                  _buildDetailItem('Ruang', namaRuang),
                  _buildDetailItem(
                      'Kegiatan', booking['namaKegiatan'] ?? '-'),
                  _buildDetailItem(
                      'Jenis Rapat', booking['jenisRapat'] ?? '-'),
                  _buildDetailItem(
                      'Peserta', '${booking['peserta'] ?? '-'} orang'),
                  const SizedBox(height: 8),
                  // Waktu
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mulai',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                            Text(
                              waktuMulai != null
                                  ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                                      .format(waktuMulai)
                                  : '-',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Selesai',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                            Text(
                              waktuSelesai != null
                                  ? DateFormat('HH:mm', 'id_ID')
                                      .format(waktuSelesai)
                                  : '-',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Tombol aksi
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _handleReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side:
                          BorderSide(color: Colors.grey.shade400, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Tolak Request',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Setujui Pembatalan',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              '⚠️ Link berlaku 24 jam dan hanya dapat digunakan sekali',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Approval Pembatalan Ruang'),
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade900,
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900)),
        ],
      ),
    );
  }
}