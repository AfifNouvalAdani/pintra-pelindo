import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../vehicle/form_kondisi_kendaraan_awal_page.dart';
import '../vehicle/form_pengembalian_kendaraan_page.dart';
import '../services/approval_notification_service.dart';

class DetailPeminjamanPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final int approvalStep;
  final bool isReturn;
  final bool isApprovalMode;
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const DetailPeminjamanPage({
    super.key,
    required this.data,
    required this.approvalStep,
    required this.role,
    required this.userName,
    required this.userId,
    this.isReturn = false,
    this.isApprovalMode = false,
    required this.userDivision, 
  });

  @override
  State<DetailPeminjamanPage> createState() => _DetailPeminjamanPageState();
}

class _DetailPeminjamanPageState extends State<DetailPeminjamanPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _vehicleData;
  List<Map<String, dynamic>> _approvalHistory = [];

  @override
  void initState() {
    super.initState();
    _loadBookingData();
  }

  // Load data booking dari Firestore
  Future<void> _loadBookingData() async {
    try {
      setState(() => _isLoading = true);
      
      // 1. Ambil data booking dari vehicle_bookings
      final bookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.data['id'])
          .get();

      if (bookingDoc.exists) {
        _bookingData = {
          'id': bookingDoc.id,
          ...bookingDoc.data() as Map<String, dynamic>,
        };

        // 2. Ambil data kendaraan dari vehicles jika ada vehicleId
        if (_bookingData!['vehicleId'] != null) {
          final vehicleDoc = await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(_bookingData!['vehicleId'])
              .get();

          if (vehicleDoc.exists) {
            _vehicleData = {
              'id': vehicleDoc.id,
              ...vehicleDoc.data() as Map<String, dynamic>,
            };
          }
        }

        // 3. Ambil riwayat approval jika ada
        await _loadApprovalHistory();
      }
    } catch (e) {
      print('Error loading booking data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Load riwayat approval dari subcollection
  Future<void> _loadApprovalHistory() async {
    try {
      final historySnapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.data['id'])
          .collection('approval_history')
          .orderBy('timestamp', descending: true)
          .get();

      _approvalHistory = historySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error loading approval history: $e');
    }
  }

  // Format tanggal dari Timestamp
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(date);
  }

  // Format tanggal dari DateTime
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return DateFormat('dd MMMM yyyy', 'id_ID').format(dateTime);
  }

  // Format waktu dari DateTime
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return DateFormat('HH:mm', 'id_ID').format(dateTime);
  }

