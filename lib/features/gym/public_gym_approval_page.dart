import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/approval_notification_service.dart';

class PublicGymApprovalPage extends StatefulWidget {
  final String bookingId;
  final String token;

  const PublicGymApprovalPage({
    super.key,
    required this.bookingId,
    required this.token,
  });

  @override
  State<PublicGymApprovalPage> createState() => _PublicGymApprovalPageState();
}

class _PublicGymApprovalPageState extends State<PublicGymApprovalPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _tokenData;

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

      final expiresAt = (_tokenData!['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        setState(() {
          _error = 'Link sudah kadaluarsa (berlaku 24 jam)';
          _isLoading = false;
        });
        return;
      }

      if (_tokenData!['used'] == true) {
        setState(() {
          _error = 'Link sudah digunakan sebelumnya';
          _isLoading = false;
        });
        return;
      }

      final bookingType = _tokenData!['bookingType'] as String?;
      if (bookingType != null && bookingType != 'gym') {
        setState(() {
          _error = 'Link ini bukan untuk approval ruang gym';
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
          .collection('gym_bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        setState(() {
          _error = 'Data peminjaman gym tidak ditemukan';
          _isLoading = false;
        });
        return;
      }

      _bookingData = {'id': bookingDoc.id, ...bookingDoc.data()!};
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove() async {
    final confirmed = await _showConfirmDialog(
      title: 'Setujui Peminjaman',
      message: 'Apakah Anda yakin ingin menyetujui peminjaman ruang gym ini?',
      confirmText: 'Setujui',
      isApprove: true,
    );
    if (confirmed != true) return;

    try {
      setState(() => _isProcessing = true);

      final latestDoc = await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.bookingId)
          .get();

      if (!latestDoc.exists) {
        _showSnackBar('Data peminjaman tidak ditemukan', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      final latestData = latestDoc.data()!;
      final latestStatus = latestData['status'] ?? 'PENDING';

      if (latestStatus != 'PENDING') {
        _showSnackBar(
          'Status sudah berubah: ${_getStatusText(latestStatus)}',
          isError: true,
        );
        await FirebaseFirestore.instance
            .collection('approval_tokens')
            .doc(widget.token)
            .update({
          'used': true,
          'usedAt': Timestamp.now(),
          'invalidReason': 'Status sudah berubah sebelum approval',
        });
        setState(() => _isProcessing = false);
        return;
      }

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
      final userName = userData['nama'] ?? '';
      final userRole = userData['role'] ?? 'operator';

      final now = Timestamp.now();

      // Update status ke APPROVED
      await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'APPROVED',
        'updatedAt': now,
        'lastApprovalBy': userName,
        'lastApprovalRole': userRole,
        'approval.operator': {
          'uid': userId,
          'nama': userName,
          'status': 'APPROVED',
          'approvedAt': now,
        },
      });

      // Catat history
      await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'APPROVED',
        'oldStatus': latestStatus,
        'newStatus': 'APPROVED',
        'actionBy': userName,
        'actionRole': userRole,
        'userId': userId,
        'timestamp': now,
        'note': 'Diverifikasi Operator oleh $userName (via WA)',
      });

      // Kirim notif ke peminjam
      try {
        final bookingDataWithId = {'id': widget.bookingId, ...latestData};
        await ApprovalNotificationService.sendGymApprovedNotificationToPeminjam(
          bookingId: widget.bookingId,
          bookingData: bookingDataWithId,
        );
      } catch (e) {
        print('⚠️ [Gym] Gagal kirim notif ke peminjam: $e');
      }

      // Mark token as used
      await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(widget.token)
          .update({'used': true, 'usedAt': now});

      _setDoneState(
        isApproved: true,
        message: 'Peminjaman ruang gym telah disetujui!',
      );
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

      final userId = _tokenData!['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userData = userDoc.data()!;
      final userName = userData['nama'] ?? '';
      final userRole = userData['role'] ?? 'operator';

      final currentStatus = _bookingData!['status'] ?? 'PENDING';
      final now = Timestamp.now();

      await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'CANCELLED',
        'rejectionReason': reason,
        'rejectedBy': userName,
        'rejectedRole': userRole,
        'updatedAt': now,
      });

      await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'REJECTED',
        'oldStatus': currentStatus,
        'newStatus': 'CANCELLED',
        'actionBy': userName,
        'actionRole': userRole,
        'userId': userId,
        'timestamp': now,
        'note': 'Ditolak oleh $userName (via WA)',
        'reason': reason,
      });

      // Kirim notif penolakan ke peminjam
      try {
        await ApprovalNotificationService.sendGymRejectedNotificationToPeminjam(
          bookingId: widget.bookingId,
          bookingData: _bookingData!,
          rejectedBy: userName,
          reason: reason,
        );
      } catch (e) {
        print('⚠️ [Gym] Gagal kirim notif penolakan: $e');
      }

      // Mark token as used
      await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(widget.token)
          .update({'used': true, 'usedAt': now});

      _setDoneState(
        isApproved: false,
        message: 'Peminjaman ruang gym berhasil ditolak.',
      );
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
              backgroundColor:
                  isApprove ? Colors.green.shade600 : Colors.red.shade600,
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
        title: const Text('Tolak Peminjaman Gym'),
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
                hintText: 'Contoh: Jadwal gym tidak tersedia',
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(ts.toDate());
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING': return 'Menunggu Operator';
      case 'APPROVED': return 'Disetujui';
      case 'DONE': return 'Selesai';
      case 'CANCELLED': return 'Ditolak/Dibatalkan';
      default: return status;
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Approval Ruang Gym',
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
                          ? (booking['id'] ?? '-').toString().substring(0, 12).toUpperCase()
                          : (booking['id'] ?? '-').toString().toUpperCase(),
                    ),
                    const SizedBox(height: 12),
                    _buildDoneRow(
                      Icons.person_outline_rounded,
                      'Peminjam',
                      peminjam['nama'] ?? '-',
                    ),
                    const SizedBox(height: 12),
                    _buildDoneRow(
                      Icons.business_outlined,
                      'Divisi',
                      peminjam['divisi'] ?? '-',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
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
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green.shade600),
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
        appBar: _buildAppBar(),
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
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final booking = _bookingData!;
    final status = booking['status'] ?? 'PENDING';
    final peminjam = booking['peminjam'] as Map<String, dynamic>? ?? {};

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
                      child: const Icon(Icons.hourglass_empty_rounded,
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
                              color: Colors.orange.shade700,
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
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.fitness_center,
                              color: Colors.green.shade700, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Detail Peminjaman Gym',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _buildDetailItem('ID Peminjaman', booking['id'] ?? '-'),
                    _buildDetailItem('Nama Peminjam', peminjam['nama'] ?? '-'),
                    _buildDetailItem('NIPP', peminjam['nipp'] ?? '-'),
                    _buildDetailItem('Divisi', peminjam['divisi'] ?? '-'),
                    _buildDetailItem('Jabatan', peminjam['jabatan'] ?? '-'),

                    if ((booking['catatan'] ?? '').toString().isNotEmpty) ...[
                      _buildDetailItem('Catatan', booking['catatan'].toString()),
                    ],

                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 16),

                    // Jadwal
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mulai',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
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
                                    ? DateFormat('HH:mm').format(waktuMulai)
                                    : '-',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600),
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
                              Text('Selesai',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
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
                                    ? DateFormat('HH:mm').format(waktuSelesai)
                                    : '-',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600),
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
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Approval Ruang Gym',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade900,
        ),
      ),
      centerTitle: true,
    );
  }
}