import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../vehicle/detail_peminjaman_page.dart';
import '../services/approval_notification_service.dart';

class ApprovalKendaraanPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;
  final String userJabatan;
  final String? operatorType; // ← TAMBAHKAN

  const ApprovalKendaraanPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
    required this.userJabatan,
    this.operatorType, // ← TAMBAHKAN
  });

  @override
  State<ApprovalKendaraanPage> createState() => _ApprovalKendaraanPageState();
}

class _ApprovalKendaraanPageState extends State<ApprovalKendaraanPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String sortOrder = 'terbaru';
  DateTime? startDate;
  DateTime? endDate;
  List<String> selectedStatuses = [];

  bool _isLoading = true;
  bool _isHistoryLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  List<Map<String, dynamic>> _historyBookings = [];
  List<Map<String, dynamic>> _filteredHistoryBookings = [];
  String? _userJabatan;

  bool _isDisposed = false;

  final List<String> statusOptions = [
    'SUBMITTED',
    'APPROVAL_1',
    'APPROVAL_2',
    'APPROVAL_3',
    'ON_GOING',
    'DONE',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserJabatan();
    _tabController.addListener(() {
      if (_tabController.index == 1 && _historyBookings.isEmpty) {
        _loadHistoryBookings();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    super.dispose();
  }

  // ─── Fetch jabatan ────────────────────────────────────────────────────────
  Future<void> _fetchUserJabatan() async {
    if (_isDisposed) return;
    if (widget.userJabatan.isNotEmpty) {
      if (mounted && !_isDisposed) setState(() => _userJabatan = widget.userJabatan);
    } else {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        if (userDoc.exists) {
          if (mounted && !_isDisposed) setState(() => _userJabatan = userDoc.data()?['jabatan'] ?? 'Staff');
        }
      } catch (e) {
        print('Error fetching user jabatan: $e');
        if (mounted && !_isDisposed) setState(() => _userJabatan = 'Staff');
      }
    }

    if (!mounted || _isDisposed) return;
    _setDefaultFilters();
    _loadBookings();
  }

  void _setDefaultFilters() {
    selectedStatuses.clear();
    final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');

    if (widget.role == 'admin' || widget.role == 'manager_umum') {
      selectedStatuses = ['APPROVAL_2', 'APPROVAL_3'];
    } else if (widget.role == 'user' && isManagerDivisi) {
      selectedStatuses = ['SUBMITTED'];
    } else if (widget.role == 'operator') {
      selectedStatuses = ['APPROVAL_1'];
    }
  }

  // ─── Load waiting bookings ────────────────────────────────────────────────
  Future<void> _loadBookings() async {
    if (!mounted || _isDisposed) return;
    if (mounted && !_isDisposed) setState(() => _isLoading = true);

    try {
      List<QueryDocumentSnapshot> allDocs = [];
      final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');

      if (widget.role == 'admin' || widget.role == 'manager_umum') {
        final snapshot1 = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('status', isEqualTo: 'APPROVAL_2')
            .orderBy('createdAt', descending: true)
            .get();

        final snapshot2 = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('cancellationRequested', isEqualTo: true)
            .where('status', isEqualTo: 'APPROVAL_3')
            .orderBy('createdAt', descending: true)
            .get();

        final seenIds = <String>{};
        for (final doc in [...snapshot1.docs, ...snapshot2.docs]) {
          if (seenIds.add(doc.id)) allDocs.add(doc);
        }
      } else if (widget.role == 'user' && isManagerDivisi) {
        final s = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('divisi', isEqualTo: widget.userDivision)
            .where('status', isEqualTo: 'SUBMITTED')
            .orderBy('createdAt', descending: true)
            .get();

        allDocs = s.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['peminjamId'] != widget.userId;
        }).toList();
      } else if (widget.role == 'operator') {
        final s = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('status', isEqualTo: 'APPROVAL_1')
            .orderBy('createdAt', descending: true)
            .get();

        allDocs = s.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['peminjamId'] != widget.userId;
        }).toList();
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

      final bookings = await Future.wait(allDocs.map((doc) async {
        if (_isDisposed) return null;
        final data = doc.data() as Map<String, dynamic>;

        Map<String, dynamic>? vehicleData;
        if (data['vehicleId'] != null) {
          try {
            final vehicleDoc = await FirebaseFirestore.instance
                .collection('vehicles')
                .doc(data['vehicleId'])
                .get();
            if (vehicleDoc.exists) {
              vehicleData = {'id': vehicleDoc.id, ...vehicleDoc.data() as Map<String, dynamic>};
            }
          } catch (e) {
            print('Error fetching vehicle: $e');
          }
        }

        final waktuPinjam = data['waktuPinjam'] is Timestamp
            ? (data['waktuPinjam'] as Timestamp).toDate()
            : null;
        final waktuKembali = data['waktuKembali'] is Timestamp
            ? (data['waktuKembali'] as Timestamp).toDate()
            : null;
        final createdAt = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now();

        return {
          'id': doc.id,
          'bookingId': doc.id,
          'title': 'Peminjaman ${data['tujuan'] ?? '-'}',
          'kendaraan': data['vehicle'] != null
              ? (data['vehicle'] as Map<String, dynamic>)['nama'] ?? 'Kendaraan'
              : vehicleData?['nama'] ?? 'Kendaraan',
          'platNomor': data['vehicle'] != null
              ? (data['vehicle'] as Map<String, dynamic>)['platNomor'] ?? '-'
              : vehicleData?['platNomor'] ?? '-',
          'tujuan': data['tujuan'] ?? '-',
          'peminjam': data['namaPeminjam'] ?? 'Peminjam',
          'peminjamId': data['peminjamId'] ?? '',
          'divisi': data['divisi'] ?? '-',
          'status': data['status'] ?? 'SUBMITTED',
          'statusText': _getStatusText(data['status'] ?? 'SUBMITTED'),
          'tanggal': createdAt,
          'jam': DateFormat('HH:mm').format(createdAt),
          'keperluan': data['keperluan'] ?? '-',
          'nomorSurat': data['nomorSurat'] ?? '-',
          'alasan': data['alasan'] ?? '-',
          'tglPinjam': waktuPinjam != null ? DateFormat('dd MMM yyyy').format(waktuPinjam) : '-',
          'jamPinjam': waktuPinjam != null ? DateFormat('HH:mm').format(waktuPinjam) : '-',
          'tglKembali': waktuKembali != null ? DateFormat('dd MMM yyyy').format(waktuKembali) : '-',
          'jamKembali': waktuKembali != null ? DateFormat('HH:mm').format(waktuKembali) : '-',
          'createdAt': createdAt,
          'waktuPinjam': waktuPinjam,
          'waktuKembali': waktuKembali,
          'vehicleId': data['vehicleId'],
          'vehicleData': vehicleData,
          'bookingData': data,
          'cancellationRequested': data['cancellationRequested'] ?? false,
          'cancellationRequestReason': data['cancellationRequestReason'] ?? '',
          'cancellationRequestedBy': data['cancellationRequestedBy'] ?? '',
        };
      }));

      final validBookings = bookings.where((b) => b != null).cast<Map<String, dynamic>>().toList();

      if (!mounted || _isDisposed) return;
      setState(() {
        _bookings = validBookings;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      print('Error loading bookings: $e');
      if (!mounted || _isDisposed) return;
      setState(() => _isLoading = false);
    }
  }

  // ─── Load history bookings ────────────────────────────────────────────────
  Future<void> _loadHistoryBookings() async {
    if (!mounted || _isDisposed) return;
    if (mounted && !_isDisposed) setState(() => _isHistoryLoading = true);

    try {
      final approvalHistoryQuery = await FirebaseFirestore.instance
          .collectionGroup('approval_history')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .get();

      final bookingIds = approvalHistoryQuery.docs.map((doc) {
        final path = doc.reference.path;
        final parts = path.split('/');
        return parts[1];
      }).toSet();

      if (bookingIds.isEmpty) {
        if (!mounted || _isDisposed) return;
        setState(() {
          _historyBookings = [];
          _filteredHistoryBookings = [];
          _isHistoryLoading = false;
        });
        return;
      }

      final bookings = await Future.wait(bookingIds.map((bookingId) async {
        if (_isDisposed) return null;
        try {
          final bookingDoc = await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .doc(bookingId)
              .get();

          if (!bookingDoc.exists) return null;

          final data = bookingDoc.data() as Map<String, dynamic>;

          Map<String, dynamic>? vehicleData;
          if (data['vehicleId'] != null) {
            try {
              final vehicleDoc = await FirebaseFirestore.instance
                  .collection('vehicles')
                  .doc(data['vehicleId'])
                  .get();
              if (vehicleDoc.exists) {
                vehicleData = {
                  'id': vehicleDoc.id,
                  ...vehicleDoc.data() as Map<String, dynamic>,
                };
              }
            } catch (e) {
              print('Error fetching vehicle data: $e');
            }
          }

          final historyDocs = await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .doc(bookingId)
              .collection('approval_history')
              .where('userId', isEqualTo: widget.userId)
              .orderBy('timestamp', descending: true)
              .get();

          final historyData = historyDocs.docs.isNotEmpty ? historyDocs.docs.first.data() : null;

          final waktuPinjam = data['waktuPinjam'] is Timestamp
              ? (data['waktuPinjam'] as Timestamp).toDate()
              : null;
          final waktuKembali = data['waktuKembali'] is Timestamp
              ? (data['waktuKembali'] as Timestamp).toDate()
              : null;
          final createdAt = data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now();

          final historyTimestamp = historyData?['timestamp'] is Timestamp
              ? (historyData!['timestamp'] as Timestamp).toDate()
              : createdAt;

          return {
            'id': bookingId,
            'bookingId': bookingId,
            'title': 'Peminjaman ${data['tujuan'] ?? '-'}',
            'kendaraan': data['vehicle'] != null
                ? (data['vehicle'] as Map<String, dynamic>)['nama'] ?? 'Kendaraan'
                : vehicleData?['nama'] ?? 'Kendaraan',
            'platNomor': data['vehicle'] != null
                ? (data['vehicle'] as Map<String, dynamic>)['platNomor'] ?? '-'
                : vehicleData?['platNomor'] ?? '-',
            'tujuan': data['tujuan'] ?? '-',
            'peminjam': data['namaPeminjam'] ?? 'Peminjam',
            'peminjamId': data['peminjamId'] ?? '',
            'divisi': data['divisi'] ?? '-',
            'status': data['status'] ?? 'SUBMITTED',
            'statusText': _getStatusText(data['status'] ?? 'SUBMITTED'),
            'historyAction': historyData?['action'] ?? 'UNKNOWN',
            'historyNote': historyData?['note'] ?? '',
            'historyTimestamp': historyData?['timestamp'],
            'historyOldStatus': historyData?['oldStatus'] ?? '',
            'historyNewStatus': historyData?['newStatus'] ?? '',
            'historyReason': historyData?['reason'] ?? '',
            'tanggal': historyTimestamp,
            'jam': DateFormat('HH:mm').format(historyTimestamp),
            'keperluan': data['keperluan'] ?? '-',
            'nomorSurat': data['nomorSurat'] ?? '-',
            'alasan': data['alasan'] ?? '-',
            'tglPinjam': waktuPinjam != null ? DateFormat('dd MMM yyyy').format(waktuPinjam) : '-',
            'jamPinjam': waktuPinjam != null ? DateFormat('HH:mm').format(waktuPinjam) : '-',
            'tglKembali': waktuKembali != null ? DateFormat('dd MMM yyyy').format(waktuKembali) : '-',
            'jamKembali': waktuKembali != null ? DateFormat('HH:mm').format(waktuKembali) : '-',
            'createdAt': createdAt,
            'waktuPinjam': waktuPinjam,
            'waktuKembali': waktuKembali,
            'vehicleId': data['vehicleId'],
            'vehicleData': vehicleData,
            'bookingData': data,
          };
        } catch (e) {
          print('Error loading booking $bookingId: $e');
          return null;
        }
      }));

      final validBookings = bookings.where((b) => b != null).cast<Map<String, dynamic>>().toList();

      if (!mounted || _isDisposed) return;
      setState(() {
        _historyBookings = validBookings;
        _filteredHistoryBookings = List.from(validBookings);
        _isHistoryLoading = false;
      });
    } catch (e) {
      print('Error loading history bookings: $e');
      if (!mounted || _isDisposed) return;
      setState(() => _isHistoryLoading = false);
    }
  }

  // ─── Filters ──────────────────────────────────────────────────────────────
  void _applyFilters() {
    if (!mounted || _isDisposed) return;
    List<Map<String, dynamic>> result = List.from(_bookings);

    if (selectedStatuses.isNotEmpty) {
      result = result.where((e) {
        final status = e['status'] as String;
        final isCancellationRequest = e['cancellationRequested'] == true;

        if (status == 'APPROVAL_3') {
          return isCancellationRequest && selectedStatuses.contains('APPROVAL_3');
        }
        return selectedStatuses.contains(status);
      }).toList();
    }

    if (sortOrder == 'terbaru') {
      result.sort((a, b) {
        final aDate = a['createdAt'] as DateTime?;
        final bDate = b['createdAt'] as DateTime?;
        return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
      });
    } else {
      result.sort((a, b) {
        final aDate = a['createdAt'] as DateTime?;
        final bDate = b['createdAt'] as DateTime?;
        return (aDate ?? DateTime(1970)).compareTo(bDate ?? DateTime(1970));
      });
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _filteredBookings = result;
      });
    }
  }

  void _applyHistoryFilters() {
    if (!mounted || _isDisposed) return;
    List<Map<String, dynamic>> result = List.from(_historyBookings);

    if (sortOrder == 'terbaru') {
      result.sort((a, b) {
        final aDate = a['tanggal'] as DateTime?;
        final bDate = b['tanggal'] as DateTime?;
        return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
      });
    } else {
      result.sort((a, b) {
        final aDate = a['tanggal'] as DateTime?;
        final bDate = b['tanggal'] as DateTime?;
        return (aDate ?? DateTime(1970)).compareTo(bDate ?? DateTime(1970));
      });
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _filteredHistoryBookings = result;
      });
    }
  }

  void _resetFilters() {
    if (!mounted || _isDisposed) return;
    setState(() {
      selectedStatuses.clear();
      startDate = null;
      endDate = null;
      _setDefaultFilters();
    });
    _applyFilters();
  }

  // ─── Dialog filter ────────────────────────────────────────────────────────
  Future<void> _showFilterDialog(BuildContext context) async {
    final tempStatuses = List<String>.from(selectedStatuses);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Status'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: statusOptions.map((status) {
                      final isSelected = tempStatuses.contains(status);
                      return FilterChip(
                        label: Text(_getStatusText(status)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              tempStatuses.add(status);
                            } else {
                              tempStatuses.remove(status);
                            }
                          });
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: _getStatusColor(status).withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? _getStatusColor(status) : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        checkmarkColor: _getStatusColor(status),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempStatuses.clear();
                  });
                },
                child: Text(
                  'Reset',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'statuses': tempStatuses,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                ),
                child: const Text('Terapkan'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted && !_isDisposed) {
      setState(() {
        selectedStatuses = List<String>.from(result['statuses']);
      });
      _applyFilters();
    }
  }

  // ─── Approval logic ───────────────────────────────────────────────────────
  Future<void> _approveBooking(Map<String, dynamic> booking) async {
    if (!mounted || _isDisposed) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          color: Colors.blue.shade700,
        ),
      ),
    );

    try {
      String currentStatus = booking['status'];
      String newStatus;
      String actionText;

      final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');

      if (widget.role == 'user' && isManagerDivisi) {
        if (currentStatus != 'SUBMITTED') {
          throw Exception('Hanya dapat menyetujui peminjaman dengan status SUBMITTED');
        }
        newStatus = 'APPROVAL_1';
        actionText = 'Disetujui Manager Divisi';
      } else if (widget.role == 'operator') {
        if (currentStatus != 'APPROVAL_1') {
          throw Exception('Hanya dapat menyetujui peminjaman dengan status APPROVAL_1');
        }

        final vehicleId = booking['vehicleId'];
        if (vehicleId == null || vehicleId.toString().isEmpty) {
          if (mounted && !_isDisposed) Navigator.pop(context);
          if (mounted && !_isDisposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Kendaraan belum dipilih. Buka detail untuk memilih kendaraan terlebih dahulu'),
                backgroundColor: Colors.orange.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        final dynamic rawWaktuPinjam = booking['waktuPinjam'];
        final dynamic rawWaktuKembali = booking['waktuKembali'];

        if (rawWaktuPinjam == null || rawWaktuKembali == null) {
          if (mounted && !_isDisposed) Navigator.pop(context);
          if (mounted && !_isDisposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Data waktu peminjaman tidak valid, hubungi admin'),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        final DateTime waktuPinjam = rawWaktuPinjam is Timestamp
            ? rawWaktuPinjam.toDate()
            : rawWaktuPinjam as DateTime;
        final DateTime waktuKembali = rawWaktuKembali is Timestamp
            ? rawWaktuKembali.toDate()
            : rawWaktuKembali as DateTime;

        print('🔍 Cek konflik untuk vehicleId: $vehicleId');
        print('🕐 Waktu pinjam: $waktuPinjam — Waktu kembali: $waktuKembali');

        final conflictSnapshot = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('vehicleId', isEqualTo: vehicleId)
            .where('status', whereIn: ['APPROVAL_2', 'APPROVAL_3', 'ON_GOING'])
            .get();

        print('📋 Jumlah booking konflik potensial: ${conflictSnapshot.docs.length}');

        bool adaKonflik = false;
        String? konflikDengan;

        for (var doc in conflictSnapshot.docs) {
          if (doc.id == booking['bookingId']) continue;

          final data = doc.data();
          final dynamic otherRawStart = data['waktuPinjam'];
          final dynamic otherRawEnd = data['waktuKembali'];

          if (otherRawStart == null || otherRawEnd == null) continue;

          final DateTime otherStart = otherRawStart is Timestamp
              ? otherRawStart.toDate()
              : otherRawStart as DateTime;
          final DateTime otherEnd = otherRawEnd is Timestamp
              ? otherRawEnd.toDate()
              : otherRawEnd as DateTime;

          print('   Cek dengan booking ${doc.id}: $otherStart — $otherEnd');

          final bool isBentrok = waktuPinjam.isBefore(otherEnd) && waktuKembali.isAfter(otherStart);
          print('   Bentrok? $isBentrok');

          if (isBentrok) {
            adaKonflik = true;
            konflikDengan = data['namaPeminjam'] ?? doc.id;
            break;
          }
        }

        if (adaKonflik) {
          if (mounted && !_isDisposed) Navigator.pop(context);
          if (mounted && !_isDisposed) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.directions_car_outlined, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    const Flexible(child: Text('Kendaraan Tidak Tersedia')),
                  ],
                ),
                content: Text(
                  'Kendaraan yang dialokasikan sudah disetujui '
                  '${konflikDengan != null ? "untuk $konflikDengan " : ""}'
                  'pada waktu yang sama.\n\n'
                  'Buka halaman detail untuk mengganti kendaraan terlebih dahulu.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mengerti'),
                  ),
                ],
              ),
            );
          }
          return;
        }

        newStatus = 'APPROVAL_2';
        actionText = 'Diverifikasi Operator';
      } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
        if (currentStatus != 'APPROVAL_2') {
          throw Exception('Hanya dapat menyetujui peminjaman dengan status APPROVAL_2');
        }
        newStatus = 'APPROVAL_3';
        actionText = 'Disetujui Manager Umum';
      } else {
        throw Exception('Role tidak memiliki izin untuk approval');
      }

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(booking['bookingId'])
          .update({
        'status': newStatus,
        'updatedAt': Timestamp.now(),
        'lastApprovalBy': widget.userName,
        'lastApprovalRole': widget.role,
        'lastApprovalJabatan': _userJabatan,
      });

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(booking['bookingId'])
          .collection('approval_history')
          .add({
        'action': 'APPROVED',
        'oldStatus': currentStatus,
        'newStatus': newStatus,
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'actionJabatan': _userJabatan,
        'userId': widget.userId,
        'timestamp': Timestamp.now(),
        'note': '$actionText oleh ${widget.userName}',
      });

      if (mounted && !_isDisposed) Navigator.pop(context);

      if (newStatus == 'APPROVAL_1') {
        ApprovalNotificationService.sendApprovalNotificationToOperator(
          bookingId: booking['bookingId'],
          bookingData: booking['bookingData'] ?? {},
        ).then((s) => print(s ? '✅ Notif Operator terkirim' : '❌ Gagal notif Operator'))
         .catchError((e) => print('❌ Error: $e'));
      } else if (newStatus == 'APPROVAL_2') {
        ApprovalNotificationService.sendApprovalNotificationToManagerUmum(
          bookingId: booking['bookingId'],
          bookingData: booking['bookingData'] ?? {},
        ).then((s) => print(s ? '✅ Notif Manager Umum terkirim' : '❌ Gagal'))
         .catchError((e) => print('❌ Error: $e'));
      } else if (newStatus == 'APPROVAL_3') {
        ApprovalNotificationService.sendApprovedNotificationToPeminjam(
          bookingId: booking['bookingId'],
          bookingData: booking['bookingData'] ?? {},
        ).then((s) => print(s ? '✅ Notif peminjam terkirim' : '❌ Gagal'))
         .catchError((e) => print('❌ Error: $e'));
      }

      await _loadBookings();

      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Peminjaman berhasil disetujui'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted && !_isDisposed) Navigator.pop(context);
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyetujui: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rejectBooking(Map<String, dynamic> booking, String reason) async {
    if (!mounted || _isDisposed) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          color: Colors.blue.shade700,
        ),
      ),
    );

    try {
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(booking['bookingId'])
          .update({
        'status': 'CANCELLED',
        'rejectionReason': reason,
        'rejectedBy': widget.userName,
        'rejectedRole': widget.role,
        'rejectedJabatan': _userJabatan,
        'updatedAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(booking['bookingId'])
          .collection('approval_history')
          .add({
        'action': 'REJECTED',
        'oldStatus': booking['status'],
        'newStatus': 'CANCELLED',
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'actionJabatan': _userJabatan,
        'timestamp': Timestamp.now(),
        'note': 'Ditolak oleh ${widget.userName} (${widget.role})',
        'reason': reason,
        'userId': widget.userId,
      });

      if (mounted && !_isDisposed) Navigator.pop(context);
      ApprovalNotificationService.sendRejectedNotificationToPeminjam(
        bookingId: booking['bookingId'],
        bookingData: booking['bookingData'] ?? {},
        rejectedBy: widget.userName,
        reason: reason,
      ).then((s) => print(s ? '✅ Notif penolakan terkirim' : '❌ Gagal'))
       .catchError((e) => print('❌ Error: $e'));

      await _loadBookings();

      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Peminjaman berhasil ditolak'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted && !_isDisposed) Navigator.pop(context);
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _approveCancellationRequest(Map<String, dynamic> item) async {
    if (!mounted || _isDisposed) return;
    try {
      if (mounted && !_isDisposed) setState(() => _isLoading = true);

      final requestedBy = item['cancellationRequestedBy'] ?? '';
      final reason = item['cancellationRequestReason'] ?? '';

      final bookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(item['bookingId'])
          .get();
      final bookingData = {'id': bookingDoc.id, ...bookingDoc.data()!};

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(item['bookingId'])
          .update({
        'status': 'CANCELLED',
        'cancellationReason': reason,
        'cancelledBy': requestedBy,
        'cancelledByRole': 'operator',
        'approvedCancellationBy': widget.userName,
        'approvedCancellationByRole': 'admin',
        'approvedCancellationAt': Timestamp.now(),
        'cancellationRequested': false,
        'updatedAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(item['bookingId'])
          .collection('approval_history')
          .add({
        'action': 'CANCELLATION_APPROVED',
        'oldStatus': 'APPROVAL_3',
        'newStatus': 'CANCELLED',
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'userId': widget.userId,
        'timestamp': Timestamp.now(),
        'note': '${widget.userName} menyetujui request pembatalan dari $requestedBy',
        'reason': reason,
      });

      await ApprovalNotificationService.sendUnilateralCancellationToPeminjam(
        bookingId: item['bookingId'],
        bookingData: bookingData,
        cancelledBy: requestedBy,
        cancelledByRole: 'operator',
        reason: reason,
      );

      await _loadBookings();

      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pembatalan berhasil disetujui'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted && !_isDisposed) setState(() => _isLoading = false);
    }
  }

  void _navigateToDetail(Map<String, dynamic> item, bool isHistory) {
    if (!mounted || _isDisposed) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPeminjamanPage(
          data: {
            'id': item['bookingId'],
            'nama': item['peminjam'],
            'divisi': item['divisi'],
            'keperluan': item['keperluan'],
            'nomor': item['nomorSurat'],
            'alasan': item['alasan'],
            'tujuan': item['tujuan'],
            'kendaraan': item['kendaraan'],
            'platNomor': item['platNomor'],
            'tglPinjam': item['tglPinjam'],
            'jamPinjam': item['jamPinjam'],
            'tglKembali': item['tglKembali'],
            'jamKembali': item['jamKembali'],
            'status': item['status'],
            'waktuPinjam': item['waktuPinjam'],
            'waktuKembali': item['waktuKembali'],
            'vehicleId': item['vehicleId'],
          },
          approvalStep: _getApprovalStep(item['status']),
          isApprovalMode: !isHistory && _canApprove(item['status']),
          userName: widget.userName,
          userId: widget.userId,
          role: widget.role,
          userDivision: widget.userDivision,
        ),
      ),
    ).then((result) {
      if (result == true && mounted && !_isDisposed) {
        if (isHistory) {
          _loadHistoryBookings();
        } else {
          _loadBookings();
        }
      }
    });
  }

  // ─── Helper methods ───────────────────────────────────────────────────────
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
        return Colors.blue;
      case 'APPROVAL_1':
        return Colors.blue.shade700;
      case 'APPROVAL_2':
        return Colors.orange;
      case 'APPROVAL_3':
        return Colors.purple;
      case 'ON_GOING':
        return Colors.green;
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
        return Icons.access_time_rounded;
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

  bool _canApprove(String status) {
    final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');

    if (widget.role == 'user' && isManagerDivisi) {
      return status == 'SUBMITTED';
    } else if (widget.role == 'operator') {
      return status == 'APPROVAL_1';
    } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
      return status == 'APPROVAL_2';
    }
    return false;
  }

  int _getApprovalStep(String status) {
    switch (status) {
      case 'SUBMITTED':
        return 0;
      case 'APPROVAL_1':
        return 1;
      case 'APPROVAL_2':
        return 2;
      case 'APPROVAL_3':
        return 3;
      case 'ON_GOING':
        return 5;
      case 'DONE':
        return 6;
      default:
        return 0;
    }
  }

  // ===== PERUBAHAN: logika akses dengan operatorType =====
  bool _hasAccess() {
    if (widget.role == 'admin') return true;
    if (widget.role == 'manager_umum') return true;
    if (widget.role == 'user') {
      final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
      return isManagerDivisi;
    }
    if (widget.role == 'operator') {
      // null (operator umum) → boleh, 'kendaraan' → boleh, 'ruang_meeting' → tidak boleh
      final opType = widget.operatorType;
      return opType == null || opType == 'kendaraan';
    }
    return false;
  }

  // ===== PERUBAHAN: pesan akses ditolak =====
  String _getAccessDeniedMessage() {
    if (widget.role == 'operator' && widget.operatorType == 'ruang_meeting') {
      return 'Anda adalah Operator Ruang Meeting.\nSilakan gunakan menu Approval Ruang Meeting.';
    }
    return 'Anda tidak memiliki izin untuk mengakses halaman approval';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess()) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.grey.shade700,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Approval Kendaraan',
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
              Icon(
                Icons.block,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Akses Ditolak',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getAccessDeniedMessage(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.grey.shade700,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Approval Kendaraan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Menunggu Approval'),
            Tab(text: 'Riwayat Approval'),
          ],
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blue.shade700,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWaitingApprovalTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildWaitingApprovalTab() {
    final waitingCount = _bookings
        .where((e) => _canApprove(e['status']))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Stats
        Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                label: 'Total',
                value: _bookings.length.toString(),
                icon: Icons.list_alt_rounded,
                color: Colors.blue,
              ),
              _buildStatItem(
                label: 'Menunggu',
                value: waitingCount.toString(),
                icon: Icons.access_time_rounded,
                color: Colors.orange,
              ),
            ],
          ),
        ),

        // Filter Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showFilterDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey.shade700,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(
                    Icons.filter_alt_outlined,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  label: Text(
                    selectedStatuses.isNotEmpty ? 'Filter Aktif' : 'Filter',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: selectedStatuses.isNotEmpty ? _resetFilters : null,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: selectedStatuses.isNotEmpty
                      ? Colors.blue.shade700
                      : Colors.grey.shade400,
                ),
                tooltip: 'Reset Filter',
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    sortOrder = sortOrder == 'terbaru' ? 'terlama' : 'terbaru';
                  });
                  _applyFilters();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey.shade700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                icon: Icon(
                  sortOrder == 'terbaru' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                label: Text(sortOrder == 'terbaru' ? 'Terbaru' : 'Terlama'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // List Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  () {
                    final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
                    if (widget.role == 'user' && isManagerDivisi) {
                      return 'Peminjaman Menunggu Approval Divisi ${widget.userDivision}';
                    } else if (widget.role == 'operator') {
                      return 'Peminjaman Menunggu Verifikasi Operator';
                    } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
                      return 'Peminjaman Menunggu Approval Manager Umum';
                    }
                    return 'Peminjaman Menunggu Approval';
                  }(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_filteredBookings.length} item',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),

        // Data List
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Colors.blue.shade700,
                  ),
                )
              : _filteredBookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada data',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      color: Colors.blue.shade700,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: _filteredBookings.length,
                        itemBuilder: (context, index) {
                          final item = _filteredBookings[index];
                          return _buildApprovalCard(item, false);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Approval',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daftar peminjaman yang pernah Anda approve atau tolak',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Sort Control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                sortOrder = sortOrder == 'terbaru' ? 'terlama' : 'terbaru';
              });
              _applyHistoryFilters();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey.shade700,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            icon: Icon(
              sortOrder == 'terbaru' ? Icons.arrow_downward : Icons.arrow_upward,
              color: Colors.grey.shade600,
              size: 20,
            ),
            label: Text(sortOrder == 'terbaru' ? 'Terbaru' : 'Terlama'),
          ),
        ),

        const SizedBox(height: 16),

        // List Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
              const SizedBox(width: 12),
              Text(
                'Riwayat Approval Anda',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const Spacer(),
              Text(
                '${_filteredHistoryBookings.length} item',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),

        // History List
        Expanded(
          child: _isHistoryLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Colors.blue.shade700,
                  ),
                )
              : _filteredHistoryBookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada riwayat',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Riwayat approval Anda akan muncul di sini',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistoryBookings,
                      color: Colors.blue.shade700,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: _filteredHistoryBookings.length,
                        itemBuilder: (context, index) {
                          final item = _filteredHistoryBookings[index];
                          return _buildApprovalCard(item, true);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> item, bool isHistory) {
    final status = item['status'];
    final statusText = item['statusText'];
    final statusColor = _getStatusColor(status);
    final canApprove = !isHistory && _canApprove(status);
    final canReject = !isHistory && _canApprove(status);
    final historyAction = item['historyAction'] ?? 'APPROVED';
    final historyNote = item['historyNote'] ?? '';
    final historyOldStatus = item['historyOldStatus'] ?? '';
    final historyNewStatus = item['historyNewStatus'] ?? '';
    final isCancellationRequest = item['cancellationRequested'] == true;

    Color historyBadgeColor = statusColor;
    String historyBadgeText = statusText;
    Color displayColor = isCancellationRequest ? Colors.red.shade700 : _getStatusColor(status);
    String displayText = isCancellationRequest ? 'Request Pembatalan' : item['statusText'];
    IconData displayIcon = isCancellationRequest ? Icons.cancel_outlined : _getStatusIcon(status);

    if (isHistory) {
      if (historyAction == 'REJECTED') {
        historyBadgeColor = Colors.red;
        historyBadgeText = 'Ditolak';
      } else if (historyAction == 'APPROVED') {
        historyBadgeColor = Colors.green;
        historyBadgeText = 'Disetujui';
      } else if (historyAction == 'VEHICLE_CHANGED') {
        historyBadgeColor = Colors.orange;
        historyBadgeText = 'Kendaraan Diubah';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(item, isHistory),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (isHistory ? historyBadgeColor : statusColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isHistory && historyAction == 'REJECTED'
                        ? Icons.cancel
                        : isHistory && historyAction == 'APPROVED'
                            ? Icons.check_circle
                            : _getStatusIcon(status),
                    color: isHistory ? historyBadgeColor : statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['bookingId'].substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item['kendaraan']} - ${item['platNomor']}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(item['tanggal'])} • ${item['jam']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isHistory ? historyBadgeColor : displayColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isHistory ? historyBadgeColor : displayColor).withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    isHistory ? historyBadgeText : displayText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isHistory ? historyBadgeColor : displayColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // History note dengan info lebih detail
            if (isHistory && historyNote.isNotEmpty)
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        historyAction == 'REJECTED'
                            ? Icons.close
                            : historyAction == 'APPROVED'
                                ? Icons.check
                                : Icons.info_outline,
                        size: 16,
                        color: historyAction == 'REJECTED'
                            ? Colors.red
                            : historyAction == 'APPROVED'
                                ? Colors.green
                                : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              historyNote,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            if (historyAction == 'REJECTED' && item['historyReason'] != null && item['historyReason'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 14,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Alasan: ${item['historyReason']}',
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
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Detail Peminjaman
            _buildDetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Peminjam',
              value: item['peminjam'],
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.business_rounded,
              label: 'Divisi',
              value: item['divisi'],
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.directions_car_rounded,
              label: 'Kendaraan',
              value: '${item['kendaraan']} (${item['platNomor']})',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.location_on_rounded,
              label: 'Tujuan',
              value: item['tujuan'],
            ),

            if (isCancellationRequest && !isHistory) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Pembatalan dari Operator ${item['cancellationRequestedBy']}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alasan: ${item['cancellationRequestReason']}',
                            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (!isHistory && (canApprove || canReject || isCancellationRequest))
              _buildActionButtons(item, canApprove, canReject),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> item, bool canApprove, bool canReject) {
    final isCancellationRequest = item['cancellationRequested'] == true;

    if (isCancellationRequest && (widget.role == 'admin' || widget.role == 'manager_umum')) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _navigateToDetail(item, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Lihat Detail', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showApproveCancellationDialog(context, item),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Setujui Pembatalan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _navigateToDetail(item, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              side: BorderSide(color: Colors.blue.shade700, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Lihat Detail'),
          ),
        ),
        if (canApprove) ...[
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showApprovalConfirmationDialog(context, item),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Setujui'),
            ),
          ),
        ],
        if (canReject) ...[
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showRejectDialog(context, item),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Tolak'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showApproveCancellationDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 12),
            const Text('Setujui Pembatalan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operator ${item['cancellationRequestedBy']} meminta pembatalan dengan alasan:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item['cancellationRequestReason'] ?? '-',
                style: TextStyle(color: Colors.red.shade700, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Menyetujui akan membatalkan peminjaman dan mengirim notifikasi ke peminjam.'),
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
              await _approveCancellationRequest(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Setujui Pembatalan'),
          ),
        ],
      ),
    );
  }

  void _showApprovalConfirmationDialog(BuildContext context, Map<String, dynamic> item) {
    String approvalText = '';
    final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');

    if (widget.role == 'user' && isManagerDivisi) {
      approvalText = 'menyetujui sebagai Manager Divisi';
    } else if (widget.role == 'operator') {
      approvalText = 'memverifikasi sebagai Operator';
    } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
      approvalText = 'menyetujui sebagai Manager Umum';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 28,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Konfirmasi Approval',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apakah Anda yakin ingin $approvalText?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.red.shade200,
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _approveBooking(item);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Ya, Setujui'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, Map<String, dynamic> item) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 28,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tolak Peminjaman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan alasan penolakan:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'Contoh: Kendaraan tidak tersedia, jadwal bentrok, dll.',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.grey.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (reasonController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Harap masukkan alasan penolakan'),
                              backgroundColor: Colors.red.shade600,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        await _rejectBooking(item, reasonController.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Ya, Tolak'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) => reasonController.dispose());
  }
}