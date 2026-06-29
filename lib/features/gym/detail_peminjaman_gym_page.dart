import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/approval_notification_service.dart';

class DetailPeminjamanGymPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isApprovalMode;
  final String role;
  final String userName;
  final String userId;
  final String userDivision;
  final String? operatorType;

  const DetailPeminjamanGymPage({
    super.key,
    required this.data,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
    this.isApprovalMode = false,
    this.operatorType,
  });

  @override
  State<DetailPeminjamanGymPage> createState() =>
      _DetailPeminjamanGymPageState();
}

class _DetailPeminjamanGymPageState extends State<DetailPeminjamanGymPage> {
  String? _userJabatan;
  bool _isLoading = false;
  Map<String, dynamic>? _bookingData;
  List<Map<String, dynamic>> _approvalHistory = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _loadBookingData();
  }

  Future<void> _loadBookingData() async {
    try {
      setState(() => _isLoading = true);

      // ← tambah fetch jabatan
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        _userJabatan = userDoc.data()?['jabatan'];
      } catch (_) {}

      final bookingDoc = await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.data['id'])
          .get();

      if (bookingDoc.exists) {
        _bookingData = {'id': bookingDoc.id, ...bookingDoc.data()!};
        await _loadApprovalHistory();
      }
    } catch (e) {
      debugPrint('Error loading gym booking data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadApprovalHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.data['id'])
          .collection('approval_history')
          .orderBy('timestamp', descending: true)
          .get();

      _approvalHistory =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('Error loading approval history: $e');
    }
  }

  bool _isGymSessionStarted() {
    final waktuMulai = _bookingData?['waktuMulai'] as Timestamp?;
    if (waktuMulai == null) return false;
    return DateTime.now().isAfter(waktuMulai.toDate());
  }

  // ─── Approve ───────────────────────────────────────────────────────────────

 Future<void> _approveBooking() async {
  try {
    setState(() => _isLoading = true);

    final currentStatus = _bookingData?['status'] ?? 'PENDING';

    if (currentStatus != 'PENDING') {
      throw Exception('Status tidak valid untuk approval ini');
    }

    final now = Timestamp.now();

    await FirebaseFirestore.instance
        .collection('gym_bookings')
        .doc(widget.data['id'])
        .update({
      'status': 'APPROVED',
      'updatedAt': now,
      'lastApprovalBy': widget.userName,
      'lastApprovalRole': widget.role,
      'approval.operator': {
        'uid': widget.userId,
        'nama': widget.userName,
        'status': 'APPROVED',
        'approvedAt': now,
      },
    });

    await FirebaseFirestore.instance
        .collection('gym_bookings')
        .doc(widget.data['id'])
        .collection('approval_history')
        .add({
      'action': 'APPROVED',
      'oldStatus': currentStatus,
      'newStatus': 'APPROVED',
      'actionBy': widget.userName,
      'actionRole': widget.role,
      'userId': widget.userId,
      'timestamp': now,
      'note': 'Diverifikasi Operator oleh ${widget.userName}',
    });
    
    // Setelah update Firestore berhasil, kirim notif ke peminjam
    try {
      final updatedData = {'id': widget.data['id'], ..._bookingData!};
      await ApprovalNotificationService.sendGymApprovedNotificationToPeminjam(
        bookingId: widget.data['id'],
        bookingData: updatedData,
      );
    } catch (e) {
      debugPrint('⚠️ [Gym] Gagal kirim notif approved: $e');
    }

    await _loadBookingData();

    if (mounted) {
      _showSnackBar('Peminjaman berhasil disetujui', Colors.green.shade600);
      Navigator.pop(context, true);
    }
  } catch (e) {
    if (mounted) {
      _showSnackBar('Gagal menyetujui: $e', Colors.red.shade600);
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  // ─── Reject ────────────────────────────────────────────────────────────────

  Future<void> _rejectBooking() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tolak Peminjaman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan alasan penolakan:'),
            const SizedBox(height: 12),
            TextFormField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                hintText: 'Contoh: Jadwal gym tidak tersedia, dll.',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Harap masukkan alasan penolakan'),
                ));
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || reason.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      final now = Timestamp.now();
      final currentStatus = _bookingData?['status'];

      await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.data['id'])
          .update({
        'status': 'CANCELLED',
        'rejectionReason': reason,
        'rejectedBy': widget.userName,
        'rejectedRole': widget.role,
        'rejectedJabatan': _userJabatan,
        'updatedAt': now,
      });

      await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.data['id'])
          .collection('approval_history')
          .add({
        'action': 'REJECTED',
        'oldStatus': currentStatus,
        'newStatus': 'CANCELLED',
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'actionJabatan': _userJabatan,
        'userId': widget.userId,
        'timestamp': now,
        'note': 'Ditolak oleh ${widget.userName}',
        'reason': reason,
      });

      try {
        await ApprovalNotificationService.sendGymRejectedNotificationToPeminjam(
          bookingId: widget.data['id'],
          bookingData: _bookingData!,    
          rejectedBy: widget.userName,
          reason: reason,
        );
      } catch (e) {
        debugPrint('⚠️ [Gym] Gagal kirim notif rejected: $e');
      }

      await _loadBookingData();

      if (mounted) {
        _showSnackBar('Peminjaman berhasil ditolak', Colors.red.shade600);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal menolak: $e', Colors.red.shade600);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Mark Done ─────────────────────────────────────────────────────────────

  Future<void> _markAsDone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Selesaikan Peminjaman'),
        content:
            const Text('Tandai peminjaman ruang gym ini sebagai selesai?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white),
            child: const Text('Ya, Selesai'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      final now = Timestamp.now();

      await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.data['id'])
          .update({
        'status': 'DONE',
        'completedAt': now,
        'updatedAt': now,
        'completedBy': widget.userName,
      });

      await FirebaseFirestore.instance
          .collection('gym_bookings')
          .doc(widget.data['id'])
          .collection('approval_history')
          .add({
        'action': 'COMPLETED',
        'oldStatus': _bookingData?['status'],
        'newStatus': 'DONE',
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'userId': widget.userId,
        'timestamp': now,
        'note': 'Peminjaman selesai, ditandai oleh ${widget.userName}',
      });

      await _loadBookingData();

      if (mounted) {
        _showSnackBar(
            'Peminjaman berhasil ditandai selesai', Colors.green.shade600);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Gagal: $e', Colors.red.shade600);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Cancel by Admin/Operator ──────────────────────────────────────────────

  Future<void> _cancelBooking() async {
    if (_isGymSessionStarted()) {
      _showSnackBar(
        'Tidak dapat membatalkan: sesi gym sedang berlangsung',
        Colors.orange.shade700,
      );
      return;
    }

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Batalkan Peminjaman'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.role == 'operator'
                  ? 'Anda akan mengajukan request pembatalan kepada Admin.'
                  : 'Anda akan membatalkan peminjaman ini secara langsung.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            const Text('Masukkan alasan pembatalan:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                hintText: 'Contoh: Ada keperluan mendadak, dll.',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Alasan pembatalan harus diisi'),
                  backgroundColor: Colors.red.shade600,
                ));
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white),
            child: Text(widget.role == 'operator'
                ? 'Ajukan Request'
                : 'Ya, Batalkan'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || reason.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      final now = Timestamp.now();

      if (widget.role == 'operator') {
        await FirebaseFirestore.instance
            .collection('gym_bookings')
            .doc(widget.data['id'])
            .update({
          'cancellationRequested': true,
          'cancellationRequestedBy': widget.userName,
          'cancellationRequestedByRole': 'operator',
          'cancellationRequestedByJabatan': _userJabatan,
          'cancellationRequestReason': reason,
          'cancellationRequestedAt': now,
          'updatedAt': now,
        });

        await FirebaseFirestore.instance
            .collection('gym_bookings')
            .doc(widget.data['id'])
            .collection('approval_history')
            .add({
          'action': 'CANCELLATION_REQUESTED',
          'oldStatus': _bookingData?['status'],
          'newStatus': _bookingData?['status'],
          'actionBy': widget.userName,
          'actionRole': 'operator',
          'actionJabatan': _userJabatan,
          'userId': widget.userId,
          'timestamp': now,
          'note': 'Request pembatalan gym oleh ${widget.userName}',
          'reason': reason,
        });

        await _loadBookingData();
        if (mounted) {
          _showSnackBar(
              'Request pembatalan berhasil dikirim ke Admin',
              Colors.orange.shade600);
          Navigator.pop(context, true);
        }
      } else {
        // Admin → langsung cancel
        final currentStatus = _bookingData?['status'];

        await FirebaseFirestore.instance
            .collection('gym_bookings')
            .doc(widget.data['id'])
            .update({
          'status': 'CANCELLED',
          'cancellationReason': reason,
          'cancelledBy': widget.userName,
          'cancelledByRole': 'admin',
          'cancelledByJabatan': _userJabatan,
          'cancelledAt': now,
          'cancellationRequested': false,
          'updatedAt': now,
        });

        await FirebaseFirestore.instance
            .collection('gym_bookings')
            .doc(widget.data['id'])
            .collection('approval_history')
            .add({
          'action': 'CANCELLED_BY_ADMIN',
          'oldStatus': currentStatus,
          'newStatus': 'CANCELLED',
          'actionBy': widget.userName,
          'actionRole': 'admin',
          'actionJabatan': _userJabatan,
          'userId': widget.userId,
          'timestamp': now,
          'note': 'Dibatalkan langsung oleh Admin: ${widget.userName}',
          'reason': reason,
        });

        await _loadBookingData();
        if (mounted) {
          _showSnackBar(
              'Peminjaman berhasil dibatalkan', Colors.red.shade600);
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Gagal: $e', Colors.red.shade600);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(ts.toDate());
  }

  String _formatDateOnly(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('dd MMMM yyyy', 'id_ID').format(ts.toDate());
  }

  String _formatTimeOnly(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('HH:mm', 'id_ID').format(ts.toDate());
  }

  // ─── Status Helpers ────────────────────────────────────────────────────────

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'Menunggu Verifikasi Operator';
      case 'APPROVED':
        return 'Disetujui Operator';
      case 'DONE':
        return 'Selesai';
      case 'CANCELLED':
        return 'Ditolak/Dibatalkan';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green.shade700;
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
      case 'PENDING':
        return Icons.hourglass_empty_rounded;
      case 'APPROVED':
        return Icons.check_circle_outline_rounded;
      case 'DONE':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.info_outline_rounded;
    }
}

  String _getStatusDescription(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pengajuan sedang menunggu verifikasi operator';
      case 'APPROVED':
        return 'Pengajuan telah disetujui operator. Ruang gym siap digunakan';
      case 'DONE':
        return 'Peminjaman ruang gym telah selesai';
      case 'CANCELLED':
        return 'Peminjaman ruang gym dibatalkan/ditolak';
      default:
        return '-';
    }
  }

  // ─── Timeline ──────────────────────────────────────────────────────────────

