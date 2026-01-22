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

class _ApprovalKendaraanPageState extends State<ApprovalKendaraanPage> {
  String sortOrder = 'terbaru';
  DateTime? startDate;
  DateTime? endDate;
  List<String> selectedStatuses = [];
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  String? _userJabatan; // Untuk menyimpan jabatan user
  
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
    _fetchUserJabatan(); // Ambil jabatan user terlebih dahulu
  }

  // Ambil jabatan user dari Firestore jika tidak ada di widget
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
    
    // Setelah dapat jabatan, set filter dan load bookings
    _setDefaultFilters();
    _loadBookings();
  }

  // Set filter default berdasarkan role dan jabatan
  void _setDefaultFilters() {
    // ✅ FIX: Manager Divisi (role user dengan jabatan Manager) melihat SUBMITTED
    if (widget.role == 'admin') {
      // Manager Umum melihat APPROVAL_2
      selectedStatuses = ['APPROVAL_2'];
    } else if (widget.role == 'user' && _userJabatan != null) {
      // ✅ Cek apakah Manager Divisi
      final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
      if (isManagerDivisi) {
        selectedStatuses = ['SUBMITTED']; // Manager Divisi melihat SUBMITTED
      } else {
        selectedStatuses = []; // Staff tidak bisa approve
      }
    } else if (widget.role == 'operator') {
      selectedStatuses = ['APPROVAL_1'];
    } else if (widget.role == 'manager_umum') {
      selectedStatuses = ['APPROVAL_2'];
    } else {
      selectedStatuses = [];
    }
  }

  // Load bookings dari Firestore - LOGIC BARU
