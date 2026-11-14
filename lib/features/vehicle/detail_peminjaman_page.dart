import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../vehicle/form_kondisi_kendaraan_awal_page.dart';
import '../vehicle/form_pengembalian_kendaraan_page.dart';
import '../services/approval_notification_service.dart';
import '../services/auto_cancel_service.dart';
import 'dart:convert';
import '../services/location_tracking_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:pintra/utils/booking_logic.dart';

class DetailPeminjamanPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final int approvalStep;
  final bool isReturn;
  final bool isApprovalMode;
  final String role;
  final String userName;
  final String userId;
  final String userDivision;
  final String? operatorType;

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
    this.operatorType,
  });

  @override
  State<DetailPeminjamanPage> createState() => _DetailPeminjamanPageState();
}

class _DetailPeminjamanPageState extends State<DetailPeminjamanPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _vehicleData;
  List<Map<String, dynamic>> _approvalHistory = [];
  Map<String, dynamic>? _kondisiAwalData;
  Map<String, dynamic>? _kondisiAkhirData;

  @override
  void initState() {
    super.initState();
    _checkAndCancelIfExpired();
    _loadBookingData();
  }

  @override
void dispose() {
  // Stop tracking saat halaman ditutup
  if (widget.role == 'user') {
    LocationTrackingService().stopTracking();
  }
  super.dispose();
}

    Future<void> _checkAndCancelIfExpired() async {
    final wasCancelled = await AutoCancelService.checkAndCancelSingleBooking(widget.data['id']);
    
    if (wasCancelled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Peminjaman ini telah dibatalkan otomatis karena melewati waktu peminjaman'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

Future<void> _loadBookingData() async {
  try {
    setState(() => _isLoading = true);
    print('=== LOAD BOOKING DATA ==='); // ← TAMBAH INI
    print('booking id: ${widget.data['id']}'); // ← TAMBAH INI
    
    final bookingDoc = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .doc(widget.data['id'])
        .get();

    if (bookingDoc.exists) {
      _bookingData = {
        'id': bookingDoc.id,
        ...bookingDoc.data() as Map<String, dynamic>,
      };

      // Ekstrak kondisi awal dan akhir
      _kondisiAwalData = _bookingData!['kondisiAwal'] as Map<String, dynamic>?;
      _kondisiAkhirData = _bookingData!['kondisiAkhir'] as Map<String, dynamic>?;

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

      print('status booking: ${_bookingData!['status']}'); // ← TAMBAH INI
      print('role: ${widget.role}'); // ← TAMBAH INI

      await _loadApprovalHistory();
      _startSilentTrackingIfNeeded();
    }
  } catch (e) {
    print('Error loading booking data: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

void _startSilentTrackingIfNeeded() {
  if (_bookingData == null) return;

  final status = _bookingData!['status'] ?? '';
  final isPeminjam = _bookingData!['peminjamId'] == widget.userId;

  if (widget.role != 'user' || !isPeminjam || status != 'ON_GOING') return;

  // Di web, jangan auto-check permission — tunggu user tap tombol "Aktifkan"
  if (kIsWeb) return; // ← tambah ini

  final vehicle = _bookingData!['vehicle'] as Map<String, dynamic>? ?? {};

  final vehicleNama = vehicle['nama'] ?? _vehicleData?['nama'] ?? 'Kendaraan';
  final vehiclePlat = vehicle['platNomor'] ?? _vehicleData?['platNomor'] ?? '-';
  final namaPeminjam = _bookingData!['namaPeminjam'] ?? widget.userName;

  // Hanya mulai tracking jika permission sudah granted sebelumnya
  Geolocator.checkPermission().then((permission) {
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      LocationTrackingService().startTracking(
        bookingId: widget.data['id'],
        vehicleNama: vehicleNama,
        vehiclePlat: vehiclePlat,
        namaPeminjam: namaPeminjam,
      );
    }
    // Jika belum ada izin, tunggu user tap tombol "Aktifkan"
  });
}

Future<void> _cancelBookingByAdminOperator() async {
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
                ? 'Anda akan mengajukan request pembatalan kepada Admin. Peminjam tidak akan melihat perubahan hingga Admin menyetujui.'
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
              hintText: 'Contoh: Kendaraan mengalami kerusakan mendadak',
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
          .collection('users')
          .doc(widget.userId)
          .get();
      userJabatan = userDoc.data()?['jabatan'];
    } catch (e) {
      print('Error fetching user jabatan: $e');
    }

    if (widget.role == 'operator') {

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.data['id'])
          .update({
        'cancellationRequested': true,
        'cancellationRequestedBy': widget.userName,
        'cancellationRequestedByRole': 'operator',
        'cancellationRequestedByJabatan': userJabatan,
        'cancellationRequestReason': reason,
        'cancellationRequestedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
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
        'timestamp': Timestamp.now(),
        'note': 'Request pembatalan oleh ${widget.userName}',
        'reason': reason,
      });

      print('📨 Mengirim notifikasi WA request pembatalan ke Admin...');
      final success = await ApprovalNotificationService.sendCancellationRequestToAdmin(
        bookingId: widget.data['id'],
        bookingData: _bookingData!,
        requestedBy: widget.userName,
        reason: reason,
      );
      print(success ? '✅ Notifikasi WA terkirim' : '❌ Gagal kirim WA');

      await _loadBookingData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Request pembatalan berhasil dikirim ke Admin'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } else {
      final currentStatus = _bookingData?['status'];

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.data['id'])
          .update({
        'status': 'CANCELLED',
        'cancellationReason': reason,
        'cancelledBy': widget.userName,
        'cancelledByRole': 'admin',
        'cancelledByJabatan': userJabatan,
        'cancelledAt': Timestamp.now(),
        'cancellationRequested': false,
        'updatedAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
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
        'timestamp': Timestamp.now(),
        'note': 'Dibatalkan langsung oleh Admin: ${widget.userName}',
        'reason': reason,
      });

      await ApprovalNotificationService.sendUnilateralCancellationToPeminjam(
        bookingId: widget.data['id'],
        bookingData: _bookingData!,
        cancelledBy: widget.userName,
        cancelledByRole: 'admin',
        reason: reason,
      );

      await _loadBookingData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Peminjaman berhasil dibatalkan'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal: $e'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ));
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

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

Future<void> _showSelectVehicleDialog() async {
  try {
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

    // ✅ Ambil semua booking ON_GOING — ini satu-satunya yang BENAR-BENAR tidak bisa ditukar
    final onGoingSnapshot = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .where('status', isEqualTo: 'ON_GOING')
        .get();

    // ✅ vehicleId yang sedang ON_GOING (kendaraan sudah diambil)
    Set<String> hardUnavailableVehicleIds = {};
    for (var doc in onGoingSnapshot.docs) {
      // Skip booking ini sendiri
      if (doc.id == widget.data['id']) continue;
      final vehicleId = doc.data()['vehicleId'] as String?;
      if (vehicleId != null) {
        hardUnavailableVehicleIds.add(vehicleId);
      }
    }

    // ✅ Ambil semua booking non-ON_GOING aktif — untuk deteksi soft booked (swap)
    final activeSnapshot = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .where('status', whereIn: [
          'SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3'
        ])
        .get();

    // key: vehicleId, value: bookingId yang memakai kendaraan tersebut
    Map<String, String> softBookedVehicleIds = {};
    for (var doc in activeSnapshot.docs) {
      if (doc.id == widget.data['id']) continue;
      final vehicleId = doc.data()['vehicleId'] as String?;
      if (vehicleId != null) {
        softBookedVehicleIds[vehicleId] = doc.id;
      }
    }

    final currentVehicleId = _bookingData?['vehicleId'];

    final vehiclesWithStatus = vehiclesSnapshot.docs.map((doc) {
      final isHardUnavailable = hardUnavailableVehicleIds.contains(doc.id);
      final isSoftBooked = softBookedVehicleIds.containsKey(doc.id);
      final isCurrentVehicle = doc.id == currentVehicleId;

      return {
        'doc': doc,
        'isHardUnavailable': isHardUnavailable,
        'isSoftBooked': isSoftBooked,
        'isCurrentVehicle': isCurrentVehicle,
        'otherBookingId': softBookedVehicleIds[doc.id],
      };
    }).toList();

    // Urutan: kendaraan saat ini → bebas → soft booked → hard unavailable
    vehiclesWithStatus.sort((a, b) {
      final aCurrent = a['isCurrentVehicle'] as bool? ?? false;
      final bCurrent = b['isCurrentVehicle'] as bool? ?? false;
      final aHard = a['isHardUnavailable'] as bool? ?? false;
      final bHard = b['isHardUnavailable'] as bool? ?? false;
      final aSoft = a['isSoftBooked'] as bool? ?? false;
      final bSoft = b['isSoftBooked'] as bool? ?? false;

      if (aCurrent) return -1;
      if (bCurrent) return 1;
      if (aHard && !bHard) return 1;
      if (bHard && !aHard) return -1;
      if (aSoft && !bSoft) return 1;
      if (bSoft && !aSoft) return -1;
      return 0;
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
              final vehicle = item['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
              final vehicleData = vehicle.data();
              final isHardUnavailable = item['isHardUnavailable'] as bool? ?? false;
              final isSoftBooked = item['isSoftBooked'] as bool? ?? false;
              final isCurrentVehicle = item['isCurrentVehicle'] as bool? ?? false;

              // ✅ Hanya ON_GOING yang tidak bisa dipilih
              final canSelect = !isHardUnavailable && !isCurrentVehicle;

              Color cardColor;
              String? badgeText;
              Color? badgeColor;

              if (isCurrentVehicle) {
                cardColor = Colors.blue.shade50;
                badgeText = 'Kendaraan saat ini';
                badgeColor = Colors.blue.shade700;
              } else if (isHardUnavailable) {
                cardColor = Colors.grey.shade100;
                badgeText = 'Sedang digunakan (tidak bisa ditukar)';
                badgeColor = Colors.red.shade700;
              } else if (isSoftBooked) {
                cardColor = Colors.orange.shade50;
                badgeText = 'Dipinjam user lain — akan ditukar otomatis';
                badgeColor = Colors.orange.shade700;
              } else {
                cardColor = Colors.white;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: cardColor,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isHardUnavailable
                          ? Colors.grey.shade300
                          : isCurrentVehicle
                              ? Colors.blue.shade100
                              : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: isHardUnavailable
                          ? Colors.grey.shade600
                          : Colors.blue.shade700,
                      size: 28,
                    ),
                  ),
                  title: Text(
                    vehicleData['nama'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isHardUnavailable || isCurrentVehicle
                          ? Colors.grey.shade500
                          : Colors.grey.shade900,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        vehicleData['platNomor'] ?? '-',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.event_seat, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text('${vehicleData['kursi']} kursi',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.local_gas_station, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(vehicleData['bbm'] ?? '-',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      if (badgeText != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? Colors.grey).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: (badgeColor ?? Colors.grey).withOpacity(0.3)),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              color: badgeColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                      ? () {
                          Navigator.pop(context, {
                            'id': vehicle.id,
                            ...vehicleData,
                            'otherBookingId': item['otherBookingId'],
                          });
                        }
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

Future<void> _updateVehicle(Map<String, dynamic> newVehicle) async {
  try {
    setState(() => _isLoading = true);

    final oldVehicleId = _bookingData?['vehicleId'];
    final oldVehicleName = _vehicleData?['nama'] ?? 'Unknown';
    final newVehicleId = newVehicle['id'];
    final newVehicleName = newVehicle['nama'];
    final otherBookingId = newVehicle['otherBookingId'] as String?;

    // ✅ Cek apakah kendaraan baru sedang dipakai booking lain (perlu swap)
    if (otherBookingId != null && oldVehicleId != null) {
      // Konfirmasi swap ke operator
      final confirmSwap = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              const Flexible(
                child: Text('Konfirmasi Tukar Kendaraan'),
              ),
            ],
          ),
          content: Text(
            'Kendaraan $newVehicleName sedang dialokasikan untuk peminjam lain.\n\n'
            'Dengan melanjutkan:\n'
            '• Peminjaman ini → $newVehicleName\n'
            '• Peminjaman lain → $oldVehicleName\n\n'
            'Lanjutkan penukaran?',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Tukar'),
            ),
          ],
        ),
      );

      if (confirmSwap != true) {
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Ambil data kendaraan lama (untuk nama di history booking lain)
      String? oldVehiclePlatNomor = _vehicleData?['platNomor'];

      // ✅ Update booking LAIN: ganti ke kendaraan lama (milik booking ini)
      final otherBookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(otherBookingId)
          .get();

      if (otherBookingDoc.exists) {
        await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .doc(otherBookingId)
            .update({
          'vehicleId': oldVehicleId,
          'vehicle': {
            'nama': oldVehicleName,
            'platNomor': oldVehiclePlatNomor ?? '-',
          },
          'updatedAt': Timestamp.now(),
          'lastEditBy': widget.userName,
          'lastEditRole': widget.role,
        });

        // History untuk booking lain
        await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .doc(otherBookingId)
            .collection('approval_history')
            .add({
          'action': 'VEHICLE_CHANGED',
          'oldVehicleId': newVehicleId,
          'oldVehicleName': newVehicleName,
          'newVehicleId': oldVehicleId,
          'newVehicleName': oldVehicleName,
          'actionBy': widget.userName,
          'actionRole': widget.role,
          'userId': widget.userId,
          'timestamp': Timestamp.now(),
          'note': 'Kendaraan ditukar otomatis dari $newVehicleName ke $oldVehicleName oleh ${widget.userName} (akibat swap)',
        });
      }
    }

    // ✅ Update booking INI dengan kendaraan baru
    await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .doc(widget.data['id'])
        .update({
      'vehicleId': newVehicleId,
      'vehicle': {
        'nama': newVehicleName,
        'platNomor': newVehicle['platNomor'],
      },
      'updatedAt': Timestamp.now(),
      'lastEditBy': widget.userName,
      'lastEditRole': widget.role,
    });

    // History untuk booking ini
    await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .doc(widget.data['id'])
        .collection('approval_history')
        .add({
      'action': 'VEHICLE_CHANGED',
      'oldVehicleId': oldVehicleId,
      'oldVehicleName': oldVehicleName,
      'newVehicleId': newVehicleId,
      'newVehicleName': newVehicleName,
      'actionBy': widget.userName,
      'actionRole': widget.role,
      'userId': widget.userId,
      'timestamp': Timestamp.now(),
      'note': otherBookingId != null
          ? 'Kendaraan ditukar dari $oldVehicleName ke $newVehicleName oleh ${widget.userName} (swap dengan peminjam lain)'
          : 'Kendaraan diubah dari $oldVehicleName ke $newVehicleName oleh ${widget.userName}',
    });

    await _loadBookingData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            otherBookingId != null
                ? 'Kendaraan berhasil ditukar! $newVehicleName ↔ $oldVehicleName'
                : 'Kendaraan berhasil diubah ke $newVehicleName',
          ),
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
    if (mounted) setState(() => _isLoading = false);
  }
}

Future<void> _approveBooking() async {
  try {
    setState(() => _isLoading = true);

    String currentStatus = _bookingData?['status'] ?? 'SUBMITTED';

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

    bool adaKonflik = false;
    String? konflikDengan;

    // ✅ Khusus role operator: cek dulu kendaraan & konflik waktu via Firestore
    if (widget.role == 'operator') {
      if (widget.operatorType != 'ruang_meeting') {
        if (_bookingData?['vehicleId'] == null || _bookingData?['vehicleId'] == '') {
          setState(() => _isLoading = false);
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

        final vehicleId = _bookingData!['vehicleId'] as String;

        final dynamic rawWaktuPinjam = _bookingData!['waktuPinjam'];
        final dynamic rawWaktuKembali = _bookingData!['waktuKembali'];

        if (rawWaktuPinjam == null || rawWaktuKembali == null) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Data waktu peminjaman tidak valid, hubungi admin'),
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

        for (var doc in conflictSnapshot.docs) {
          if (doc.id == widget.data['id']) continue;

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

          final bool isBentrok = BookingLogic.isTimeConflict(
              waktuPinjam, waktuKembali, otherStart, otherEnd);

          print('   Bentrok? $isBentrok');

          if (isBentrok) {
            adaKonflik = true;
            konflikDengan = data['namaPeminjam'] ?? doc.id;
            break;
          }
        }
      }
    }

    // ✅ Keputusan status/izin sepenuhnya dari BookingLogic (fungsi murni)
    final result = BookingLogic.approveTransition(
      role: widget.role,
      jabatan: userJabatan ?? '',
      currentStatus: currentStatus,
      operatorType: widget.operatorType,
      hasConflict: adaKonflik,
    );

    if (result.error != null) {
      setState(() => _isLoading = false);

      // Kasus khusus: kendaraan bentrok → tampilkan dialog informatif (bukan cuma snackbar)
      if (result.error == 'Kendaraan bentrok') {
        if (mounted) {
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
                'Kendaraan yang dialokasikan untuk peminjaman ini sudah disetujui '
                '${konflikDengan != null ? "untuk $konflikDengan " : ""}'
                'pada waktu yang sama.\n\n'
                'Silakan ubah kendaraan terlebih dahulu menggunakan tombol "Edit Kendaraan".',
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

      // Error lain → lempar exception, ditangkap di catch bawah (snackbar merah)
      throw Exception(result.error);
    }

    final newStatus = result.newStatus!;
    final actionText = switch (newStatus) {
      'APPROVAL_1' => 'Disetujui Manager Divisi',
      'APPROVAL_2' => 'Diverifikasi Operator',
      'APPROVAL_3' => 'Disetujui Manager Umum',
      _ => 'Disetujui',
    };

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

    // Kirim notifikasi WA ke approver berikutnya
    if (newStatus == 'APPROVAL_1') {
      print('📨 Mengirim notifikasi WA ke Operator...');
      final success = await ApprovalNotificationService.sendApprovalNotificationToOperator(
        bookingId: widget.data['id'],
        bookingData: _bookingData!,
      );
      print(success ? '✅ Notifikasi WA berhasil dikirim ke Operator' : '❌ Gagal mengirim notifikasi WA ke Operator');
    } else if (newStatus == 'APPROVAL_2') {
      print('📨 Mengirim notifikasi WA ke Manager Umum...');
      final success = await ApprovalNotificationService.sendApprovalNotificationToManagerUmum(
        bookingId: widget.data['id'],
        bookingData: _bookingData!,
      );
      print(success ? '✅ Notifikasi WA berhasil dikirim ke Manager Umum' : '❌ Gagal mengirim notifikasi WA ke Manager Umum');
    } else if (newStatus == 'APPROVAL_3') {
      print('📨 Mengirim notifikasi WA ke peminjam...');
      final success = await ApprovalNotificationService.sendApprovedNotificationToPeminjam(
        bookingId: widget.data['id'],
        bookingData: _bookingData!,
      );
      print(success ? '✅ Notifikasi WA berhasil dikirim ke peminjam' : '❌ Gagal mengirim notifikasi WA ke peminjam');
    }

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

Future<void> _rejectBooking() async {
  final TextEditingController reasonController = TextEditingController();

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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
          child: const Text('Tolak'),
        ),
      ],
    ),
  );

  // ✅ Ambil reason dari controller SETELAH dialog ditutup
  final reason = reasonController.text.trim();
  reasonController.dispose(); // ✅ Selalu dispose di sini

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
    } catch (e) {
      print('Error fetching user jabatan: $e');
    }

    await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .doc(widget.data['id'])
        .update({
      'status': 'CANCELLED',
      'rejectionReason': reason,
      'rejectedBy': widget.userName,
      'rejectedRole': widget.role,
      'rejectedJabatan': userJabatan,
      'updatedAt': Timestamp.now(),
    });

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
      'reason': reason,
    });

    print('📨 Mengirim notifikasi WA penolakan ke peminjam...');
    final success = await ApprovalNotificationService.sendRejectedNotificationToPeminjam(
      bookingId: widget.data['id'],
      bookingData: _bookingData!,
      rejectedBy: widget.userName,
      reason: reason,
    );
    print(success ? '✅ Notifikasi WA berhasil dikirim ke peminjam' : '❌ Gagal mengirim notifikasi WA ke peminjam');

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
    if (mounted) setState(() => _isLoading = false);
  }
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
  final isCancelled = currentStatus == 'CANCELLED';

  final statusOrder = [
    'SUBMITTED',
    'APPROVAL_1',
    'APPROVAL_2',
    'APPROVAL_3',
    'ON_GOING',
    'DONE',
  ];

  final currentStep = isCancelled ? -1 : statusOrder.indexOf(currentStatus);

  return Column(
    children: List.generate(steps.length, (index) {
      final step = steps[index];
      final isLast = index == steps.length - 1;

      final isReached = !isCancelled && index <= currentStep;
      final isCurrent = !isCancelled && index == currentStep;

      // ✅ Semua yang sudah dicapai → hijau
      // Step saat ini (current) → hijau lebih gelap
      // Belum dicapai / cancelled → abu-abu
      Color dotColor;
      if (!isReached) {
        dotColor = Colors.grey.shade300;
      } else if (isCurrent) {
        dotColor = Colors.green.shade700; // current → hijau gelap
      } else {
        dotColor = Colors.green.shade400; // sudah lewat → hijau muda
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
  // Khusus SUBMITTED → ambil dari createdAt booking
  if (status == 'SUBMITTED') {
    return _formatTimestamp(_bookingData?['createdAt']);
  }

  // Cari di approval history berdasarkan newStatus
  final history = _approvalHistory.firstWhere(
    (h) => h['newStatus'] == status,
    orElse: () => {},
  );

  if (history.isNotEmpty && history['timestamp'] != null) {
    return _formatTimestamp(history['timestamp'] as Timestamp?);
  }

  // Fallback khusus per status
  switch (status) {
    case 'ON_GOING':
      return _formatTimestamp(_bookingData?['actualPickupTime'] as Timestamp?);
    case 'DONE':
      return _formatTimestamp(_bookingData?['actualReturnTime'] as Timestamp?);
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
    final isPeminjam = booking['peminjamId'] == widget.userId;
    final isAdmin = widget.role == 'admin';
    final canFillForm = isPeminjam || isAdmin;
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
              if (status == 'ON_GOING' && widget.role == 'user' && isPeminjam)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aktifkan tracking lokasi kendaraan',
                          style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                        ),
                      ),
                        ElevatedButton(
                        onPressed: () async {
                          if (kIsWeb) {
                            // Di web, langsung panggil startTracking — bypass _startSilentTrackingIfNeeded
                            final vehicle = _bookingData?['vehicle'] as Map<String, dynamic>? ?? {};
                            final vehicleNama = vehicle['nama'] ?? _vehicleData?['nama'] ?? 'Kendaraan';
                            final vehiclePlat = vehicle['platNomor'] ?? _vehicleData?['platNomor'] ?? '-';
                            final namaPeminjam = _bookingData?['namaPeminjam'] ?? widget.userName;

                            LocationTrackingService().startTracking(
                              bookingId: widget.data['id'],
                              vehicleNama: vehicleNama,
                              vehiclePlat: vehiclePlat,
                              namaPeminjam: namaPeminjam,
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Text('Meminta izin lokasi...'),
                                backgroundColor: Colors.blue.shade600,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                            return;
                          }

                            // Native Android/iOS: flow permission manual
                            final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text('Layanan lokasi tidak aktif. Aktifkan GPS di pengaturan.'),
                                  backgroundColor: Colors.orange.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  action: SnackBarAction(
                                    label: 'Pengaturan',
                                    textColor: Colors.white,
                                    onPressed: () => Geolocator.openLocationSettings(),
                                  ),
                                ));
                              }
                              return;
                            }

                            LocationPermission permission = await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                            }

                            if (permission == LocationPermission.deniedForever) {
                              if (mounted) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Izin Lokasi Diperlukan'),
                                    content: const Text(
                                      'Izin lokasi telah ditolak permanen. '
                                      'Buka pengaturan aplikasi untuk mengaktifkannya.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          Geolocator.openAppSettings();
                                        },
                                        child: const Text('Buka Pengaturan'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return;
                            }

                            if (permission == LocationPermission.always ||
                                permission == LocationPermission.whileInUse) {
                              _startSilentTrackingIfNeeded();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text('Tracking lokasi aktif'),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            }
                          },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Aktifkan', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
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
                      ] else if (booking['vehicle'] != null) ...[
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
                        if (status == 'CANCELLED') ...[
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 16),
                        
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
                                  Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.red.shade700,
                                    size: 20,
                                  ),
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
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (booking['rejectedBy'] != null || booking['cancelledBy'] != null) ...[
                                const SizedBox(height: 8),
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
                        } else if (history['action'] == 'VEHICLE_CHANGED') {
                          icon = Icons.swap_horiz;
                          iconColor = Colors.orange;
                          bgColor = Colors.orange.shade100;
                        } else if (history['action'] == 'CANCELLED_BY_ADMIN') {
                          icon = Icons.block;
                          iconColor = Colors.red.shade700;
                          bgColor = Colors.red.shade100;
                        } else if (history['action'] == 'AUTO_CANCELLED') {
                          icon = Icons.timer_off_rounded;
                          iconColor = Colors.orange.shade700;
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

                // ─── KONDISI AWAL ───
                if (_kondisiAwalData != null) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Data Kondisi Awal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                              child: Icon(Icons.start_rounded, color: Colors.blue.shade700, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Kondisi Awal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailItem('Kondisi Saat Pinjam', _kondisiAwalData!['kondisi'] ?? '-'),
                        _buildDetailItem('Kelengkapan Saat Pinjam', _kondisiAwalData!['kelengkapan'] ?? '-'),
                        if (_kondisiAwalData!['kelengkapanItems'] != null)
                          _buildKelengkapanItems('Kelengkapan Tersedia Saat Pinjam', _kondisiAwalData!['kelengkapanItems']),
                        _buildDetailItem('Odometer Awal', '${_kondisiAwalData!['odometerAwal'] ?? '-'} km'),
                        if (_kondisiAwalData!['uraianKondisi'] != null &&
                            _kondisiAwalData!['uraianKondisi'].toString().isNotEmpty)
                          _buildDetailItem('Keterangan Kondisi', _kondisiAwalData!['uraianKondisi']),
                        if (_kondisiAwalData!['uraianKelengkapan'] != null &&
                            _kondisiAwalData!['uraianKelengkapan'].toString().isNotEmpty)
                          _buildDetailItem('Keterangan Kelengkapan', _kondisiAwalData!['uraianKelengkapan']),
                        _buildDetailItem(
                          'Diisi Oleh',
                          _kondisiAwalData!['filledByName'] ?? '-',
                        ),
                        _buildDetailItem(
                          'Waktu Pengambilan',
                          _formatTimestamp(_kondisiAwalData!['timestamp'] as Timestamp?),
                        ),
                        // Foto kondisi awal
                        if (_kondisiAwalData!['fotoBase64List'] != null &&
                            (_kondisiAwalData!['fotoBase64List'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Foto Kondisi Awal',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          _buildFotoGrid(_kondisiAwalData!['fotoBase64List'] as List),
                        ],
                      ],
                    ),
                  ),
                ],

                // ─── KONDISI AKHIR ───
                if (_kondisiAkhirData != null) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Data Pengembalian',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                              child: Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Data Pengembalian',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_kondisiAkhirData!['statusPengembalian'] != null)
                          _buildStatusPengembalian(_kondisiAkhirData!['statusPengembalian']),

                        // Kondisi
                        if (_kondisiAkhirData!['statusPengembalian'] == 'Ada Perubahan') ...[
                          _buildDetailItem('Kondisi Akhir', _kondisiAkhirData!['kondisiAkhir'] ?? '-'),
                        ] else if (_kondisiAkhirData!['kondisi'] != null) ...[
                          _buildDetailItem('Kondisi Saat Kembali', _kondisiAkhirData!['kondisi']),
                        ],

                        // Kelengkapan
                        if (_kondisiAkhirData!['statusPengembalian'] == 'Ada Perubahan') ...[
                          _buildDetailItem('Kelengkapan Akhir', _kondisiAkhirData!['kelengkapanAkhir'] ?? '-'),
                        ] else if (_kondisiAkhirData!['kelengkapan'] != null) ...[
                          _buildDetailItem('Kelengkapan Saat Kembali', _kondisiAkhirData!['kelengkapan']),
                        ],

                        if (_kondisiAkhirData!['kelengkapanItems'] != null)
                          _buildKelengkapanItems(
                            'Kelengkapan Tersedia Saat Pengembalian',
                            _kondisiAkhirData!['kelengkapanItems'],
                          ),

                        if (_kondisiAkhirData!['uraianKondisi'] != null &&
                            _kondisiAkhirData!['uraianKondisi'].toString().isNotEmpty)
                          _buildDetailItem('Keterangan Perubahan Kondisi', _kondisiAkhirData!['uraianKondisi']),

                        if (_kondisiAkhirData!['uraianKelengkapan'] != null &&
                            _kondisiAkhirData!['uraianKelengkapan'].toString().isNotEmpty)
                          _buildDetailItem('Keterangan Perubahan Kelengkapan', _kondisiAkhirData!['uraianKelengkapan']),

                        _buildDetailItem('Sisa BBM', _kondisiAkhirData!['sisaBBM'] ?? '-'),
                        _buildDetailItem('Odometer Akhir', '${_kondisiAkhirData!['odometerAkhir'] ?? '-'} km'),

                        // Jarak tempuh
                        if (_kondisiAwalData != null &&
                            _kondisiAwalData!['odometerAwal'] != null &&
                            _kondisiAkhirData!['odometerAkhir'] != null) ...[
                          _buildDetailItem(
                            'Jarak Tempuh',
                            '${_kondisiAkhirData!['odometerAkhir'] - _kondisiAwalData!['odometerAwal']} km',
                          ),
                        ],

                        _buildDetailItem(
                          'Dikembalikan Pada',
                          _formatTimestamp(_kondisiAkhirData!['timestampPengembalian'] as Timestamp?),
                        ),

                        if (_kondisiAkhirData!['fotoPengembalianBase64List'] != null &&
                            (_kondisiAkhirData!['fotoPengembalianBase64List'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Foto Kondisi Pengembalian',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          _buildFotoGrid(_kondisiAkhirData!['fotoPengembalianBase64List'] as List),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),

              if (widget.isApprovalMode) ...[
                if ((widget.role == 'operator' && status == 'APPROVAL_1') ||
                    (widget.role == 'admin' && ['APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3'].contains(status))) ...[
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
                  if (status == 'APPROVAL_3') ...[
                    // Tombol Batalkan — admin langsung, operator hanya jika belum ada request pending
                    if (widget.role == 'admin' || widget.role == 'operator') ...[
                      // Cek apakah operator sudah pernah request dan belum diproses
                      if (widget.role == 'operator' && 
                          (_bookingData?['cancellationRequested'] == true)) ...[
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
                              Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Request pembatalan sedang menunggu persetujuan Admin',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
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
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade700, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],

                      // ✅ TOMBOL ISI FORM (khusus Peminjam/Admin)
                      if (canFillForm) ...[
                        Builder(
                          builder: (context) {
                            // Cek apakah sudah H-1 jam sebelum waktu pinjam
                            final bool formTersedia = waktuPinjam != null &&
                                DateTime.now().isAfter(
                                  waktuPinjam.subtract(const Duration(hours: 1)),
                                );

                            // Hitung sisa waktu jika belum tersedia
                            String pesanWaktu = '';
                            if (!formTersedia && waktuPinjam != null) {
                              final batasAwal = waktuPinjam.subtract(const Duration(hours: 1));
                              final durasi = batasAwal.difference(DateTime.now());
                              final jam = durasi.inHours;
                              final menit = durasi.inMinutes % 60;
                              pesanWaktu =
                                  'Form tersedia ${jam > 0 ? "$jam jam " : ""}$menit menit lagi\n'
                                  '(mulai ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(batasAwal)})';
                            }

                            return Column(
                              children: [
                                // Banner info jika belum waktunya
                                if (!formTersedia) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.access_time_rounded,
                                            color: Colors.orange.shade700, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            pesanWaktu,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.orange.shade900,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Tombol — disabled jika belum waktunya
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: formTersedia
                                        ? () {
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
                                          }
                                        : null, // ← disabled otomatis
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: Colors.grey.shade300,
                                      disabledForegroundColor: Colors.grey.shade500,
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
                              ],
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],

                  if (status == 'ON_GOING') ...[
                    if (canFillForm) ...[
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
                    ] else ...[
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
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Menunggu peminjam atau Admin untuk memproses pengembalian kendaraan',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  Widget _buildKelengkapanItems(String label, dynamic items) {
  List<String> kelengkapanList = [];
  if (items is List) {
    kelengkapanList = items.map((e) => e.toString()).toList();
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kelengkapanList.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                    item,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

Widget _buildStatusPengembalian(String status) {
  final isSepertiAwal = status == 'Seperti Awal Peminjaman';

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: isSepertiAwal ? Colors.green.shade50 : Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSepertiAwal ? Colors.green.shade100 : Colors.orange.shade100,
      ),
    ),
    child: Row(
      children: [
        Icon(
          isSepertiAwal ? Icons.check_circle_rounded : Icons.info_rounded,
          color: isSepertiAwal ? Colors.green.shade700 : Colors.orange.shade700,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status Pengembalian',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSepertiAwal ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildFotoGrid(List<dynamic> fotoList) {
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1,
    ),
    itemCount: fotoList.length,
    itemBuilder: (context, index) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(fotoList[index].toString()),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Foto ${index + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      );
    },
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