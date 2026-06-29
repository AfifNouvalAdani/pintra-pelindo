import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../ruang_meeting/detail_peminjaman_ruang_meeting_page.dart';
import '../services/approval_notification_service.dart';

class ApprovalRuangMeetingPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;
  final String userJabatan;
  final String? operatorType; // ← TAMBAHKAN

  const ApprovalRuangMeetingPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
    required this.userJabatan,
    this.operatorType, // ← TAMBAHKAN
  });

  @override
  State<ApprovalRuangMeetingPage> createState() =>
      _ApprovalRuangMeetingPageState();
}

class _ApprovalRuangMeetingPageState extends State<ApprovalRuangMeetingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDisposed = false;

  bool _isLoading = true;
  bool _isHistoryLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  List<Map<String, dynamic>> _historyBookings = [];
  List<Map<String, dynamic>> _filteredHistoryBookings = [];
  String _sortOrder = 'terbaru';
  List<String> _selectedStatuses = [];

  String? _userJabatan;

  final List<String> _statusOptions = [
    'SUBMITTED',
    'APPROVAL_1',
    'APPROVAL_2',
    'APPROVAL_3',
    'DONE',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _historyBookings.isEmpty) {
        _loadHistoryBookings();
      }
    });
    _fetchUserJabatan();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserJabatan() async {
    if (_isDisposed) return;
    if (widget.userJabatan.isNotEmpty) {
      _userJabatan = widget.userJabatan;
    } else {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        _userJabatan = doc.data()?['jabatan'] ?? 'Staff';
      } catch (_) {
        _userJabatan = 'Staff';
      }
    }
    _setDefaultFilters();
    _loadBookings();
  }

  void _setDefaultFilters() {
    _selectedStatuses.clear();
    final isManagerDivisi =
        (_userJabatan ?? '').toLowerCase().contains('manager');

    if (widget.role == 'admin' || widget.role == 'manager_umum') {
      _selectedStatuses = ['APPROVAL_2'];
    } else if (widget.role == 'user' && isManagerDivisi) {
      _selectedStatuses = ['SUBMITTED'];
    } else if (widget.role == 'operator') {
      _selectedStatuses = ['APPROVAL_1'];
    }
  }

  // ─── Load waiting bookings ────────────────────────────────────────────────
  Future<void> _loadBookings() async {
    if (_isDisposed) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final isManagerDivisi =
          (_userJabatan ?? '').toLowerCase().contains('manager');

      Query query = FirebaseFirestore.instance.collection('room_bookings');

      if (widget.role == 'admin' || widget.role == 'manager_umum') {
        query = query.where('status', isEqualTo: 'APPROVAL_2');
      } else if (widget.role == 'user' && isManagerDivisi) {
        query = query
            .where('peminjam.divisi', isEqualTo: widget.userDivision)
            .where('status', isEqualTo: 'SUBMITTED');
      } else if (widget.role == 'operator') {
        query = query.where('status', isEqualTo: 'APPROVAL_1');
      } else {
        if (mounted && !_isDisposed) {
          setState(() {
            _bookings = [];
            _filteredBookings = [];
            _isLoading = false;
          });
        }
        return;
      }

      final snapshot =
          await query.orderBy('createdAt', descending: true).get();

      final docs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
        return peminjam['userId'] != widget.userId;
      }).toList();

      final bookings = await Future.wait(docs.map((doc) async {
        if (_isDisposed) return null;
        final data = doc.data() as Map<String, dynamic>;

        Map<String, dynamic>? roomData;
        final roomId = data['ruang']?['roomId'] as String?;
        if (roomId != null) {
          try {
            final roomDoc = await FirebaseFirestore.instance
                .collection('rooms')
                .doc(roomId)
                .get();
            if (roomDoc.exists) {
              roomData = {'id': roomDoc.id, ...roomDoc.data()!};
            }
          } catch (_) {}
        }

        final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final waktuMulai = (data['waktuMulai'] as Timestamp?)?.toDate();
        final waktuSelesai = (data['waktuSelesai'] as Timestamp?)?.toDate();

        return {
          'id': doc.id,
          'namaKegiatan': data['namaKegiatan'] ?? '-',
          'jenisRapat': data['jenisRapat'] ?? 'OFFLINE',
          'peserta': data['peserta'] ?? '-',
          'konsumsi': data['konsumsi'] ?? [],
          'dekorasi': data['dekorasi'] ?? 'NO',
          'status': data['status'] ?? 'SUBMITTED',
          'peminjamNama': peminjam['nama'] ?? '-',
          'peminjamDivisi': peminjam['divisi'] ?? '-',
          'peminjamJabatan': peminjam['jabatan'] ?? '-',
          'peminjamUserId': peminjam['userId'] ?? '',
          'namaRuang': roomData?['namaRuang'] ?? 'Ruang Meeting',
          'lokasiRuang': roomData?['lokasi'] ?? '-',
          'kapasitasRuang': roomData?['kapasitas']?.toString() ?? '-',
          'createdAt': createdAt,
          'waktuMulai': waktuMulai,
          'waktuSelesai': waktuSelesai,
          'rawData': data,
          'roomData': roomData,
        };
      }));

      final valid = bookings
          .where((b) => b != null)
          .cast<Map<String, dynamic>>()
          .toList();

      if (_isDisposed) return;
      if (mounted) {
        setState(() {
          _bookings = valid;
          _isLoading = false;
        });
      }
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading room bookings: $e');
      if (mounted && !_isDisposed) setState(() => _isLoading = false);
    }
  }

  // ─── Load history ─────────────────────────────────────────────────────────
  Future<void> _loadHistoryBookings() async {
    if (_isDisposed) return;
    if (mounted) setState(() => _isHistoryLoading = true);

    try {
      final historyQuery = await FirebaseFirestore.instance
          .collectionGroup('approval_history')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .get();

      final bookingIds = historyQuery.docs
          .where((doc) => doc.reference.path.startsWith('room_bookings/'))
          .map((doc) => doc.reference.path.split('/')[1])
          .toSet();

      if (bookingIds.isEmpty) {
        if (mounted && !_isDisposed) {
          setState(() {
            _historyBookings = [];
            _filteredHistoryBookings = [];
            _isHistoryLoading = false;
          });
        }
        return;
      }

      final bookings = await Future.wait(bookingIds.map((id) async {
        if (_isDisposed) return null;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('room_bookings')
              .doc(id)
              .get();
          if (!doc.exists) return null;

          final data = doc.data()!;

          Map<String, dynamic>? roomData;
          final roomId = data['ruang']?['roomId'] as String?;
          if (roomId != null) {
            try {
              final roomDoc = await FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(roomId)
                  .get();
              if (roomDoc.exists) {
                roomData = {'id': roomDoc.id, ...roomDoc.data()!};
              }
            } catch (_) {}
          }

          final histDocs = await FirebaseFirestore.instance
              .collection('room_bookings')
              .doc(id)
              .collection('approval_history')
              .where('userId', isEqualTo: widget.userId)
              .orderBy('timestamp', descending: true)
              .get();

          final hist =
              histDocs.docs.isNotEmpty ? histDocs.docs.first.data() : null;

          final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
          final createdAt =
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final waktuMulai = (data['waktuMulai'] as Timestamp?)?.toDate();
          final waktuSelesai = (data['waktuSelesai'] as Timestamp?)?.toDate();
          final histTimestamp =
              (hist?['timestamp'] as Timestamp?)?.toDate() ?? createdAt;

          return {
            'id': id,
            'namaKegiatan': data['namaKegiatan'] ?? '-',
            'jenisRapat': data['jenisRapat'] ?? 'OFFLINE',
            'peserta': data['peserta'] ?? '-',
            'status': data['status'] ?? 'SUBMITTED',
            'peminjamNama': peminjam['nama'] ?? '-',
            'peminjamDivisi': peminjam['divisi'] ?? '-',
            'namaRuang': roomData?['namaRuang'] ?? 'Ruang Meeting',
            'lokasiRuang': roomData?['lokasi'] ?? '-',
            'createdAt': createdAt,
            'waktuMulai': waktuMulai,
            'waktuSelesai': waktuSelesai,
            'histAction': hist?['action'] ?? '',
            'histNote': hist?['note'] ?? '',
            'histReason': hist?['reason'] ?? '',
            'histOldStatus': hist?['oldStatus'] ?? '',
            'histNewStatus': hist?['newStatus'] ?? '',
            'histTimestamp': histTimestamp,
            'rawData': data,
          };
        } catch (_) {
          return null;
        }
      }));

      final valid = bookings
          .where((b) => b != null)
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) {
          final aT = (a['histTimestamp'] as DateTime);
          final bT = (b['histTimestamp'] as DateTime);
          return bT.compareTo(aT);
        });

      if (_isDisposed) return;
      if (mounted) {
        setState(() {
          _historyBookings = valid;
          _filteredHistoryBookings = List.from(valid);
          _isHistoryLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted && !_isDisposed) setState(() => _isHistoryLoading = false);
    }
  }

  // ─── Filters ──────────────────────────────────────────────────────────────
  void _applyFilters() {
    if (_isDisposed) return;
    var result = List<Map<String, dynamic>>.from(_bookings);

    if (_selectedStatuses.isNotEmpty) {
      result = result
          .where((e) => _selectedStatuses.contains(e['status']))
          .toList();
    }

    result.sort((a, b) {
      final aT = a['createdAt'] as DateTime;
      final bT = b['createdAt'] as DateTime;
      return _sortOrder == 'terbaru' ? bT.compareTo(aT) : aT.compareTo(bT);
    });

    if (mounted) setState(() => _filteredBookings = result);
  }

  void _applyHistorySort() {
    if (_isDisposed) return;
    final result = List<Map<String, dynamic>>.from(_historyBookings)
      ..sort((a, b) {
        final aT = a['histTimestamp'] as DateTime;
        final bT = b['histTimestamp'] as DateTime;
        return _sortOrder == 'terbaru' ? bT.compareTo(aT) : aT.compareTo(bT);
      });
    if (mounted) setState(() => _filteredHistoryBookings = result);
  }

  void _resetFilters() {
    setState(() => _selectedStatuses.clear());
    _setDefaultFilters();
    _applyFilters();
  }

  Future<void> _approveBooking(Map<String, dynamic> item) async {
    if (_isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final currentStatus = item['status'] as String;
      String newStatus;
      String actionText;
      String approvalKey;

      final isManagerDivisi =
          (_userJabatan ?? '').toLowerCase().contains('manager');

      if (widget.role == 'user' && isManagerDivisi) {
        if (currentStatus != 'SUBMITTED') throw Exception('Status tidak valid');
        newStatus = 'APPROVAL_1';
        actionText = 'Disetujui Manager Divisi';
        approvalKey = 'manager';
      } else if (widget.role == 'operator') {
        if (currentStatus != 'APPROVAL_1') throw Exception('Status tidak valid');
        newStatus = 'APPROVAL_2';
        actionText = 'Diverifikasi Operator';
        approvalKey = 'operator';
      } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
        if (currentStatus != 'APPROVAL_2') throw Exception('Status tidak valid');
        newStatus = 'APPROVAL_3';
        actionText = 'Disetujui Manager Umum';
        approvalKey = 'admin';
      } else {
        throw Exception('Role tidak memiliki izin');
      }

      final now = Timestamp.now();

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(item['id'])
          .update({
        'status': newStatus,
        'updatedAt': now,
        'lastApprovalBy': widget.userName,
        'lastApprovalRole': widget.role,
        'approval.$approvalKey': {
          'uid': widget.userId,
          'nama': widget.userName,
          'status': 'APPROVED',
          'approvedAt': now,
        },
      });

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(item['id'])
          .collection('approval_history')
          .add({
        'action': 'APPROVED',
        'oldStatus': currentStatus,
        'newStatus': newStatus,
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'actionJabatan': _userJabatan,
        'userId': widget.userId,
        'timestamp': now,
        'note': '$actionText oleh ${widget.userName}',
      });

      // ── Kirim notif WA ──────────────────────────────────────
      try {
        // Ambil data booking terbaru dari Firestore untuk data yang akurat
        final bookingDoc = await FirebaseFirestore.instance
            .collection('room_bookings')
            .doc(item['id'])
            .get();
        final bookingDataWithId = {'id': item['id'], ...bookingDoc.data()!};

        if (newStatus == 'APPROVAL_1') {
          await ApprovalNotificationService.sendRoomApprovalNotificationToOperator(
            bookingId: item['id'],
            bookingData: bookingDataWithId,
          );
        } else if (newStatus == 'APPROVAL_2') {
          await ApprovalNotificationService.sendRoomApprovalNotificationToManagerUmum(
            bookingId: item['id'],
            bookingData: bookingDataWithId,
          );
        } else if (newStatus == 'APPROVAL_3') {
          await ApprovalNotificationService.sendRoomApprovedNotificationToPeminjam(
            bookingId: item['id'],
            bookingData: bookingDataWithId,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [Room] Gagal kirim notif WA: $e');
        // lanjut meski notif gagal
      }

      if (mounted && !_isDisposed) Navigator.pop(context);
      await _loadBookings();

      if (mounted && !_isDisposed) {
        _showSnackBar('Peminjaman berhasil disetujui', Colors.green.shade600);
      }
    } catch (e) {
      if (mounted && !_isDisposed) Navigator.pop(context);
      if (mounted && !_isDisposed) {
        _showSnackBar('Gagal menyetujui: $e', Colors.red.shade600);
      }
    }
  }

  // ─── Reject ───────────────────────────────────────────────────────────────
  Future<void> _rejectBooking(Map<String, dynamic> item, String reason) async {
    if (_isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final now = Timestamp.now();

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(item['id'])
          .update({
        'status': 'CANCELLED',
        'rejectionReason': reason,
        'rejectedBy': widget.userName,
        'rejectedRole': widget.role,
        'rejectedJabatan': _userJabatan,
        'updatedAt': now,
      });

      await FirebaseFirestore.instance
          .collection('room_bookings')
          .doc(item['id'])
          .collection('approval_history')
          .add({
        'action': 'REJECTED',
        'oldStatus': item['status'],
        'newStatus': 'CANCELLED',
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'actionJabatan': _userJabatan,
        'userId': widget.userId,
        'timestamp': now,
        'note': 'Ditolak oleh ${widget.userName}',
        'reason': reason,
      });

      if (mounted && !_isDisposed) Navigator.pop(context);
      await _loadBookings();

      if (mounted && !_isDisposed) {
        _showSnackBar('Peminjaman berhasil ditolak', Colors.red.shade600);
      }
    } catch (e) {
      if (mounted && !_isDisposed) Navigator.pop(context);
      if (mounted && !_isDisposed) {
        _showSnackBar('Gagal menolak: $e', Colors.red.shade600);
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  String _fmt(DateTime? dt, {bool timeOnly = false}) {
    if (dt == null) return '-';
    if (timeOnly) return DateFormat('HH:mm').format(dt);
    return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
  }

  bool _canApprove(String status) {
    final isManagerDivisi =
        (_userJabatan ?? '').toLowerCase().contains('manager');
    if (widget.role == 'user' && isManagerDivisi) return status == 'SUBMITTED';
    if (widget.role == 'operator') return status == 'APPROVAL_1';
    if (widget.role == 'admin' || widget.role == 'manager_umum') {
      return status == 'APPROVAL_2';
    }
    return false;
  }

  // ===== PERUBAHAN: logika akses dengan operatorType =====
  bool _hasAccess() {
    if (['admin', 'manager_umum'].contains(widget.role)) return true;
    if (widget.role == 'user') {
      return (_userJabatan ?? '').toLowerCase().contains('manager');
    }
    if (widget.role == 'operator') {
      // null (operator umum) → boleh, 'ruang_meeting' → boleh, 'kendaraan' → tidak boleh
      final opType = widget.operatorType;
      return opType == null || opType == 'ruang_meeting';
    }
    return false;
  }

  // ===== PERUBAHAN: pesan akses ditolak =====
  String _getAccessDeniedMessage() {
    if (widget.role == 'operator' && widget.operatorType == 'kendaraan') {
      return 'Anda adalah Operator Kendaraan.\nSilakan gunakan menu Approval Kendaraan.';
    }
    return 'Anda tidak memiliki izin untuk mengakses halaman ini';
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
        return Colors.teal;
      case 'DONE':
        return Colors.grey.shade600;
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
      case 'DONE':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.info_outline_rounded;
    }
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────
  void _showApproveDialog(Map<String, dynamic> item) {
    final isManagerDivisi =
        (_userJabatan ?? '').toLowerCase().contains('manager');
    String approvalText = '';
    if (widget.role == 'user' && isManagerDivisi) {
      approvalText = 'menyetujui sebagai Manager Divisi';
    } else if (widget.role == 'operator') {
      approvalText = 'memverifikasi sebagai Operator';
    } else {
      approvalText = 'menyetujui sebagai Manager Umum';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline_rounded,
                  size: 28, color: Colors.teal.shade700),
            ),
            const SizedBox(height: 16),
            Text(
              'Konfirmasi Approval',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900),
            ),
            const SizedBox(height: 8),
            Text(
              'Apakah Anda yakin ingin $approvalText?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogRow(Icons.event_note_outlined, item['namaKegiatan']),
                  const SizedBox(height: 4),
                  _dialogRow(Icons.meeting_room_outlined, item['namaRuang']),
                  const SizedBox(height: 4),
                  _dialogRow(
                    Icons.schedule_outlined,
                    '${_fmt(item['waktuMulai'] as DateTime?)} ${_fmt(item['waktuMulai'] as DateTime?, timeOnly: true)} — ${_fmt(item['waktuSelesai'] as DateTime?, timeOnly: true)}',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _approveBooking(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> item) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded,
                  size: 28, color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            Text(
              'Tolak Peminjaman',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                hintText: 'Masukkan alasan penolakan...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                _showSnackBar('Harap masukkan alasan penolakan', Colors.red.shade600);
                return;
              }
              final reason = reasonController.text.trim();
              Navigator.pop(context);
              await _rejectBooking(item, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Tolak'),
          ),
        ],
      ),
    ).then((_) => reasonController.dispose());
  }

  void _showFilterDialog() {
    final tempStatuses = List<String>.from(_selectedStatuses);

    showDialog<List<String>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Filter Status'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statusOptions.map((s) {
              final isSelected = tempStatuses.contains(s);
              return FilterChip(
                label: Text(_getStatusText(s)),
                selected: isSelected,
                selectedColor: _getStatusColor(s).withOpacity(0.15),
                checkmarkColor: _getStatusColor(s),
                labelStyle: TextStyle(
                  color: isSelected ? _getStatusColor(s) : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (val) => setDialogState(() {
                  val ? tempStatuses.add(s) : tempStatuses.remove(s);
                }),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
            ),
            TextButton(
              onPressed: () => setDialogState(() => tempStatuses.clear()),
              child: Text('Reset', style: TextStyle(color: Colors.red.shade600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, tempStatuses),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Terapkan'),
            ),
          ],
        ),
      ),
    ).then((result) {
      if (result != null && mounted) {
        setState(() => _selectedStatuses = result);
        _applyFilters();
      }
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_hasAccess()) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Akses Ditolak',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                _getAccessDeniedMessage(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWaitingTab(),
          _buildHistoryTab(),
        ],
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
        'Approval Ruang Meeting',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900),
      ),
      centerTitle: true,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Menunggu Approval'),
          Tab(text: 'Riwayat Approval'),
        ],
        labelColor: Colors.teal.shade700,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.teal.shade700,
      ),
    );
  }

  // ─── Waiting Tab ──────────────────────────────────────────────────────────

  Widget _buildWaitingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats card
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', _bookings.length.toString(),
                  Icons.list_alt_rounded, Colors.teal),
              _buildStatItem(
                'Menunggu',
                _bookings
                    .where((e) => _canApprove(e['status']))
                    .length
                    .toString(),
                Icons.hourglass_empty_rounded,
                Colors.orange,
              ),
            ],
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: Icon(Icons.filter_alt_outlined,
                      size: 18, color: Colors.grey.shade600),
                  label: Text(
                    _selectedStatuses.isNotEmpty
                        ? 'Filter Aktif'
                        : 'Filter',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_selectedStatuses.isNotEmpty)
                IconButton(
                  onPressed: _resetFilters,
                  icon: Icon(Icons.refresh_rounded,
                      color: Colors.teal.shade700),
                  tooltip: 'Reset Filter',
                ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _sortOrder =
                      _sortOrder == 'terbaru' ? 'terlama' : 'terbaru');
                  _applyFilters();
                },
                icon: Icon(
                  _sortOrder == 'terbaru'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                label: Text(
                  _sortOrder == 'terbaru' ? 'Terbaru' : 'Terlama',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                ),
              ),
            ],
          ),
        ),

        // List header
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.teal.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getWaitingTitle(),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${_filteredBookings.length} item',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: Colors.teal.shade600))
              : _filteredBookings.isEmpty
                  ? _buildEmptyState(isHistory: false)
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      color: Colors.teal.shade600,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: _filteredBookings.length,
                        itemBuilder: (_, i) =>
                            _buildApprovalCard(_filteredBookings[i], false),
                      ),
                    ),
        ),
      ],
    );
  }

  String _getWaitingTitle() {
    final isManagerDivisi =
        (_userJabatan ?? '').toLowerCase().contains('manager');
    if (widget.role == 'user' && isManagerDivisi) {
      return 'Menunggu Approval Divisi ${widget.userDivision}';
    } else if (widget.role == 'operator') {
      return 'Menunggu Verifikasi Operator';
    } else {
      return 'Menunggu Approval Manager Umum';
    }
  }

  // ─── History Tab ──────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.history,
                    color: Colors.green.shade700, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Riwayat Approval',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900)),
                    const SizedBox(height: 4),
                    Text(
                      'Peminjaman yang pernah Anda approve atau tolak',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Sort control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() => _sortOrder =
                  _sortOrder == 'terbaru' ? 'terlama' : 'terbaru');
              _applyHistorySort();
            },
            icon: Icon(
              _sortOrder == 'terbaru'
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              size: 16,
              color: Colors.grey.shade600,
            ),
            label: Text(_sortOrder == 'terbaru' ? 'Terbaru' : 'Terlama',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade700)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
            ),
          ),
        ),

        // List header
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text('Riwayat Approval Anda',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900)),
              const Spacer(),
              Text('${_filteredHistoryBookings.length} item',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
        ),

        Expanded(
          child: _isHistoryLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: Colors.teal.shade600))
              : _filteredHistoryBookings.isEmpty
                  ? _buildEmptyState(isHistory: true)
                  : RefreshIndicator(
                      onRefresh: _loadHistoryBookings,
                      color: Colors.teal.shade600,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: _filteredHistoryBookings.length,
                        itemBuilder: (_, i) => _buildApprovalCard(
                            _filteredHistoryBookings[i], true),
                      ),
                    ),
        ),
      ],
    );
  }

  // ─── Card ─────────────────────────────────────────────────────────────────

  Widget _buildApprovalCard(Map<String, dynamic> item, bool isHistory) {
    final status = item['status'] as String;
    final statusColor = _getStatusColor(status);
    final canApprove = !isHistory && _canApprove(status);

    // History badge
    final histAction = item['histAction'] as String? ?? '';
    Color histColor = Colors.grey;
    String histLabel = '-';
    if (histAction == 'APPROVED') {
      histColor = Colors.teal;
      histLabel = 'Disetujui';
    } else if (histAction == 'REJECTED') {
      histColor = Colors.red;
      histLabel = 'Ditolak';
    } else if (histAction == 'COMPLETED') {
      histColor = Colors.green;
      histLabel = 'Selesai';
    }

    final displayColor = isHistory ? histColor : statusColor;
    final displayLabel =
        isHistory ? histLabel : _getStatusText(status);
    final displayIcon = isHistory && histAction == 'REJECTED'
        ? Icons.cancel
        : isHistory && histAction == 'APPROVED'
            ? Icons.check_circle
            : _getStatusIcon(status);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanRuangMeetingPage(
            data: {'id': item['id'], ...item['rawData'] as Map<String, dynamic>},
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: canApprove,
          ),
        ),
      ).then((result) {
        if (result == true && mounted) {
          isHistory ? _loadHistoryBookings() : _loadBookings();
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(displayIcon,
                      color: displayColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['namaKegiatan'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isHistory
                            ? DateFormat('dd/MM/yyyy HH:mm').format(
                                item['histTimestamp'] as DateTime)
                            : DateFormat('dd/MM/yyyy HH:mm').format(
                                item['createdAt'] as DateTime),
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints:
                      const BoxConstraints(maxWidth: 100),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: displayColor.withOpacity(0.25)),
                  ),
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: displayColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 12),

            // ── History note ─────────────────────────────────
            if (isHistory && (item['histNote'] as String).isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    histAction == 'REJECTED'
                        ? Icons.close
                        : Icons.check,
                    size: 15,
                    color: histColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['histNote'],
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              if (histAction == 'REJECTED' &&
                  (item['histReason'] as String).isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.red.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Alasan: ${item['histReason']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],

            // ── Detail rows ──────────────────────────────────
            _detailRow(Icons.person_outline, 'Peminjam',
                item['peminjamNama']),
            const SizedBox(height: 8),
            _detailRow(Icons.business_outlined, 'Divisi',
                item['peminjamDivisi']),
            const SizedBox(height: 8),
            _detailRow(Icons.meeting_room_outlined, 'Ruang',
                item['namaRuang']),
            const SizedBox(height: 8),
            _detailRow(
              Icons.schedule_outlined,
              'Waktu',
              '${_fmt(item['waktuMulai'] as DateTime?)}, ${_fmt(item['waktuMulai'] as DateTime?, timeOnly: true)} — ${_fmt(item['waktuSelesai'] as DateTime?, timeOnly: true)}',
            ),
            const SizedBox(height: 8),
            _detailRow(Icons.people_outline, 'Peserta',
                '${item['peserta']} orang'),

            // ── Jenis rapat badge ────────────────────────────
            const SizedBox(height: 10),
            _buildJenisBadge(item['jenisRapat'] as String),

            // ── Action buttons ───────────────────────────────
            if (!isHistory && canApprove) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectDialog(item),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(
                            color: Colors.red.shade400, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Tolak',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showApproveDialog(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Setujui',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ] else if (!isHistory) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailPeminjamanRuangMeetingPage(
                        data: {
                          'id': item['id'],
                          ...item['rawData'] as Map<String, dynamic>
                        },
                        role: widget.role,
                        userName: widget.userName,
                        userId: widget.userId,
                        userDivision: widget.userDivision,
                        isApprovalMode: false,
                      ),
                    ),
                  ).then((_) => _loadBookings()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal.shade700,
                    side: BorderSide(color: Colors.teal.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Lihat Detail',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────────────────────

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJenisBadge(String jenis) {
    IconData icon;
    Color color;
    switch (jenis.toUpperCase()) {
      case 'ONLINE':
        icon = Icons.videocam_outlined;
        color = Colors.blue.shade600;
        break;
      case 'HYBRID':
        icon = Icons.devices_outlined;
        color = Colors.purple.shade600;
        break;
      default:
        icon = Icons.people_outline;
        color = Colors.teal.shade600;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(jenis.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _dialogRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.teal.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade800)),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required bool isHistory}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isHistory ? Icons.history : Icons.search_off_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isHistory ? 'Belum ada riwayat' : 'Tidak ada data',
            style: TextStyle(
                fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            isHistory
                ? 'Riwayat approval Anda akan muncul di sini'
                : 'Tidak ada peminjaman yang menunggu approval',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}