Future<void> _loadBookings() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    QuerySnapshot snapshot;
    
    // ✅ Cek apakah Manager Divisi
    final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
    
    if (widget.role == 'admin') {
      // ✅ Admin (Manager Umum) melihat booking yang APPROVAL_2
      snapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', isEqualTo: 'APPROVAL_2')
          .orderBy('createdAt', descending: true)
          .get();
          
    } else if (widget.role == 'user' && isManagerDivisi) {
      // ✅ Manager Divisi melihat SUBMITTED dari divisinya
      snapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('divisi', isEqualTo: widget.userDivision)
          .where('status', isEqualTo: 'SUBMITTED')
          .orderBy('createdAt', descending: true)
          .get();
          
    } else if (widget.role == 'operator') {
      // Operator melihat semua booking yang APPROVAL_1
      snapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', isEqualTo: 'APPROVAL_1')
          .orderBy('createdAt', descending: true)
          .get();
          
    } else if (widget.role == 'manager_umum') {
      // Manager Umum melihat semua booking yang APPROVAL_2
      snapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', isEqualTo: 'APPROVAL_2')
          .orderBy('createdAt', descending: true)
          .get();
          
    } else {
      // Role tidak memiliki akses approval
      setState(() {
        _bookings = [];
        _filteredBookings = [];
        _isLoading = false;
      });
      return;
    }

      final bookings = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        
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

        // Format data untuk UI
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

  // Apply filters
  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_bookings);

    // Filter berdasarkan status
    if (selectedStatuses.isNotEmpty) {
      result = result.where((e) => selectedStatuses.contains(e['status'])).toList();
    }

    // Filter berdasarkan tanggal (createdAt)
    if (startDate != null && endDate != null) {
      result = result.where((e) {
        final itemDate = e['createdAt'] as DateTime?;
        if (itemDate == null) return false;
        
        final normalizedDate = DateTime(itemDate.year, itemDate.month, itemDate.day);
        final normalizedStart = DateTime(startDate!.year, startDate!.month, startDate!.day);
        final normalizedEnd = DateTime(endDate!.year, endDate!.month, endDate!.day);
        
        return (normalizedDate.isAfter(normalizedStart) || normalizedDate.isAtSameMomentAs(normalizedStart)) &&
               (normalizedDate.isBefore(normalizedEnd) || normalizedDate.isAtSameMomentAs(normalizedEnd));
      }).toList();
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

  // Reset filters
  void _resetFilters() {
    setState(() {
      selectedStatuses.clear();
      startDate = null;
      endDate = null;
      _setDefaultFilters();
      _applyFilters();
    });
  }

  // Show filter dialog
  Future<void> _showFilterDialog(BuildContext context) async {
    final tempStatuses = List<String>.from(selectedStatuses);
    DateTime? tempStartDate = startDate;
    DateTime? tempEndDate = endDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Data'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 24),
                  Text(
                    'Periode Tanggal Pengajuan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() => tempStartDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dari',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tempStartDate != null
                                      ? DateFormat('dd/MM/yyyy').format(tempStartDate!)
                                      : 'Pilih tanggal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() => tempEndDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sampai',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tempEndDate != null
                                      ? DateFormat('dd/MM/yyyy').format(tempEndDate!)
                                      : 'Pilih tanggal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
                    tempStartDate = null;
                    tempEndDate = null;
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
                    'startDate': tempStartDate,
                    'endDate': tempEndDate,
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
        startDate = result['startDate'];
        endDate = result['endDate'];
      });
      _applyFilters();
    }
  }

  // Show sort dialog
  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Urutkan Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio(
                value: 'terbaru',
                groupValue: sortOrder,
                onChanged: (value) {
                  setState(() {
                    sortOrder = value.toString();
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
              title: const Text('Tanggal Terbaru'),
            ),
            ListTile(
              leading: Radio(
                value: 'terlama',
                groupValue: sortOrder,
                onChanged: (value) {
                  setState(() {
                    sortOrder = value.toString();
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
              title: const Text('Tanggal Terlama'),
            ),
          ],
        ),
      ),
    );
  }

  // Approve booking - LOGIC BARU dengan jabatan
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
      
      // ✅ Cek apakah Manager Divisi
      final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
      
      // Tentukan status baru berdasarkan role dan jabatan
      if (widget.role == 'user' && isManagerDivisi) {
        // ✅ Manager Divisi mengubah SUBMITTED → APPROVAL_1
        if (currentStatus != 'SUBMITTED') {
          throw Exception('Hanya dapat menyetujui peminjaman dengan status SUBMITTED');
        }
        newStatus = 'APPROVAL_1';
        actionText = 'Disetujui Manager Divisi';
        
      } else if (widget.role == 'operator') {
        // Operator mengubah APPROVAL_1 → APPROVAL_2
        if (currentStatus != 'APPROVAL_1') {
          throw Exception('Hanya dapat menyetujui peminjaman dengan status APPROVAL_1');
        }
        newStatus = 'APPROVAL_2';
        actionText = 'Diverifikasi Operator';
        
      } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
        // ✅ Admin/Manager Umum mengubah APPROVAL_2 → APPROVAL_3
        if (currentStatus != 'APPROVAL_2') {
          throw Exception('Hanya dapat menyetujui peminjaman dengan status APPROVAL_2');
        }
        newStatus = 'APPROVAL_3';
        actionText = 'Disetujui Manager Umum';
        
      } else {
        throw Exception('Role tidak memiliki izin untuk approval');
      }

      // Update status di Firestore
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

      // Tambahkan ke riwayat approval
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
    // Show loading
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
      // Update status menjadi CANCELLED
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

      // Tambahkan ke riwayat approval
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
      });

      // Close loading
      if (mounted) Navigator.pop(context);

      // Refresh data
      await _loadBookings();

      // Show success message
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
      // Close loading
      if (mounted) Navigator.pop(context);
      
      // Show error
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

  // Get status text
  String _getStatusText(String status) {
    switch (status) {
      case 'SUBMITTED':
        return 'Menunggu Manager Divisi';
      case 'APPROVAL_1':
        return 'Menunggu Operator'; // ✅ Setelah Manager Divisi approve
      case 'APPROVAL_2':
        return 'Menunggu Manager Umum'; // ✅ Setelah Operator approve
      case 'APPROVAL_3':
        return 'Disetujui'; // ✅ Setelah Manager Umum approve
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

  // Get status color
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

  // Get status icon
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

  // Check if user can approve based on role, jabatan and status
bool _canApprove(String status) {
  // ✅ Cek apakah Manager Divisi
  final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
  
  if (widget.role == 'user' && isManagerDivisi) {
    return status == 'SUBMITTED'; // Manager Divisi approve SUBMITTED
  } else if (widget.role == 'operator') {
    return status == 'APPROVAL_1'; // Operator approve APPROVAL_1
  } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
    return status == 'APPROVAL_2'; // Manager Umum approve APPROVAL_2
  }
  
  return false;
}

  // Check if user can reject based on role, jabatan and status
  bool _canReject(String status) {
    return _canApprove(status); // Sama dengan canApprove
  }

  // Cek apakah user memiliki akses approval
  bool _hasAccess() {
    if (widget.role == 'admin') return true;
    if (widget.role == 'operator') return true;
    if (widget.role == 'manager_umum') return true;
    
    // ✅ Cek apakah Manager Divisi
    if (widget.role == 'user') {
      final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
      return isManagerDivisi;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Jika user tidak memiliki akses
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

    // Hitung statistik
    final totalCount = _bookings.length;
    final waitingCount = _bookings
        .where((e) => _canApprove(e['status']))
        .length;
    final processedCount = _bookings
        .where((e) => ['APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3'].contains(e['status']))
        .length;

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
      body: _isLoading || _userJabatan == null
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.blue.shade700,
              ),
            )
          : Column(
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
                        value: totalCount.toString(),
                        icon: Icons.list_alt_rounded,
                        color: Colors.blue,
                      ),
                      _buildStatItem(
                        label: 'Menunggu',
                        value: waitingCount.toString(),
                        icon: Icons.access_time_rounded,
                        color: Colors.orange,
                      ),
                      _buildStatItem(
                        label: 'Diproses',
                        value: processedCount.toString(),
                        icon: Icons.sync_rounded,
                        color: Colors.purple,
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
                            selectedStatuses.isNotEmpty || startDate != null
                                ? 'Filter Aktif'
                                : 'Filter',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: selectedStatuses.isNotEmpty || startDate != null
                            ? _resetFilters
                            : null,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: selectedStatuses.isNotEmpty || startDate != null
                              ? Colors.blue.shade700
                              : Colors.grey.shade400,
                        ),
                        tooltip: 'Reset Filter',
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showSortDialog(context),
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
                          Icons.sort_rounded,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        label: const Text('Urutkan'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Filter Status
                if (selectedStatuses.isNotEmpty || startDate != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter Aktif:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (selectedStatuses.isNotEmpty)
                              ...selectedStatuses.map((status) {
                                return Chip(
                                  label: Text(_getStatusText(status)),
                                  backgroundColor: _getStatusColor(status).withOpacity(0.1),
                                  labelStyle: TextStyle(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  deleteIcon: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: _getStatusColor(status),
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      selectedStatuses.remove(status);
                                      _applyFilters();
                                    });
                                  },
                                );
                              }).toList(),
                            if (startDate != null && endDate != null)
                              Chip(
                                label: Text(
                                  '${DateFormat('dd/MM/yyyy').format(startDate!)} - ${DateFormat('dd/MM/yyyy').format(endDate!)}',
                                ),
                                backgroundColor: Colors.green.shade100,
                                deleteIcon: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                                onDeleted: () {
                                  setState(() {
                                    startDate = null;
                                    endDate = null;
                                    _applyFilters();
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

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
                            // ✅ FIX: Gunakan _isManagerDivisi seperti di dashboard
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
                    )
                  ),

                  // Data List
                  Expanded(
                    child: _filteredBookings.isEmpty
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
                                const SizedBox(height: 8),
                                Text(
                                  // ✅ FIX: Gunakan _isManagerDivisi
                                  () {
                                    final isManagerDivisi = (_userJabatan ?? '').toLowerCase().contains('manager');
                                    
                                    if (widget.role == 'user' && isManagerDivisi) {
                                      return 'Tidak ada peminjaman yang menunggu approval dari divisi ${widget.userDivision}';
                                    } else if (widget.role == 'operator') {
                                      return 'Tidak ada peminjaman yang menunggu verifikasi operator';
                                    } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
                                      return 'Tidak ada peminjaman yang menunggu approval manager umum';
                                    }
                                    return 'Tidak ada peminjaman';
                                  }(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadBookings,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Muat Ulang'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
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
                                return _buildApprovalCard(item);
                              },
                            ),
                          ),
                  ),
              ],
            ),
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

  Widget _buildApprovalCard(Map<String, dynamic> item) {
  final status = item['status'];
  final statusText = item['statusText'];
  final statusColor = _getStatusColor(status);
  final statusIcon = _getStatusIcon(status);
  final canApprove = _canApprove(status);
  final canReject = _canReject(status);

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16), // DIKURANGI DARI 20
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
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['bookingId'].substring(0, 8).toUpperCase(),
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
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
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
        const SizedBox(height: 8),
        _buildDetailRow(
          icon: Icons.calendar_today_rounded,
          label: 'Waktu Pinjam',
          value: '${item['tglPinjam']} ${item['jamPinjam']}',
        ),
        const SizedBox(height: 8),
        _buildDetailRow(
          icon: Icons.calendar_today_rounded,
          label: 'Waktu Kembali',
          value: '${item['tglKembali']} ${item['jamKembali']}',
        ),

        const SizedBox(height: 16),

        // Tombol Aksi
        if (canApprove || canReject)
          _buildActionButtons(item, canApprove, canReject),
      ],
    ),
  );
}

  Widget _buildActionButtons(Map<String, dynamic> item, bool canApprove, bool canReject) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Jika lebar kurang dari 400, gunakan layout vertikal
        if (constraints.maxWidth < 400) {
          return Column(
            children: [
              // Tombol Lihat Detail
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
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
                          },
                          approvalStep: _getApprovalStep(item['status']),
                          isApprovalMode: canApprove || canReject,
                          userName: widget.userName,
                          userId: widget.userId,
                          role: widget.role,
                          userDivision: widget.userDivision,
                        ),
                      ),
                    );
                    if (result == true) {
                      await _loadBookings();
                    }
                  },
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      const Text('Lihat Detail'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Tombol Setujui (jika ada)
              if (canApprove) ...[
                SizedBox(
                  width: double.infinity,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        const Text('Setujui'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              // Tombol Tolak (jika ada)
              if (canReject) ...[
                SizedBox(
                  width: double.infinity,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        const Text('Tolak'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        }
        
        // Jika lebar cukup, gunakan layout horizontal
        else {
          return Row(
            children: [
              // Tombol Lihat Detail
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
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
                          },
                          approvalStep: _getApprovalStep(item['status']),
                          isApprovalMode: canApprove || canReject,
                          userName: widget.userName,
                          userId: widget.userId,
                          role: widget.role,
                          userDivision: widget.userDivision,
                        ),
                      ),
                    );
                    if (result == true) {
                      await _loadBookings();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          'Lihat Detail',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        const Flexible(
                          child: Text(
                            'Setujui',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        const Flexible(
                          child: Text(
                            'Tolak',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        }
      },
    );
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

  void _showApprovalConfirmationDialog(BuildContext context, Map<String, dynamic> item) {
    String approvalText = '';
    
    // ✅ Cek apakah Manager Divisi
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
              // Icon Konfirmasi
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
              
              // Judul Dialog
              Text(
                'Konfirmasi Approval',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Pesan Konfirmasi
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
              
              // Tombol Aksi
              Row(
                children: [
                  // Tombol Batal
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 6),
                          const Text('Batal'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Tombol Ya, Setujui
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          const Text('Ya, Setujui'),
                        ],
                      ),
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
              // Icon Konfirmasi
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
              
              // Judul Dialog
              Text(
                'Tolak Peminjaman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Pesan Konfirmasi
              Text(
                'Masukkan alasan penolakan:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Input Alasan
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
              
              // Tombol Aksi
              Row(
                children: [
                  // Tombol Batal
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          const Text('Batal'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Tombol Ya, Tolak
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          const Text('Ya, Tolak'),
                        ],
                      ),
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
}