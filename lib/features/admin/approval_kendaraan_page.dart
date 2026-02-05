import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../vehicle/detail_peminjaman_page.dart';

class ApprovalKendaraanPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;
  final String userJabatan;

  const ApprovalKendaraanPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
    required this.userJabatan,
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
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserJabatan() async {
    if (widget.userJabatan.isNotEmpty) {
      setState(() {
        _userJabatan = widget.userJabatan;
      });
    } else {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        
        if (userDoc.exists) {
          setState(() {
            _userJabatan = userDoc.data()?['jabatan'] ?? 'Staff';
          });
        }
      } catch (e) {
        print('Error fetching user jabatan: $e');
        setState(() {
          _userJabatan = 'Staff';
        });
      }
    }
    
    _setDefaultFilters();
    _loadBookings();
  }

  void _setDefaultFilters() {
    // Filter default untuk approval yang perlu ditindak lanjuti
    selectedStatuses.clear();
    
    final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
    
    if (widget.role == 'admin' || widget.role == 'manager_umum') {
      selectedStatuses = ['APPROVAL_2'];
    } else if (widget.role == 'user' && isManagerDivisi) {
      selectedStatuses = ['SUBMITTED'];
    } else if (widget.role == 'operator') {
      selectedStatuses = ['APPROVAL_1'];
    }
  }

  // Load bookings yang perlu approval
  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      QuerySnapshot snapshot;
      final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
      
      if (widget.role == 'admin' || widget.role == 'manager_umum') {
        snapshot = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('status', isEqualTo: 'APPROVAL_2')
            .orderBy('createdAt', descending: true)
            .get();
      } else if (widget.role == 'user' && isManagerDivisi) {
        snapshot = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('divisi', isEqualTo: widget.userDivision)
            .where('status', isEqualTo: 'SUBMITTED')
            .orderBy('createdAt', descending: true)
            .get();
      } else if (widget.role == 'operator') {
        snapshot = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('status', isEqualTo: 'APPROVAL_1')
            .orderBy('createdAt', descending: true)
            .get();
      } else {
        setState(() {
          _bookings = [];
          _filteredBookings = [];
          _isLoading = false;
        });
        return;
      }

      final bookings = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        
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
        };
      }));

      setState(() {
        _bookings = bookings;
        _applyFilters();
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading bookings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load history approval untuk user ini
// Load history approval untuk user ini
Future<void> _loadHistoryBookings() async {
  setState(() {
    _isHistoryLoading = true;
  });
  
  try {
    // Query untuk mengambil history approval berdasarkan user yang melakukan approval
    final approvalHistoryQuery = await FirebaseFirestore.instance
        .collectionGroup('approval_history')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('timestamp', descending: true)
        .get();

    final bookingIds = approvalHistoryQuery.docs.map((doc) {
      final path = doc.reference.path;
      final parts = path.split('/');
      return parts[1]; // vehicle_bookings/{bookingId}/approval_history/{docId}
    }).toSet();

    if (bookingIds.isEmpty) {
      setState(() {
        _historyBookings = [];
        _filteredHistoryBookings = [];
        _isHistoryLoading = false;
      });
      return;
    }

    // Ambil data booking berdasarkan bookingIds
    final bookings = await Future.wait(bookingIds.map((bookingId) async {
      try {
        final bookingDoc = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .doc(bookingId)
            .get();

        if (!bookingDoc.exists) return null;

        final data = bookingDoc.data() as Map<String, dynamic>;
        
        // Ambil data kendaraan
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

        // ✅ PERBAIKAN: Ambil SEMUA history approval untuk booking ini oleh user ini
        final historyDocs = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .doc(bookingId)
            .collection('approval_history')
            .where('userId', isEqualTo: widget.userId)
            .orderBy('timestamp', descending: true)
            .get();

        // ✅ Ambil history approval terakhir yang dilakukan user
        final historyData = historyDocs.docs.isNotEmpty ? 
            historyDocs.docs.first.data() : null;

        final waktuPinjam = data['waktuPinjam'] is Timestamp
            ? (data['waktuPinjam'] as Timestamp).toDate()
            : null;
        final waktuKembali = data['waktuKembali'] is Timestamp
            ? (data['waktuKembali'] as Timestamp).toDate()
            : null;
        final createdAt = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now();

        // ✅ Gunakan timestamp dari history untuk sorting
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
          'historyReason': historyData?['reason'] ?? '', // ✅ Untuk rejection reason
          'tanggal': historyTimestamp, // ✅ Gunakan timestamp history
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

    setState(() {
      _historyBookings = validBookings;
      _filteredHistoryBookings = List.from(validBookings);
      _isHistoryLoading = false;
    });

  } catch (e) {
    print('Error loading history bookings: $e');
    setState(() {
      _isHistoryLoading = false;
    });
  }
}

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_bookings);

    // Filter sederhana: hanya status
    if (selectedStatuses.isNotEmpty) {
      result = result.where((e) => selectedStatuses.contains(e['status'])).toList();
    }

    // Sort berdasarkan tanggal
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

    setState(() {
      _filteredBookings = result;
    });
  }

void _applyHistoryFilters() {
  List<Map<String, dynamic>> result = List.from(_historyBookings);

  // ✅ Sort berdasarkan historyTimestamp (waktu approval dilakukan)
  if (sortOrder == 'terbaru') {
    result.sort((a, b) {
      final aDate = a['tanggal'] as DateTime?; // sudah diset ke historyTimestamp
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

  setState(() {
    _filteredHistoryBookings = result;
  });
}

  void _resetFilters() {
    setState(() {
      selectedStatuses.clear();
      startDate = null;
      endDate = null;
      _setDefaultFilters();
      _applyFilters();
    });
  }

  // Filter sederhana - hanya status
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

    if (result != null) {
      setState(() {
        selectedStatuses = List<String>.from(result['statuses']);
      });
      _applyFilters();
    }
  }

  // Approve booking
  Future<void> _approveBooking(Map<String, dynamic> booking) async {
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

      if (mounted) Navigator.pop(context);
      await _loadBookings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Peminjaman berhasil disetujui'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
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

  // Reject booking
  Future<void> _rejectBooking(Map<String, dynamic> booking, String reason) async {
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

      if (mounted) Navigator.pop(context);
      await _loadBookings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Peminjaman berhasil ditolak'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
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

  void _navigateToDetail(Map<String, dynamic> item, bool isHistory) {
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
            'vehicleId': item['vehicleId'], // ✅ Tambahkan ini
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
      if (result == true) {
        if (isHistory) {
          _loadHistoryBookings();
        } else {
          _loadBookings();
        }
      }
    });
  }

  // Helper methods
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

  bool _hasAccess() {
    if (widget.role == 'admin') return true;
    if (widget.role == 'operator') return true;
    if (widget.role == 'manager_umum') return true;
    
    if (widget.role == 'user') {
      final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
      return isManagerDivisi;
    }
    
    return false;
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
                'Anda tidak memiliki izin untuk mengakses halaman approval',
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
          // Tab 1: Menunggu Approval
          _buildWaitingApprovalTab(),
          // Tab 2: Riwayat Approval
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
                    _applyFilters();
                  });
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
                _applyHistoryFilters();
              });
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

  // ✅ Tentukan warna badge berdasarkan action history
  Color historyBadgeColor = statusColor;
  String historyBadgeText = statusText;
  
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isHistory ? historyBadgeColor : statusColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isHistory ? historyBadgeColor : statusColor).withOpacity(0.2),
                  ),
                ),
                child: Text(
                  isHistory ? historyBadgeText : statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isHistory ? historyBadgeColor : statusColor,
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

          // ✅ History note dengan info lebih detail
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
                          // ✅ Tampilkan alasan jika ditolak
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

          const SizedBox(height: 16),

          // Tombol Aksi (hanya untuk yang menunggu approval)
          if (!isHistory && (canApprove || canReject))
            _buildActionButtons(item, canApprove, canReject),
        ],
      ),
    ),
  );
}

  Widget _buildActionButtons(Map<String, dynamic> item, bool canApprove, bool canReject) {
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
    );
  }
}