void _showSnackBar(String message) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Fungsi untuk menampilkan dialog pilih kendaraan
// Fungsi untuk menampilkan dialog pilih kendaraan
Future<void> _showSelectVehicleDialog() async {
  try {
    // ✅ AMBIL SEMUA KENDARAAN AKTIF (tidak filter status)
    final vehiclesSnapshot = await FirebaseFirestore.instance
        .collection('vehicles')
        .where('statusAktif', isEqualTo: true)
        .get();

    if (vehiclesSnapshot.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak ada kendaraan yang terdaftar'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // ✅ AMBIL DATA BOOKING YANG SEDANG DIEDIT
    final currentBookingStart = (_bookingData?['waktuPinjam'] as Timestamp?)?.toDate();
    final currentBookingEnd = (_bookingData?['waktuKembali'] as Timestamp?)?.toDate();

    if (currentBookingStart == null || currentBookingEnd == null) {
      _showSnackBar('Data waktu peminjaman tidak valid');
      return;
    }

    // ✅ AMBIL SEMUA BOOKING AKTIF SELAIN BOOKING INI
    final activeBookingsSnapshot = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .where('status', whereIn: [
          'SUBMITTED',
          'APPROVAL_1',
          'APPROVAL_2',
          'APPROVAL_3',
          'ON_GOING'
        ])
        .get();

    // ✅ HITUNG KENDARAAN YANG BENTROK WAKTU (TAPI EXCLUDE BOOKING SENDIRI)
    Set<String> unavailableVehicleIds = {};
    
    for (var bookingDoc in activeBookingsSnapshot.docs) {
      // ✅ SKIP JIKA INI BOOKING YANG SEDANG DIEDIT
      if (bookingDoc.id == widget.data['id']) continue;

      final booking = bookingDoc.data();
      final bookingStart = (booking['waktuPinjam'] as Timestamp).toDate();
      final bookingEnd = (booking['waktuKembali'] as Timestamp).toDate();
      final vehicleId = booking['vehicleId'] as String?;

      if (vehicleId == null) continue;

      // Cek bentrok waktu
      bool isBentrok = currentBookingStart.isBefore(bookingEnd) && 
                      currentBookingEnd.isAfter(bookingStart);

      if (isBentrok) {
        unavailableVehicleIds.add(vehicleId);
      }
    }

    print('🚗 Total kendaraan: ${vehiclesSnapshot.docs.length}');
    print('🔴 Kendaraan bentrok: ${unavailableVehicleIds.length}');

    // ✅ BUAT LIST KENDARAAN DENGAN STATUS KETERSEDIAAN
    final vehiclesWithStatus = vehiclesSnapshot.docs.map((doc) {
      final isAvailable = !unavailableVehicleIds.contains(doc.id);
      return {
        'doc': doc,
        'isAvailable': isAvailable,
      };
    }).toList();

    // ✅ FIX ERROR 1: URUTKAN DENGAN TYPE CAST YANG BENAR
    vehiclesWithStatus.sort((a, b) {
      final aAvailable = a['isAvailable'] as bool? ?? false;
      final bAvailable = b['isAvailable'] as bool? ?? false;
      
      if (aAvailable == bAvailable) return 0;
      return aAvailable ? -1 : 1;
    });

    final selectedVehicle = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.directions_car, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Text('Pilih Kendaraan'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vehiclesWithStatus.length,
            itemBuilder: (context, index) {
              final item = vehiclesWithStatus[index];
              
              // ✅ FIX ERROR 2: SAFE CAST DENGAN NULL CHECK
              final vehicle = item['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
              final vehicleData = vehicle.data();
              final isAvailable = item['isAvailable'] as bool? ?? false;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isAvailable ? Colors.white : Colors.grey.shade100,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isAvailable 
                          ? Colors.blue.shade50 
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: isAvailable 
                          ? Colors.blue.shade700 
                          : Colors.grey.shade600,
                      size: 28,
                    ),
                  ),
                  title: Text(
                    vehicleData['nama'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isAvailable 
                          ? Colors.grey.shade900 
                          : Colors.grey.shade600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        vehicleData['platNomor'] ?? '-',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.event_seat, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${vehicleData['kursi']} kursi',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.local_gas_station, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            vehicleData['bbm'] ?? '-',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      // ✅ BADGE STATUS
                      if (!isAvailable) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Sedang dipinjam user lain',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isAvailable 
                        ? Colors.grey.shade400 
                        : Colors.grey.shade300,
                  ),
                  // ✅ FIX ERROR 3: SAFE ACCESS DENGAN NULL CHECK
                  onTap: isAvailable
                      ? () {
                          Navigator.pop(context, {
                            'id': vehicle.id,
                            ...vehicleData,
                          });
                        }
                      : null, // ✅ DISABLE TAP JIKA TIDAK AVAILABLE
                ),
              );
            },
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
        ],
      ),
    );

    if (selectedVehicle != null) {
      await _updateVehicle(selectedVehicle);
    }
  } catch (e) {
    print('Error showing vehicle selection: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat daftar kendaraan: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// Fungsi untuk update kendaraan di booking
Future<void> _updateVehicle(Map<String, dynamic> newVehicle) async {
  try {
    setState(() => _isLoading = true);

    final oldVehicleId = _bookingData?['vehicleId'];
    final oldVehicleName = _vehicleData?['nama'] ?? 'Unknown';

    // Update booking dengan kendaraan baru
    await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .doc(widget.data['id'])
        .update({
      'vehicleId': newVehicle['id'],
      'vehicle': {
        'nama': newVehicle['nama'],
        'platNomor': newVehicle['platNomor'],
      },
      'updatedAt': Timestamp.now(),
      'lastEditBy': widget.userName,
      'lastEditRole': widget.role,
    });

    // Tambahkan ke riwayat approval
    await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .doc(widget.data['id'])
        .collection('approval_history')
        .add({
      'action': 'VEHICLE_CHANGED',
      'oldVehicleId': oldVehicleId,
      'oldVehicleName': oldVehicleName,
      'newVehicleId': newVehicle['id'],
      'newVehicleName': newVehicle['nama'],
      'actionBy': widget.userName,
      'actionRole': widget.role,
      'userId': widget.userId,
      'timestamp': Timestamp.now(),
      'note': 'Kendaraan diubah dari $oldVehicleName ke ${newVehicle['nama']} oleh ${widget.userName}',
    });

    // Refresh data
    await _loadBookingData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kendaraan berhasil diubah ke ${newVehicle['nama']}'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah kendaraan: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _approveBooking() async {
    try {
      setState(() => _isLoading = true);

      String currentStatus = _bookingData?['status'] ?? 'SUBMITTED';
      String newStatus;
      String actionText;
      
      // ✅ Cek apakah Manager Divisi (ambil dari Firestore)
      String? userJabatan;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        userJabatan = userDoc.data()?['jabatan'];
      } catch (e) {
        print('Error fetching user jabatan: $e');
      }
      
      final isManagerDivisi = (userJabatan ?? '').toLowerCase().contains('manager');
      
      // Tentukan status baru berdasarkan role dan jabatan
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
        
        // ✅ KHUSUS OPERATOR: Cek apakah kendaraan sudah dipilih
        if (_bookingData?['vehicleId'] == null || _bookingData?['vehicleId'] == '') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Harap pilih kendaraan terlebih dahulu dengan menekan tombol "Edit Kendaraan"'),
                backgroundColor: Colors.orange.shade600,
                behavior: SnackBarBehavior.floating,
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

      // Update status di booking
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.data['id'])
          .update({
        'status': newStatus,
        'updatedAt': Timestamp.now(),
        'lastApprovalBy': widget.userName,
        'lastApprovalRole': widget.role,
        'lastApprovalJabatan': userJabatan,
      });

      // Tambahkan ke riwayat approval
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
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
        'timestamp': Timestamp.now(),
        'note': '$actionText oleh ${widget.userName}',
      });

      // ✅✅✅ KIRIM NOTIFIKASI WA KE APPROVER BERIKUTNYA ✅✅✅
      if (newStatus == 'APPROVAL_1') {
        // Setelah Manager Divisi approve, kirim WA ke Operator
        print('📨 Mengirim notifikasi WA ke Operator...');
        
        final success = await ApprovalNotificationService.sendApprovalNotificationToOperator(
          bookingId: widget.data['id'],
          bookingData: _bookingData!,
        );
        
        if (success) {
          print('✅ Notifikasi WA berhasil dikirim ke Operator');
        } else {
          print('❌ Gagal mengirim notifikasi WA ke Operator');
        }
        
      } else if (newStatus == 'APPROVAL_2') {
        // Setelah Operator approve, kirim WA ke Manager Umum
        print('📨 Mengirim notifikasi WA ke Manager Umum...');
        
        final success = await ApprovalNotificationService.sendApprovalNotificationToManagerUmum(
          bookingId: widget.data['id'],
          bookingData: _bookingData!,
        );
        
        if (success) {
          print('✅ Notifikasi WA berhasil dikirim ke Manager Umum');
        } else {
          print('❌ Gagal mengirim notifikasi WA ke Manager Umum');
        }
      }
      // ✅✅✅ AKHIR KODE NOTIFIKASI WA ✅✅✅

      // Refresh data
      await _loadBookingData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Peminjaman berhasil disetujui'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyetujui: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // Fungsi untuk reject booking
  Future<void> _rejectBooking() async {
    final TextEditingController reasonController = TextEditingController();
    String reason = ''; // ✅ Tambahkan variable untuk simpan reason
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Peminjaman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan alasan penolakan:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Contoh: Kendaraan tidak tersedia, jadwal bentrok, dll.',
              ),
              onChanged: (value) {
                reason = value; // ✅ Simpan ke variable reason
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Harap masukkan alasan penolakan'),
                    backgroundColor: Colors.red.shade600,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    // ✅ Ganti reasonController.text dengan reason
    if (confirmed == true && reason.isNotEmpty) {
      try {
        setState(() => _isLoading = true);

        // Ambil jabatan user
        String? userJabatan;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();
          userJabatan = userDoc.data()?['jabatan'];
        } catch (e) {
          print('Error fetching user jabatan: $e');
        }

        // Update status menjadi CANCELLED
        await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .doc(widget.data['id'])
            .update({
          'status': 'CANCELLED',
          'rejectionReason': reason, // ✅ Gunakan reason
          'rejectedBy': widget.userName,
          'rejectedRole': widget.role,
          'rejectedJabatan': userJabatan,
          'updatedAt': Timestamp.now(),
        });

        // Tambahkan ke riwayat approval
        await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .doc(widget.data['id'])
            .collection('approval_history')
            .add({
          'action': 'REJECTED',
          'oldStatus': _bookingData?['status'],
          'newStatus': 'CANCELLED',
          'actionBy': widget.userName,
          'actionRole': widget.role,
          'actionJabatan': userJabatan,
          'userId': widget.userId,
          'timestamp': Timestamp.now(),
          'note': 'Ditolak oleh ${widget.userName}',
          'reason': reason, // ✅ Gunakan reason
        });

        await _loadBookingData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Peminjaman berhasil ditolak'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menolak: $e'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
    
    // ✅ Dispose controller
    reasonController.dispose();
  }

  // Get status text berdasarkan status dari Firestore
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

  // Get status icon
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

  // Get status description
  String _getStatusDescription(String status) {
    switch (status) {
      case 'SUBMITTED':
        return 'Pengajuan sedang menunggu persetujuan dari manager divisi';
      case 'APPROVAL_1':
        return 'Disetujui manager divisi, menunggu verifikasi operator';
      case 'APPROVAL_2':
        return 'Diverifikasi operator, menunggu persetujuan manager umum';
      case 'APPROVAL_3':
        return 'Pengajuan telah disetujui. Silakan ambil kendaraan dan isi form kondisi awal';
      case 'ON_GOING':
        return 'Kendaraan sedang digunakan';
      case 'DONE':
        return 'Peminjaman telah selesai';
      case 'CANCELLED':
        return 'Peminjaman dibatalkan';
      default:
        return 'Status tidak diketahui';
    }
  }

  // Build timeline berdasarkan status
  Widget _buildTimeline() {
    final steps = [
      {'label': 'Pengajuan', 'status': 'SUBMITTED'},
      {'label': 'Approval Manager Divisi', 'status': 'APPROVAL_1'},
      {'label': 'Verifikasi Operator', 'status': 'APPROVAL_2'},
      {'label': 'Approval Manager Umum', 'status': 'APPROVAL_3'},
      {'label': 'Sedang Digunakan', 'status': 'ON_GOING'},
      {'label': 'Selesai', 'status': 'DONE'},
    ];

    final currentStatus = _bookingData?['status'] ?? 'SUBMITTED';
    int currentStep = steps.indexWhere((step) => step['status'] == currentStatus);

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isActive = index <= currentStep;
        final isCurrent = index == currentStep;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Dot and Line
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive ? _getStatusColor(step['status']!) : Colors.grey.shade300,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: isActive
                      ? Icon(
                          isCurrent ? Icons.circle : Icons.check_rounded,
                          color: Colors.white,
                          size: isCurrent ? 10 : 14,
                        )
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isActive ? _getStatusColor(step['status']!).withOpacity(0.3) : Colors.grey.shade200,
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // Step Content
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
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? Colors.grey.shade900
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimelineDate(step['status']!),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
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

      // Get timeline date berdasarkan status
    String _getTimelineDate(String status) {
      // Cari di approval history berdasarkan newStatus
      final history = _approvalHistory.firstWhere(
        (h) => h['newStatus'] == status || h['status'] == status,
        orElse: () => {},
      );

      if (history.isNotEmpty && history['timestamp'] != null) {
        return _formatTimestamp(history['timestamp']);
      }

      // Fallback ke created/updated date
      switch (status) {
        case 'SUBMITTED':
          return _formatTimestamp(_bookingData?['createdAt']);
        case 'ON_GOING':
          return _formatTimestamp(_bookingData?['actualPickupTime']);
        case 'DONE':
          return _formatTimestamp(_bookingData?['actualReturnTime']);
        default:
          return 'Menunggu';
      }
    }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            'Detail Peminjaman',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.blue.shade700,
          ),
        ),
      );
    }

    final booking = _bookingData ?? widget.data;
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.grey.shade700,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detail Peminjaman',
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
          padding: const EdgeInsets.all(24),
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
                  border: Border.all(
                    color: statusColor.withOpacity(0.2),
                  ),
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
                            _getStatusDescription(status),
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

              const SizedBox(height: 32),

              // Timeline
              Text(
                'Proses Persetujuan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 16),

              _buildTimeline(),

              const SizedBox(height: 32),

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

                    // Data Peminjaman
                    _buildDetailItem('ID Peminjaman', booking['id']),
                    _buildDetailItem('Nama Peminjam', booking['namaPeminjam'] ?? widget.userName),
                    _buildDetailItem('Email', booking['emailPeminjam'] ?? ''),
                    _buildDetailItem('Divisi', booking['divisi'] ?? ''),
                    _buildDetailItem('Keperluan', booking['keperluan'] ?? ''),
                    
                    if (booking['nomorSurat'] != null && booking['nomorSurat'].toString().isNotEmpty && booking['nomorSurat'] != '-')
                      _buildDetailItem('Nomor SPPD/Undangan', booking['nomorSurat'].toString()),
                    
                    if (booking['alasan'] != null && booking['alasan'].toString().isNotEmpty && booking['alasan'] != '-')
                      _buildDetailItem('Alasan/Keterangan', booking['alasan'].toString()),
                    
                    _buildDetailItem('Tujuan', booking['tujuan'] ?? ''),
                    
                    // Detail Kendaraan
                    if (_vehicleData != null) ...[
                      _buildDetailItem('Kendaraan', '${_vehicleData!['nama']} (${_vehicleData!['platNomor']})'),
                      _buildDetailItem('Tahun', _vehicleData!['tahun'].toString()),
                      _buildDetailItem('Jenis', _vehicleData!['jenis'] ?? 'Mobil'),
                      _buildDetailItem('Kapasitas', '${_vehicleData!['kursi']} kursi'),
                      _buildDetailItem('BBM', _vehicleData!['bbm'] ?? '-'),
                      _buildDetailItem('Transmisi', _vehicleData!['transmisi'] ?? '-'),
                      ] else if (booking['vehicle'] != null) ...[
                        // ^^^ Ganti {} dengan ...[]
                        _buildDetailItem('Kendaraan', '${(booking['vehicle'] as Map<String, dynamic>)['nama']} (${(booking['vehicle'] as Map<String, dynamic>)['platNomor']})'),
                      ],

                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade200),
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
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                waktuPinjam != null ? _formatDateTime(waktuPinjam) : booking['tglPinjam'] ?? '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                waktuPinjam != null ? _formatTime(waktuPinjam) : booking['jamPinjam'] ?? '-',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (booking['actualPickupTime'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Diambil: ${_formatTimestamp(booking['actualPickupTime'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
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
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Tanggal Kembali',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                waktuKembali != null ? _formatDateTime(waktuKembali) : booking['tglKembali'] ?? '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                waktuKembali != null ? _formatTime(waktuKembali) : booking['jamKembali'] ?? '-',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (booking['actualReturnTime'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Dikembalikan: ${_formatTimestamp(booking['actualReturnTime'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Tanggal Pengajuan
                    if (booking['createdAt'] != null) ...[
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Text(
                        'Diajukan pada: ${_formatTimestamp(booking['createdAt'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
                // Riwayat Approval
                if (_approvalHistory.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Riwayat Approval',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: _approvalHistory.map((history) {
                        // ✅ Ambil status dari newStatus atau status
                        final statusLabel = history['newStatus'] ?? history['status'] ?? '';
                        
                        IconData icon;
                        Color iconColor;
                        Color bgColor;

                        if (history['action'] == 'APPROVED') {
                          icon = Icons.check;
                          iconColor = Colors.green;
                          bgColor = Colors.green.shade100;
                        } else if (history['action'] == 'REJECTED') {
                          icon = Icons.close;
                          iconColor = Colors.red;
                          bgColor = Colors.red.shade100;
                        } else if (history['action'] == 'VEHICLE_PICKED_UP') {
                          icon = Icons.key;
                          iconColor = Colors.blue;
                          bgColor = Colors.blue.shade100;
                        } else if (history['action'] == 'VEHICLE_RETURNED') {
                          icon = Icons.check_circle;
                          iconColor = Colors.green;
                          bgColor = Colors.green.shade100;
                        } else if (history['action'] == 'VEHICLE_CHANGED') {  // ⬅️ TAMBAHKAN INI
                          icon = Icons.swap_horiz;
                          iconColor = Colors.orange;
                          bgColor = Colors.orange.shade100;
                        } else {
                          icon = Icons.info;
                          iconColor = Colors.grey;
                          bgColor = Colors.grey.shade100;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    icon,
                                    color: iconColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Note
                                      Text(
                                        history['note'] ?? '${history['action']} by ${history['actionBy']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      
                                      // Timestamp
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatTimestamp(history['timestamp']),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      // Status Badge (jika ada)
                                      if (statusLabel.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(statusLabel).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _getStatusColor(statusLabel).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            _getStatusText(statusLabel),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(statusLabel),
                                            ),
                                          ),
                                        ),
                                      ],
                                      
                                      // Info tambahan (odometer)
                                      if (history['odometerAwal'] != null) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.speed,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Odometer Awal: ${history['odometerAwal']} km',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      
                                      if (history['odometerAkhir'] != null) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.speed,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Odometer Akhir: ${history['odometerAkhir']} km',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    if (history['action'] == 'VEHICLE_CHANGED') ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${history['oldVehicleName']} → ${history['newVehicleName']}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
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

              const SizedBox(height: 40),

                // Tombol Aksi
                if (widget.isApprovalMode) ...[
                  if (widget.role == 'operator' && status == 'APPROVAL_1') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _showSelectVehicleDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text(
                          'Edit Kendaraan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Tombol Tolak dan Setujui
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _rejectBooking,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade700, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Tolak',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Setujui',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                // Tombol untuk peminjam
                if (status == 'APPROVAL_3') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FormKondisiKendaraanAwalPage(
                              role: widget.role,
                              userName: widget.userName,
                              userId: widget.userId,
                              bookingId: booking['id'],
                              vehicleId: booking['vehicleId'],
                              vehicleData: _vehicleData,
                              userDivision: widget.userDivision,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Isi Form Kondisi Awal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (status == 'ON_GOING') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FormPengembalianKendaraanPage(
                              role: widget.role,
                              userName: widget.userName,
                              userId: widget.userId,
                              bookingId: booking['id'],
                              vehicleId: booking['vehicleId'],
                              vehicleData: _vehicleData,
                              bookingData: booking,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Kembalikan Kendaraan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Kembali',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ],

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
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
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