Widget _buildTimeline() {
  final steps = [
    {'label': 'Pengajuan', 'status': 'PENDING'},
    {'label': 'Verifikasi Operator', 'status': 'APPROVED'},
    {'label': 'Selesai', 'status': 'DONE'},
  ];

  final currentStatus = _bookingData?['status'] ?? 'PENDING';
  final isCancelled = currentStatus == 'CANCELLED';

  final statusOrder = ['PENDING', 'APPROVED', 'DONE'];
  final currentStep = isCancelled ? -1 : statusOrder.indexOf(currentStatus);

  return Column(
    children: List.generate(steps.length, (index) {
      final step = steps[index];
      final isLast = index == steps.length - 1;
      final isReached = !isCancelled && index <= currentStep;
      final isCurrent = !isCancelled && index == currentStep;

      Color dotColor;
      if (!isReached) {
        dotColor = Colors.grey.shade300;
      } else if (isCurrent) {
        dotColor = Colors.green.shade700;
      } else {
        dotColor = Colors.green.shade400;
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: isReached
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: isReached && !isCurrent
                      ? Colors.green.shade200
                      : Colors.grey.shade200,
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isReached ? FontWeight.w600 : FontWeight.w500,
                      color: isReached ? Colors.grey.shade900 : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTimelineDate(step['status']!),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }),
  );
}

String _getTimelineDate(String status) {
  if (status == 'PENDING') {
    return _formatTimestamp(_bookingData?['createdAt'] as Timestamp?);
  }
  final history = _approvalHistory.firstWhere(
    (h) => h['newStatus'] == status,
    orElse: () => {},
  );
  if (history.isNotEmpty && history['timestamp'] != null) {
    return _formatTimestamp(history['timestamp'] as Timestamp?);
  }
  if (status == 'DONE') {
    return _formatTimestamp(_bookingData?['completedAt'] as Timestamp?);
  }
  return 'Menunggu';
}

  // ─── Build Widgets ─────────────────────────────────────────────────────────

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  bool _canApprove(String status) {
    if (widget.role == 'operator') {
      final boleh = widget.operatorType == null ||
                    widget.operatorType == 'ruang_meeting';
      return boleh && status == 'PENDING';
    }
    return false;
  }

  bool _canMarkDone(String status) {
    if (widget.role == 'admin') return status == 'APPROVED';
    if (widget.role == 'operator') {
      final boleh = widget.operatorType == null ||
                    widget.operatorType == 'ruang_meeting';
      return boleh && status == 'APPROVED';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: Center(
            child:
                CircularProgressIndicator(color: Colors.green.shade600)),
      );
    }

    final booking = _bookingData ?? widget.data;
    final status = booking['status'] ?? 'PENDING';
    final statusColor = _getStatusColor(status);
    final peminjam = booking['peminjam'] as Map<String, dynamic>? ?? {};
    final waktuMulai = booking['waktuMulai'] as Timestamp?;
    final waktuSelesai = booking['waktuSelesai'] as Timestamp?;
    final catatan = (booking['catatan'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Banner ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getStatusIcon(status),
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStatusText(status),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusDescription(status),
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

            // ── Timeline ─────────────────────────────────────────────
            Text('Proses Persetujuan',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900)),
            const SizedBox(height: 16),
            _buildCard(child: _buildTimeline()),

            const SizedBox(height: 24),

            // ── Info Penyewa ──────────────────────────────────────────
            Text('Informasi Penyewa',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900)),
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                      'Detail Penyewa', Icons.person_outline,
                      Colors.blue.shade600),
                  const SizedBox(height: 16),
                  _buildDetailItem(
                      'Nama', peminjam['nama'] ?? widget.userName),
                  _buildDetailItem(
                      'NIPP', peminjam['nipp'] ?? '-'),
                  _buildDetailItem(
                      'Divisi',
                      peminjam['divisi'] ?? widget.userDivision),
                  _buildDetailItem(
                      'Jabatan', peminjam['jabatan'] ?? 'Staff'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Jadwal Pemakaian ──────────────────────────────────────
            Text('Jadwal Pemakaian Gym',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900)),
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Waktu Peminjaman',
                      Icons.fitness_center, Colors.green.shade600),
                  const SizedBox(height: 16),

                  // Waktu mulai & selesai — card hijau
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.green.shade100),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Mulai',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade600)),
                              const SizedBox(height: 4),
                              Text(
                                _formatDateOnly(waktuMulai),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Text(
                                _formatTimeOnly(waktuMulai),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_rounded,
                              color: Colors.green.shade600, size: 18),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Text('Selesai',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade600)),
                              const SizedBox(height: 4),
                              Text(
                                _formatDateOnly(waktuSelesai),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Text(
                                _formatTimeOnly(waktuSelesai),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Info: gym bisa dipakai banyak orang
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ruang gym dapat digunakan oleh beberapa pengguna secara bersamaan.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (booking['createdAt'] != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Diajukan pada: ${_formatTimestamp(booking['createdAt'] as Timestamp?)}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),

            // ── Catatan ───────────────────────────────────────────────
            if (catatan.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Catatan',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900)),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Catatan Peminjaman',
                        Icons.notes_outlined, Colors.orange.shade600),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        catatan,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Alasan Penolakan ──────────────────────────────────────
            if (status == 'CANCELLED') ...[
              const SizedBox(height: 16),
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
                        Icon(Icons.cancel_outlined,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Alasan Penolakan/Pembatalan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking['rejectionReason']?.toString() ??
                          booking['cancellationReason']?.toString() ??
                          'Tidak ada alasan yang diberikan',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                    ),
                    if (booking['rejectedBy'] != null ||
                        booking['cancelledBy'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Oleh: ${booking['rejectedBy'] ?? booking['cancelledBy']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ── Riwayat Approval ──────────────────────────────────────
            if (_approvalHistory.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Riwayat Approval',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: _approvalHistory.map((history) {
                    final action =
                        history['action'] as String? ?? '';
                    final histStatus =
                        history['newStatus'] as String? ?? '';

                    IconData icon;
                    Color iconColor;
                    Color bgColor;

                    if (action == 'APPROVED') {
                      icon = Icons.check;
                      iconColor = Colors.green;
                      bgColor = Colors.green.shade100;
                    } else if (action == 'REJECTED') {
                      icon = Icons.close;
                      iconColor = Colors.red;
                      bgColor = Colors.red.shade100;
                    } else if (action == 'COMPLETED') {
                      icon = Icons.check_circle;
                      iconColor = Colors.green;
                      bgColor = Colors.green.shade100;
                    } else if (action == 'CANCELLED_BY_ADMIN') {
                      icon = Icons.block;
                      iconColor = Colors.red.shade700;
                      bgColor = Colors.red.shade100;
                    } else if (action == 'CANCELLATION_REQUESTED') {
                      icon = Icons.hourglass_top_rounded;
                      iconColor = Colors.orange.shade700;
                      bgColor = Colors.orange.shade100;
                    } else {
                      icon = Icons.info;
                      iconColor = Colors.grey;
                      bgColor = Colors.grey.shade200;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon,
                                  color: iconColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    history['note'] ??
                                        '$action by ${history['actionBy']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time,
                                          size: 12,
                                          color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimestamp(
                                            history['timestamp']
                                                as Timestamp?),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  if (histStatus.isNotEmpty &&
                                      action != 'CANCELLATION_REQUESTED') ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                                histStatus)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _getStatusColor(
                                                  histStatus)
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        _getStatusText(histStatus),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(
                                              histStatus),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Action Buttons ────────────────────────────────────────
            _buildActionButtons(status),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    final sessionStarted = _isGymSessionStarted();

    // Mode approval
    if (widget.isApprovalMode && _canApprove(status)) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _rejectBooking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(
                        color: Colors.red.shade700, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Tolak',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _approveBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Setujui',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBackButton(),
        ],
      );
    }

    // Admin/Operator: tandai selesai + batalkan
    if (_canMarkDone(status)) {
      return Column(
        children: [
          // Banner sesi sedang berjalan
          if (sessionStarted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fitness_center,
                      color: Colors.green.shade700, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sesi gym sedang berlangsung',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pembatalan tidak tersedia saat sesi sedang berjalan.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tombol Batalkan (hanya jika belum mulai)
          if (!sessionStarted) ...[
            if (_bookingData?['cancellationRequested'] == true &&
                widget.role == 'operator')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded,
                        color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Request pembatalan sedang menunggu persetujuan Admin',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.role == 'admin' ||
                widget.role == 'operator') ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _cancelBooking,
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  label: Text(
                    widget.role == 'operator'
                        ? 'Request Pembatalan'
                        : 'Batalkan Peminjaman',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(
                        color: Colors.red.shade700, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

          // Tombol Tandai Selesai
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _markAsDone,
              icon:
                  const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Tandai Selesai',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildBackButton(),
        ],
      );
    }

    return _buildBackButton();
  }

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Text('Kembali',
            style:
                TextStyle(fontSize: 15, color: Colors.grey.shade700)),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.grey.shade700, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Detail Peminjaman Gym',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade900,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: Colors.grey.shade200),
      ),
    );
  }
}
