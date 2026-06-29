import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/approval_notification_service.dart';

class DetailPeminjamanRuangMeetingPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isApprovalMode;
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const DetailPeminjamanRuangMeetingPage({
    super.key,
    required this.data,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
    this.isApprovalMode = false,
  });

  @override
  State<DetailPeminjamanRuangMeetingPage> createState() =>
      _DetailPeminjamanRuangMeetingPageState();
}

class _DetailPeminjamanRuangMeetingPageState
    extends State<DetailPeminjamanRuangMeetingPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _roomData;
  List<Map<String, dynamic>> _approvalHistory = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _loadBookingData();
  }

  // ─── Load Data ────────────────────────────────────────────────────────────

  Future<void> _loadBookingData() async {
    try {
      setState(() => _isLoading = true);

      final bookingDoc = await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.data['id'])
          .get();

      if (bookingDoc.exists) {
        _bookingData = {'id': bookingDoc.id, ...bookingDoc.data()!};

        // Load room data
        final roomId = _bookingData!['ruang']?['roomId'] as String?;
        if (roomId != null && roomId.isNotEmpty) {
          final roomDoc = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomId)
              .get();
          if (roomDoc.exists) {
            _roomData = {'id': roomDoc.id, ...roomDoc.data()!};
          }
        }

        await _loadApprovalHistory();
      }
    } catch (e) {
      debugPrint('Error loading booking data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadApprovalHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.data['id'])
          .collection('approval_history')
          .orderBy('timestamp', descending: true)
          .get();

      _approvalHistory = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error loading approval history: $e');
    }
  }

  bool _isMeetingStarted() {
    final waktuMulai = _bookingData?['waktuMulai'] as Timestamp?;
    if (waktuMulai == null) return false;
    return DateTime.now().isAfter(waktuMulai.toDate());
  }

  Future<void> _approveBooking() async {
    try {
      setState(() => _isLoading = true);

      final currentStatus = _bookingData?['status'] ?? 'SUBMITTED';
      String newStatus;
      String actionText;

      // Ambil jabatan user
      String? userJabatan;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        userJabatan = userDoc.data()?['jabatan'];
      } catch (_) {}

      final isManagerDivisi =
          (userJabatan ?? '').toLowerCase().contains('manager');

      if (widget.role == 'user' && isManagerDivisi) {
        if (currentStatus != 'SUBMITTED') {
          throw Exception('Status tidak valid untuk approval ini');
        }
        newStatus = 'APPROVAL_1';
        actionText = 'Disetujui Manager Divisi';
      } else if (widget.role == 'operator') {
        if (currentStatus != 'APPROVAL_1') {
          throw Exception('Status tidak valid untuk approval ini');
        }
        newStatus = 'APPROVAL_2';
        actionText = 'Diverifikasi Operator';
      } else if (widget.role == 'admin') {
        if (currentStatus != 'APPROVAL_2') {
          throw Exception('Status tidak valid untuk approval ini');
        }
        newStatus = 'APPROVAL_3';
        actionText = 'Disetujui Manager Umum';
      } else {
        throw Exception('Role tidak memiliki izin untuk approval');
      }

      final now = Timestamp.now();

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.data['id'])
          .update({
        'status': newStatus,
        'updatedAt': now,
        'lastApprovalBy': widget.userName,
        'lastApprovalRole': widget.role,
        'approval.${_getApprovalKey(widget.role, isManagerDivisi)}': {
          'uid': widget.userId,
          'nama': widget.userName,
          'status': 'APPROVED',
          'approvedAt': now,
        },
      });

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.data['id'])
          .collection('approval_history')
          .add({
        'action': 'APPROVED',
        'oldStatus': currentStatus,
        'newStatus': newStatus,
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'actionJabatan': userJabatan,
        'userId': widget.userId,
        'timestamp': now,
        'note': '$actionText oleh ${widget.userName}',
      });

      // ── Kirim notif WA ──────────────────────────────────────
      try {
        final bookingDataWithId = {'id': widget.data['id'], ..._bookingData!};
        if (newStatus == 'APPROVAL_1') {
          await ApprovalNotificationService.sendRoomApprovalNotificationToOperator(
            bookingId: widget.data['id'],
            bookingData: bookingDataWithId,
          );
        } else if (newStatus == 'APPROVAL_2') {
          await ApprovalNotificationService.sendRoomApprovalNotificationToManagerUmum(
            bookingId: widget.data['id'],
            bookingData: bookingDataWithId,
          );
        } else if (newStatus == 'APPROVAL_3') {
          await ApprovalNotificationService.sendRoomApprovedNotificationToPeminjam(
            bookingId: widget.data['id'],
            bookingData: bookingDataWithId,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [Room] Gagal kirim notif WA: $e');
        // lanjut meski notif gagal
      }

      // ── Reload & navigasi ───────────────────────────────────
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

  String _getApprovalKey(String role, bool isManagerDivisi) {
    if (role == 'user' && isManagerDivisi) return 'manager';
    if (role == 'operator') return 'operator';
    return 'admin';
  }

  // ─── Reject ───────────────────────────────────────────────────────────────

  Future<void> _rejectBooking() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                hintText: 'Contoh: Ruang sudah tidak tersedia, dll.',
                hintStyle: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400),
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

      String? userJabatan;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        userJabatan = userDoc.data()?['jabatan'];
      } catch (_) {}

      final now = Timestamp.now();
      final currentStatus = _bookingData?['status'];

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.data['id'])
          .update({
        'status': 'CANCELLED',
        'rejectionReason': reason,
        'rejectedBy': widget.userName,
        'rejectedRole': widget.role,
        'rejectedJabatan': userJabatan,
        'updatedAt': now,
      });

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.data['id'])
          .collection('approval_history')
          .add({
        'action': 'REJECTED',
        'oldStatus': currentStatus,
        'newStatus': 'CANCELLED',
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'actionJabatan': userJabatan,
        'userId': widget.userId,
        'timestamp': now,
        'note': 'Ditolak oleh ${widget.userName}',
        'reason': reason,
      });

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

  // ─── Mark Done (Admin/Operator) ───────────────────────────────────────────

  Future<void> _markAsDone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Selesaikan Peminjaman'),
        content: const Text(
            'Tandai peminjaman ruang meeting ini sebagai selesai?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal',
                style: TextStyle(color: Colors.grey.shade600)),
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
          .collection('room_bookings')
          .doc(widget.data['id'])
          .update({
        'status': 'DONE',
        'completedAt': now,
        'updatedAt': now,
        'completedBy': widget.userName,
      });

      await FirebaseFirestore.instance
          .collection('room_bookings')
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
        _showSnackBar('Peminjaman berhasil ditandai selesai', Colors.green.shade600);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Gagal: $e', Colors.red.shade600);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Cancel by Admin/Operator ─────────────────────────────────────────────

  Future<void> _cancelBookingByAdminOperator() async {
        if (_isMeetingStarted()) {
      _showSnackBar(
        'Tidak dapat membatalkan: ruang meeting sedang digunakan saat ini',
        Colors.orange.shade700,
      );
      return;
    }
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Contoh: Ruang dibutuhkan untuk keperluan mendadak',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
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
              foregroundColor: Colors.white,
            ),
            child: Text(widget.role == 'operator' ? 'Ajukan Request' : 'Ya, Batalkan'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || reason.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      String? userJabatan;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(widget.userId).get();
        userJabatan = userDoc.data()?['jabatan'];
      } catch (_) {}

      final now = Timestamp.now();

      if (widget.role == 'operator') {
        // Operator → request ke admin (belum langsung cancel)
        await FirebaseFirestore.instance
            .collection('room_bookings')
            .doc(widget.data['id'])
            .update({
          'cancellationRequested': true,
          'cancellationRequestedBy': widget.userName,
          'cancellationRequestedByRole': 'operator',
          'cancellationRequestedByJabatan': userJabatan,
          'cancellationRequestReason': reason,
          'cancellationRequestedAt': now,
          'updatedAt': now,
        });

        await FirebaseFirestore.instance
            .collection('room_bookings')
            .doc(widget.data['id'])
            .collection('approval_history')
            .add({
          'action': 'CANCELLATION_REQUESTED',
          'oldStatus': _bookingData?['status'],
          'newStatus': _bookingData?['status'],
          'actionBy': widget.userName,
          'actionRole': 'operator',
          'actionJabatan': userJabatan,
          'userId': widget.userId,
          'timestamp': now,
          'note': 'Request pembatalan ruang oleh ${widget.userName}',
          'reason': reason,
        });

          await ApprovalNotificationService.sendRoomCancellationRequestToAdmin(
            bookingId: widget.data['id'],
            bookingData: _bookingData!,
            requestedBy: widget.userName,
            reason: reason,
          );

        await _loadBookingData();
        if (mounted) {
          _showSnackBar('Request pembatalan berhasil dikirim ke Admin', Colors.orange.shade600);
          Navigator.pop(context, true);
        }
      } else {
        // Admin → langsung cancel
        final currentStatus = _bookingData?['status'];

        await FirebaseFirestore.instance
            .collection('room_bookings')
            .doc(widget.data['id'])
            .update({
          'status': 'CANCELLED',
          'cancellationReason': reason,
          'cancelledBy': widget.userName,
          'cancelledByRole': 'admin',
          'cancelledByJabatan': userJabatan,
          'cancelledAt': now,
          'cancellationRequested': false,
          'updatedAt': now,
        });

        await FirebaseFirestore.instance
            .collection('room_bookings')
            .doc(widget.data['id'])
            .collection('approval_history')
            .add({
          'action': 'CANCELLED_BY_ADMIN',
          'oldStatus': currentStatus,
          'newStatus': 'CANCELLED',
          'actionBy': widget.userName,
          'actionRole': 'admin',
          'actionJabatan': userJabatan,
          'userId': widget.userId,
          'timestamp': now,
          'note': 'Dibatalkan langsung oleh Admin: ${widget.userName}',
          'reason': reason,
        });

        await _loadBookingData();
        if (mounted) {
          _showSnackBar('Peminjaman berhasil dibatalkan', Colors.red.shade600);
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Gagal: $e', Colors.red.shade600);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Change Room ──────────────────────────────────────────────────────────

  Future<void> _showSelectRoomDialog() async {
      if (_isMeetingStarted()) {
      _showSnackBar(
        'Tidak dapat mengubah ruang: meeting sedang berlangsung',
        Colors.orange.shade700,
      );
      return;
    }
    try {
      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where('status', isEqualTo: 'available')
          .get();

      if (roomsSnapshot.docs.isEmpty) {
        if (mounted) _showSnackBar('Tidak ada ruang yang tersedia', Colors.orange.shade600);
        return;
      }

      // Ambil booking aktif untuk deteksi konflik
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('room_bookings')
          .where('status', whereIn: ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3'])
          .get();

      final currentRoomId = _bookingData?['ruang']?['roomId'];
      final waktuMulai = (_bookingData?['waktuMulai'] as Timestamp?)?.toDate();
      final waktuSelesai = (_bookingData?['waktuSelesai'] as Timestamp?)?.toDate();

      // Deteksi ruang yang konflik waktu
      Map<String, String> conflictedRooms = {};
      for (final doc in bookingsSnapshot.docs) {
        if (doc.id == widget.data['id']) continue;
        final data = doc.data();
        final roomId = data['ruang']?['roomId'] as String?;
        final bMulai = (data['waktuMulai'] as Timestamp?)?.toDate();
        final bSelesai = (data['waktuSelesai'] as Timestamp?)?.toDate();
        if (roomId == null || bMulai == null || bSelesai == null) continue;
        if (waktuMulai != null && waktuSelesai != null) {
          if (waktuMulai.isBefore(bSelesai) && waktuSelesai.isAfter(bMulai)) {
            conflictedRooms[roomId] = data['peminjam']?['nama'] ?? '-';
          }
        }
      }

      final selectedRoom = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.meeting_room_outlined, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text('Pilih Ruangan'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: roomsSnapshot.docs.length,
              itemBuilder: (context, index) {
                final doc = roomsSnapshot.docs[index];
                final roomData = doc.data();
                final isCurrentRoom = doc.id == currentRoomId;
                final isConflict = conflictedRooms.containsKey(doc.id);
                final canSelect = !isCurrentRoom && !isConflict;

                Color cardColor;
                String? badgeText;
                Color? badgeColor;

                if (isCurrentRoom) {
                  cardColor = Colors.blue.shade50;
                  badgeText = 'Ruang saat ini';
                  badgeColor = Colors.blue.shade700;
                } else if (isConflict) {
                  cardColor = Colors.grey.shade100;
                  badgeText = 'Dipesan ${conflictedRooms[doc.id]}';
                  badgeColor = Colors.red.shade700;
                } else {
                  cardColor = Colors.white;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: cardColor,
                  child: ListTile(
                    leading: Icon(Icons.meeting_room_outlined,
                        color: isConflict || isCurrentRoom
                            ? Colors.grey
                            : Colors.teal.shade600),
                    title: Text(
                      roomData['namaRuang'] ?? '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: canSelect ? Colors.grey.shade900 : Colors.grey.shade500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${roomData['lokasi'] ?? '-'} • ${roomData['kapasitas'] ?? '-'} orang',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if (badgeText != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? Colors.grey).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: (badgeColor ?? Colors.grey).withOpacity(0.3)),
                            ),
                            child: Text(badgeText,
                                style: TextStyle(fontSize: 10, color: badgeColor,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ],
                    ),
                    trailing: Icon(
                      canSelect ? Icons.arrow_forward_ios : Icons.lock_outline,
                      size: 16,
                      color: canSelect ? Colors.grey.shade400 : Colors.grey.shade300,
                    ),
                    onTap: canSelect
                        ? () => Navigator.pop(context, {'id': doc.id, ...roomData})
                        : null,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
            ),
          ],
        ),
      );

      if (selectedRoom != null) await _updateRoom(selectedRoom);
    } catch (e) {
      if (mounted) _showSnackBar('Gagal memuat daftar ruang: $e', Colors.red.shade600);
    }
  }

  Future<void> _updateRoom(Map<String, dynamic> newRoom) async {
    try {
      setState(() => _isLoading = true);

      final oldRoomId = _bookingData?['ruang']?['roomId'];
      final oldRoomName = _bookingData?['ruang']?['namaRuang'] ?? '-';
      final newRoomId = newRoom['id'];
      final newRoomName = newRoom['namaRuang'];

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.data['id'])
          .update({
        'ruang': {
          'roomId': newRoomId,
          'namaRuang': newRoomName,
          'lokasi': newRoom['lokasi'] ?? '-',
        },
        'namaRuang': newRoomName,
        'lokasiRuang': newRoom['lokasi'] ?? '-',
        'updatedAt': Timestamp.now(),
        'lastEditBy': widget.userName,
        'lastEditRole': widget.role,
      });

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(widget.data['id'])
          .collection('approval_history')
          .add({
        'action': 'ROOM_CHANGED',
        'oldRoomId': oldRoomId,
        'oldRoomName': oldRoomName,
        'newRoomId': newRoomId,
        'newRoomName': newRoomName,
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'userId': widget.userId,
        'timestamp': Timestamp.now(),
        'note': 'Ruang diubah dari $oldRoomName ke $newRoomName oleh ${widget.userName}',
      });

      await _loadBookingData();
      if (mounted) {
        _showSnackBar('Ruang berhasil diubah ke $newRoomName', Colors.green.shade600);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Gagal mengubah ruang: $e', Colors.red.shade600);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // ─── Status Helpers ───────────────────────────────────────────────────────

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
        return 'Sedang Berlangsung';
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
      case 'SUBMITTED':
        return Colors.orange;
      case 'APPROVAL_1':
        return Colors.blue;
      case 'APPROVAL_2':
        return Colors.purple;
      case 'APPROVAL_3':
        return Colors.teal;
      case 'ON_GOING':
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
      case 'SUBMITTED':
        return Icons.hourglass_empty_rounded;
      case 'APPROVAL_1':
        return Icons.check_circle_outline_rounded;
      case 'APPROVAL_2':
        return Icons.verified_outlined;
      case 'APPROVAL_3':
        return Icons.thumb_up_alt_outlined;
      case 'ON_GOING':
        return Icons.meeting_room;
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
      case 'SUBMITTED':
        return 'Pengajuan sedang menunggu persetujuan manager divisi';
      case 'APPROVAL_1':
        return 'Disetujui manager divisi, menunggu verifikasi operator';
      case 'APPROVAL_2':
        return 'Diverifikasi operator, menunggu persetujuan manager umum';
      case 'APPROVAL_3':
        return 'Pengajuan telah disetujui. Ruang meeting siap digunakan';
      case 'ON_GOING':
        return 'Rapat sedang berlangsung';
      case 'DONE':
        return 'Peminjaman ruang meeting telah selesai';
      case 'CANCELLED':
        return 'Peminjaman ruang meeting dibatalkan/ditolak';
      default:
        return '-';
    }
  }

  // ─── Timeline ─────────────────────────────────────────────────────────────

  Widget _buildTimeline() {
    final steps = [
      {'label': 'Pengajuan', 'status': 'SUBMITTED'},
      {'label': 'Approval Manager Divisi', 'status': 'APPROVAL_1'},
      {'label': 'Verifikasi Operator', 'status': 'APPROVAL_2'},
      {'label': 'Approval Manager Umum', 'status': 'APPROVAL_3'},
      {'label': 'Selesai', 'status': 'DONE'},
    ];

    final currentStatus = _bookingData?['status'] ?? 'SUBMITTED';
    final isCancelled = currentStatus == 'CANCELLED';

    final statusOrder = [
      'SUBMITTED',
      'APPROVAL_1',
      'APPROVAL_2',
      'APPROVAL_3',
      'DONE',
    ];

    final currentStep =
        isCancelled ? -1 : statusOrder.indexOf(currentStatus);

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
          dotColor = Colors.teal.shade700;
        } else {
          dotColor = Colors.teal.shade400;
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
                    border:
                        Border.all(color: Colors.white, width: 3),
                  ),
                  child: isReached
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isReached && !isCurrent
                        ? Colors.teal.shade200
                        : Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(bottom: isLast ? 0 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step['label']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isReached
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isReached
                            ? Colors.grey.shade900
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimelineDate(step['status']!),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500),
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
    if (status == 'SUBMITTED') {
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

  // ─── Build Widgets ────────────────────────────────────────────────────────

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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

  Widget _buildChipList(List<String> items, Color color) {
    if (items.isEmpty) {
      return Text('Tidak ada',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            item,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Approval Buttons Logic ───────────────────────────────────────────────

  bool _canApprove(String status) {
    if (widget.role == 'user') {
      // Akan dicek jabatan di _approveBooking
      return status == 'SUBMITTED';
    }
    if (widget.role == 'operator') return status == 'APPROVAL_1';
    if (widget.role == 'admin') {
      return status == 'APPROVAL_2';
    }
    return false;
  }

  bool _canMarkDone(String status) {
    return (widget.role == 'admin' ||
            widget.role == 'operator') &&
        status == 'APPROVAL_3';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: Center(
            child: CircularProgressIndicator(color: Colors.teal.shade600)),
      );
    }

    final booking = _bookingData ?? widget.data;
    final status = booking['status'] ?? 'SUBMITTED';
    final statusColor = _getStatusColor(status);
    final peminjam = booking['peminjam'] as Map<String, dynamic>? ?? {};
    final konsumsi = (booking['konsumsi'] as List?)?.cast<String>() ?? [];
    final fasilitas =
        (_roomData?['fasilitas'] as List?)?.cast<String>() ?? [];

    final waktuMulai = booking['waktuMulai'] as Timestamp?;
    final waktuSelesai = booking['waktuSelesai'] as Timestamp?;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Banner ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: statusColor.withOpacity(0.2)),
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
                    child: Icon(
                      _getStatusIcon(status),
                      color: Colors.white,
                      size: 22,
                    ),
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
                              fontSize: 13,
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Timeline ───────────────────────────────────────────
            Text(
              'Proses Persetujuan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(child: _buildTimeline()),

            const SizedBox(height: 24),

            // ── Info Peminjam ──────────────────────────────────────
            Text(
              'Informasi Peminjam',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    'Detail Peminjam',
                    Icons.person_outline,
                    Colors.blue.shade600,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailItem(
                      'Nama', peminjam['nama'] ?? widget.userName),
                  _buildDetailItem(
                      'Divisi', peminjam['divisi'] ?? widget.userDivision),
                  _buildDetailItem(
                      'Jabatan', peminjam['jabatan'] ?? 'Staff'),
                  _buildDetailItem(
                      'Email', peminjam['email'] ?? '-'),
                  _buildDetailItem('NIPP', peminjam['nipp'] ?? '-'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Detail Kegiatan ────────────────────────────────────
            Text(
              'Detail Kegiatan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    'Informasi Kegiatan',
                    Icons.event_note_outlined,
                    Colors.teal.shade600,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailItem(
                      'Nama Kegiatan',
                      booking['namaKegiatan'] ?? '-'),
                  _buildDetailItem(
                      'Jenis Rapat', booking['jenisRapat'] ?? '-'),
                  _buildDetailItem(
                      'Jumlah Peserta',
                      '${booking['peserta'] ?? '-'} orang'),

                  // Waktu
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waktu Pelaksanaan',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.teal.shade100),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mulai',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              Colors.teal.shade600),
                                    ),
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
                                        color: Colors.teal.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.teal.shade600,
                                  size: 18,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Selesai',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              Colors.teal.shade600),
                                    ),
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
                                        color: Colors.teal.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (booking['createdAt'] != null)
                    Text(
                      'Diajukan pada: ${_formatTimestamp(booking['createdAt'])}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Info Ruang ─────────────────────────────────────────
            if (_roomData != null) ...[
              Text(
                'Informasi Ruang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      _roomData!['namaRuang'] ?? 'Ruang Meeting',
                      Icons.meeting_room_outlined,
                      Colors.purple.shade600,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                        'Lokasi', _roomData!['lokasi'] ?? '-'),
                    _buildDetailItem(
                        'Kapasitas',
                        '${_roomData!['kapasitas'] ?? '-'} orang'),
                    _buildDetailItem(
                        'Tipe',
                        (_roomData!['tipe'] as String? ?? '-')
                            .toUpperCase()),
                    if (fasilitas.isNotEmpty) ...[
                      Text(
                        'Fasilitas',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      _buildChipList(
                          fasilitas, Colors.purple.shade600),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Fasilitas Tambahan ────────────────────────────────
            Text(
              'Fasilitas Tambahan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    'Permintaan Tambahan',
                    Icons.room_service_outlined,
                    Colors.orange.shade600,
                  ),
                  const SizedBox(height: 16),

                  // Konsumsi
                  Text(
                    'Konsumsi',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  _buildChipList(konsumsi, Colors.orange.shade600),
                    if ((booking['konsumsiNote'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Catatan Konsumsi',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          booking['konsumsiNote'].toString(),
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Layout Ruangan
                    Text(
                      'Layout Ruangan',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        (booking['layoutRuangan'] ?? '').toString().isNotEmpty
                            ? booking['layoutRuangan'].toString()
                            : 'Tidak ada catatan layout',
                        style: TextStyle(
                          fontSize: 14,
                          color: (booking['layoutRuangan'] ?? '').toString().isNotEmpty
                              ? Colors.grey.shade800
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Alasan Penolakan ──────────────────────────────────
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
                    if (booking['rejectedBy'] != null || booking['cancelledBy'] != null) ...[
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

            // ── Riwayat Approval ──────────────────────────────────
            if (_approvalHistory.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Riwayat Approval',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
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
                      iconColor = Colors.teal;
                      bgColor = Colors.teal.shade100;
                    } else if (action == 'REJECTED') {
                      icon = Icons.close;
                      iconColor = Colors.red;
                      bgColor = Colors.red.shade100;
                    } else if (action == 'COMPLETED') {
                      icon = Icons.check_circle;
                      iconColor = Colors.green;
                      bgColor = Colors.green.shade100;
                    } else if (action == 'ROOM_CHANGED') {
                      icon = Icons.swap_horiz;
                      iconColor = Colors.blue;
                      bgColor = Colors.blue.shade100;
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
                          border: Border.all(
                              color: Colors.grey.shade200),
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
                                        '${action} by ${history['actionBy']}',
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
                                        _formatTimestamp(history[
                                            'timestamp'] as Timestamp?),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  if (histStatus.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
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

            // ── Action Buttons ─────────────────────────────────────
            _buildActionButtons(status),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

Widget _buildActionButtons(String status) {
  final meetingStarted = _isMeetingStarted();

  // Mode approval → tampilkan tombol approve/reject
  if (widget.isApprovalMode && _canApprove(status)) {
    return Column(
      children: [
        // Tombol Edit Ruangan untuk operator/admin saat approval
        // Disembunyikan jika meeting sudah mulai (meski di approval mode ini
        // seharusnya belum terjadi, tapi tetap aman untuk dicek)
        if ((widget.role == 'operator' || widget.role == 'admin') &&
            !meetingStarted) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _showSelectRoomDialog,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Ruangan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _rejectBooking,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Tolak',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _approveBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Setujui',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildBackButton(),
      ],
    );
  }

  // Admin/Operator dapat menandai selesai
  if (_canMarkDone(status)) {
    return Column(
      children: [
        // ── Banner: meeting sedang berlangsung ──────────────────
        if (meetingStarted) ...[
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
                Icon(Icons.meeting_room, color: Colors.green.shade700, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ruang sedang digunakan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Perubahan ruang dan pembatalan tidak tersedia saat meeting berlangsung.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Tombol Edit Ruangan (disembunyikan jika sudah mulai) ──
        if (!meetingStarted) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _showSelectRoomDialog,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Ruangan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Tombol Batalkan (disembunyikan jika sudah mulai) ──────
        if (!meetingStarted) ...[
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
          else if (widget.role == 'admin' || widget.role == 'operator') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _cancelBookingByAdminOperator,
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
                  side: BorderSide(color: Colors.red.shade700, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],

        // ── Tombol Tandai Selesai (selalu tampil) ─────────────────
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _markAsDone,
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text('Tandai Selesai',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
            style: TextStyle(
                fontSize: 15, color: Colors.grey.shade700)),
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
        'Detail Peminjaman Ruang Meeting',
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