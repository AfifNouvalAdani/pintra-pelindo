import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../vehicle/vehicle_booking_form_page.dart';
import '../aktivitas/aktivitas_page.dart';
import '../admin/approval_kendaraan_page.dart';
import '../vehicle/detail_peminjaman_page.dart';
import '../profile/profile_page.dart';
import '../admin/manajemen_user_page.dart';
import 'package:pintra/features/admin/manajemen_kendaraan_page.dart';
import '../services/auto_cancel_service.dart';
import 'dart:async';
import 'package:pintra/features/admin/manajemen_ruang_meeting_page.dart';
import '../admin/laporan_peminjaman_kendaraan_page.dart';
import '../ruang_meeting/meeting_room_booking_form_page.dart';
import '../ruang_meeting/approval_ruang_meeting_page.dart';
import '../services/meeting_room_auto_complete_service.dart';
import '../admin/dashboard_monitoring_page.dart';
import '../ruang_meeting/detail_peminjaman_ruang_meeting_page.dart';
import 'ai_chatbot_widget.dart';
import '../gym/gym_booking_form_page.dart';
import '../gym/approval_gym_page.dart';
import '../gym/detail_peminjaman_gym_page.dart';
import '../services/gym_auto_complete_service.dart';
import '../admin/laporan_peminjaman_ruang_meeting_page.dart';
import '../admin/laporan_peminjaman_gym_page.dart';
import 'dart:convert'; // untuk base64Decode
import 'package:carousel_slider/carousel_slider.dart';
import '../setting/banner_service.dart'; // sesuaikan path dengan lokasi file banner_service.dart Anda
import '../setting/home_banner.dart';

// Model kecil untuk data laporan
class _ReportItem {
  final String title;
  final IconData icon;
  final MaterialColor color;
  final VoidCallback onTap;
  const _ReportItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

// Helper Widget untuk Approval Popup
class _ApprovalItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ApprovalItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey),
          ),
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

// Main Dashboard Page
class DashboardPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const DashboardPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late int _currentIndex;
  String? _userJabatan;
  bool _isLoadingJabatan = true;
  Map<String, String>? _userProfileData;
  bool _isLoadingProfileData = false;
  Timer? _reminderTimer;
  
  final BannerService _bannerService = BannerService();

  // ===== TAMBAHAN: Spesialisasi Operator =====
  String? _userOperatorType; // null = umum, 'kendaraan', 'ruang_meeting'

  @override
  void initState() {
    super.initState();
    _checkExpiredBookings();
    _checkExpiredMeetingBookings();
    _checkExpiredGymBookings();
    _currentIndex = 0;
    initializeDateFormatting('id_ID', null);
    _fetchUserJabatan();
    _fetchUserProfileData();
    _startReminderTimer();
  }

  Future<void> _checkExpiredGymBookings() async {
  await GymAutoCompleteService.checkAndCompleteExpiredBookings();
  }

  bool get _isManagerDivisi {
    final jab = (_userJabatan ?? '').toLowerCase();
    return jab.contains('manager');
  }

  Future<void> _checkExpiredMeetingBookings() async {
    await MeetingRoomAutoCompleteService.checkAndCompleteExpiredBookings();
  }

  Future<void> _checkExpiredBookings() async {
    await AutoCancelService.checkAndCancelExpiredBookings();
  }

  void _startReminderTimer() {
    print('⏰ Starting reminder timer...');
    AutoCancelService.checkAndSendReturnReminders();
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      print('⏰ [${now.hour}:${now.minute}] Periodic reminder check triggered');
      AutoCancelService.checkAndSendReturnReminders();
    });
    print('✅ Reminder timer started (every 1 minute)');
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  // Ambil jabatan user dari Firestore (dan operatorType)
  Future<void> _fetchUserJabatan() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _userJabatan = data['jabatan'] ?? 'Staff';
          _userOperatorType = widget.role == 'operator'
              ? data['operatorType'] as String?
              : null;
          _isLoadingJabatan = false;
        });
      } else {
        setState(() {
          _userJabatan = 'Staff';
          _userOperatorType = null;
          _isLoadingJabatan = false;
        });
      }
    } catch (e) {
      print('Error fetching user jabatan: $e');
      setState(() {
        _userJabatan = 'Staff';
        _userOperatorType = null;
        _isLoadingJabatan = false;
      });
    }
  }

  // Ambil data lengkap user dari Firestore untuk profile
  Future<void> _fetchUserProfileData() async {
    try {
      setState(() {
        _isLoadingProfileData = true;
      });

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _userProfileData = {
            'email': data['email'] ?? '-',
            'noTelp': data['noTelp']?.toString() ?? '-',
            'nipp': data['nipp'] ?? widget.userId,
          };
        });
      } else {
        setState(() {
          _userProfileData = {
            'email': '-',
            'noTelp': '-',
            'nipp': widget.userId,
          };
        });
      }
    } catch (e) {
      print('Error fetching user profile data: $e');
      setState(() {
        _userProfileData = {
          'email': '-',
          'noTelp': '-',
          'nipp': widget.userId,
        };
      });
    } finally {
      setState(() {
        _isLoadingProfileData = false;
      });
    }
  }

  Widget _buildDefaultBanner() {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      image: const DecorationImage(
        image: AssetImage('assets/images/banner-dashboard.png'),
        fit: BoxFit.cover,
      ),
    ),
  );
}

Widget _buildBannerImage(String base64String) {
  if (base64String.isEmpty) return _buildDefaultBanner();
  try {
    final clean = base64String.contains(',')
        ? base64String.split(',').last
        : base64String;
    return Image.memory(
      base64Decode(clean),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => _buildDefaultBanner(),
    );
  } catch (_) {
    return _buildDefaultBanner();
  }
}

  // Cek apakah user memiliki peminjaman aktif
  Future<Map<String, dynamic>?> _checkActiveBooking() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('peminjamId', isEqualTo: widget.userId)
          .where('status', whereIn: ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'ON_GOING'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }
      return null;
    } catch (e) {
      print('Error checking active booking: $e');
      return null;
    }
  }

  // Menu items - LOGIKA DIPERBAIKI!
  List<DashboardMenuItem> get menus {
    List<DashboardMenuItem> allMenus = [
      DashboardMenuItem(
        title: 'Peminjaman Mobil',
        icon: Icons.directions_car,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Manajemen Kendaraan',
        icon: Icons.car_repair,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Peminjaman Ruang Meeting',
        icon: Icons.meeting_room,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Manajemen Ruang Meeting',
        icon: Icons.room_preferences,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Peminjaman Ruang Gym',
        icon: Icons.fitness_center,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Approval Peminjaman',
        icon: Icons.approval,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Laporan Kegiatan',
        icon: Icons.assessment,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Dashboard & Monitoring',
        icon: Icons.dashboard,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Manajemen User',
        icon: Icons.people,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
    ];

    if (widget.role == 'user') {
      if (_isManagerDivisi) {
        return [
          allMenus[0],
          allMenus[2],
          allMenus[4],
          allMenus[5],
        ];
      } else {
        return [
          allMenus[0],
          allMenus[2],
          allMenus[4],
        ];
      }
    } else if (widget.role == 'admin') {
      return allMenus;
    } else if (widget.role == 'operator') {
      return allMenus;
    } else if (widget.role == 'manager_umum') {
      return allMenus.where((menu) => menu.title != 'Manajemen User').toList();
    }

    return allMenus;
  }

  Widget _buildGymBookingCard(Map<String, dynamic> booking) {
  final peminjam = booking['peminjam'] as Map<String, dynamic>? ?? {};
  final status = booking['status'] ?? 'UNKNOWN';
  final waktuMulai = booking['waktuMulai'] as Timestamp?;
  final waktuSelesai = booking['waktuSelesai'] as Timestamp?;
  final peminjamNama = peminjam['nama'] ?? '-';
  final peminjamDivisi = peminjam['divisi'] ?? '-';
  final catatan = booking['catatan'] ?? '-';

  final bool isApprovalMode = widget.role != 'user' ||
      (widget.role == 'user' && _isManagerDivisi);

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanGymPage(
            data: booking,
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: isApprovalMode,
            operatorType: _userOperatorType,
          ),
        ),
      ).then((_) {
        setState(() {});
      });
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.fitness_center_outlined,
                        size: 16, color: Colors.orange.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        peminjamNama,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: DashboardHelpers.getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DashboardHelpers.getStatusColor(status)),
                ),
                child: Text(
                  DashboardHelpers.getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DashboardHelpers.getStatusColor(status),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.role != 'user' || (widget.role == 'user' && _isManagerDivisi)) ...[
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Peminjam: $peminjamNama',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Divisi: $peminjamDivisi',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (catatan != '-' && catatan.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.notes_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Catatan: $catatan',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                '${DashboardHelpers.formatDate(waktuMulai)} - ${DashboardHelpers.formatDate(waktuSelesai)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Future<Map<String, int>> _getVehicleStats() async {
    try {
      final vehiclesSnapshot = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('statusAktif', isEqualTo: true)
          .get();

      final totalVehicles = vehiclesSnapshot.docs.length;

      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', isEqualTo: 'ON_GOING')
          .get();

      final unavailableVehicleIds = <String>{};

      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final vehicleId = data['vehicleId'] as String?;
        if (vehicleId != null) {
          unavailableVehicleIds.add(vehicleId);
        }
      }

      final unavailableCount = unavailableVehicleIds.length;
      final availableCount = (totalVehicles - unavailableCount).clamp(0, totalVehicles);

      return {
        'totalVehicles': totalVehicles,
        'ongoingBookings': unavailableCount,
        'availableVehicles': availableCount,
      };
    } catch (e) {
      print('Error fetching vehicle stats: $e');
      return {
        'totalVehicles': 0,
        'ongoingBookings': 0,
        'availableVehicles': 0,
      };
    }
  }

Future<List<Map<String, dynamic>>> _getRecentBookings() async {
  try {
    if (_isLoadingJabatan) return [];

    // ===================== USER BIASA =====================
    if (widget.role == 'user') {
      if (_isManagerDivisi) {
        List<Map<String, dynamic>> kendaraanDocs = [];
        List<Map<String, dynamic>> meetingDocs = [];
        List<Map<String, dynamic>> gymDocs = [];

        try {
          final snap = await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .where('divisi', isEqualTo: widget.userDivision)
              .where('status', isEqualTo: 'SUBMITTED')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .get();
          kendaraanDocs = snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();
        } catch (e) {
          print('Error fetching vehicle bookings manager divisi: $e');
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('room_bookings')
              .where('peminjam.divisi', isEqualTo: widget.userDivision)
              .where('status', isEqualTo: 'SUBMITTED')
              .get();
          meetingDocs = snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, '_isMeetingBooking': true, ...data};
          }).toList();
        } catch (e) {
          print('Error fetching room bookings manager divisi: $e');
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('gym_bookings')
              .where('peminjam.divisi', isEqualTo: widget.userDivision)
              .where('status', isEqualTo: 'SUBMITTED')
              .get();
          gymDocs = snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, '_isGymBooking': true, ...data};
          }).toList();
        } catch (e) {
          print('Error fetching gym bookings manager divisi: $e');
        }

        final combined = [...kendaraanDocs, ...meetingDocs, ...gymDocs];
        combined.sort((a, b) {
          final aT = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bT = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bT.compareTo(aT);
        });
        return combined.take(5).toList();

      } else {
        List<Map<String, dynamic>> kendaraanDocs = [];
        List<Map<String, dynamic>> meetingDocs = [];
        List<Map<String, dynamic>> gymDocs = [];

        try {
          final snap = await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .where('peminjamId', isEqualTo: widget.userId)
              .orderBy('createdAt', descending: true)
              .limit(3)
              .get();
          kendaraanDocs = snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();
        } catch (e) {
          print('Error fetching vehicle bookings user: $e');
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('room_bookings')
              .where('peminjam.userId', isEqualTo: widget.userId)
              .get();
          meetingDocs = snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, '_isMeetingBooking': true, ...data};
          }).toList();
        } catch (e) {
          print('Error fetching room bookings user: $e');
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('gym_bookings')
              .where('peminjam.userId', isEqualTo: widget.userId)
              .get();
          gymDocs = snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, '_isGymBooking': true, ...data};
          }).toList();
        } catch (e) {
          print('Error fetching gym bookings user: $e');
        }

        final combined = [...kendaraanDocs, ...meetingDocs, ...gymDocs];
        combined.sort((a, b) {
          final aT = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bT = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bT.compareTo(aT);
        });
        return combined.take(5).toList();
      }
    }

    // ===================== ADMIN / MANAGER UMUM =====================
    if (widget.role == 'admin' || widget.role == 'manager_umum') {
      List<Map<String, dynamic>> kendaraanDocs = [];
      List<Map<String, dynamic>> meetingDocs = [];
      List<Map<String, dynamic>> gymDocs = [];

      try {
        final snap = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('status', isEqualTo: 'APPROVAL_2')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();
        kendaraanDocs = snap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();
      } catch (e) {
        print('Error fetching vehicle bookings admin: $e');
      }

      try {
        final snap = await FirebaseFirestore.instance
            .collection('room_bookings')
            .where('status', isEqualTo: 'APPROVAL_2')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();
        meetingDocs = snap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, '_isMeetingBooking': true, ...data};
        }).toList();
      } catch (e) {
        print('Error fetching room bookings admin: $e');
      }

      final combined = [...kendaraanDocs, ...meetingDocs];
      combined.sort((a, b) {
        final aT = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bT = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bT.compareTo(aT);
      });
      return combined.take(5).toList();
    }

    // ===================== OPERATOR =====================
    if (widget.role == 'operator') {
      if (_userOperatorType == 'ruang_meeting') {
        List<Map<String, dynamic>> meetingDocs = [];
        List<Map<String, dynamic>> gymDocs = [];

        try {
          final snap = await FirebaseFirestore.instance
              .collection('room_bookings')
              .where('status', isEqualTo: 'APPROVAL_1')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .get();
          meetingDocs = snap.docs
              .where((doc) {
                final data = doc.data();
                final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
                return peminjam['userId'] != widget.userId;
              })
              .map((doc) => {'id': doc.id, '_isMeetingBooking': true, ...doc.data()})
              .toList();
        } catch (e) {
          print('Error fetching room bookings operator ruang_meeting: $e');
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('gym_bookings')
              .where('status', isEqualTo: 'PENDING')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .get();
          gymDocs = snap.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
                return peminjam['userId'] != widget.userId;
              })
              .map((doc) => {'id': doc.id, '_isGymBooking': true, ...doc.data() as Map<String, dynamic>})
              .toList();
        } catch (e) {
          print('Error fetching gym bookings operator ruang_meeting: $e');
        }

        final combined = [...meetingDocs, ...gymDocs];
        combined.sort((a, b) {
          final aT = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bT = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bT.compareTo(aT);
        });
        return combined.take(5).toList();

      } else if (_userOperatorType == 'kendaraan') {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .where('status', isEqualTo: 'APPROVAL_1')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .get();
          return snap.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['peminjamId'] != widget.userId;
              })
              .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
              .toList();
        } catch (e) {
          print('Error fetching vehicle bookings operator kendaraan: $e');
          return [];
        }

      } else {
        List<Map<String, dynamic>> kendaraanDocs = [];
        List<Map<String, dynamic>> meetingDocs = [];
        List<Map<String, dynamic>> gymDocs = [];

        try {
          final snap = await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .where('status', isEqualTo: 'APPROVAL_1')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .get();
          kendaraanDocs = snap.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['peminjamId'] != widget.userId;
              })
              .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
              .toList();
        } catch (e) {
          print('Error fetching vehicle bookings operator umum: $e');
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('room_bookings')
              .where('status', isEqualTo: 'APPROVAL_1')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .get();
          meetingDocs = snap.docs
              .where((doc) {
                final data = doc.data();
                final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
                return peminjam['userId'] != widget.userId;
              })
              .map((doc) => {'id': doc.id, '_isMeetingBooking': true, ...doc.data()})
              .toList();
        } catch (e) {
          print('Error fetching room bookings operator umum: $e');
        }

        try {
          final snap = await FirebaseFirestore.instance
              .collection('gym_bookings')
              .where('status', isEqualTo: 'PENDING')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .get();
          gymDocs = snap.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
                return peminjam['userId'] != widget.userId;
              })
              .map((doc) => {'id': doc.id, '_isGymBooking': true, ...doc.data() as Map<String, dynamic>})
              .toList();
        } catch (e) {
          print('Error fetching gym bookings operator umum: $e');
        }

        final combined = [...kendaraanDocs, ...meetingDocs, ...gymDocs];
        combined.sort((a, b) {
          final aT = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bT = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bT.compareTo(aT);
        });
        return combined.take(5).toList();
      }
    }

    return [];
  } catch (e) {
    print('Error fetching recent bookings: $e');
    return [];
  }
}
Future<int> _getPendingApprovalCount() async {
  try {
    if (_isLoadingJabatan) return 0;

    int kendaraanCount = 0;
    int meetingCount = 0;
    int gymCount = 0;

    final bool countKendaraan = widget.role == 'admin' ||
        widget.role == 'manager_umum' ||
        (widget.role == 'user' && _isManagerDivisi) ||
        (widget.role == 'operator' &&
            (_userOperatorType == null || _userOperatorType == 'kendaraan'));

    if (countKendaraan) {
      Query q = FirebaseFirestore.instance.collection('vehicle_bookings');
      if (widget.role == 'admin' || widget.role == 'manager_umum') {
        q = q.where('status', isEqualTo: 'APPROVAL_2');
      } else if (widget.role == 'user' && _isManagerDivisi) {
        q = q.where('status', isEqualTo: 'SUBMITTED')
             .where('divisi', isEqualTo: widget.userDivision);
      } else if (widget.role == 'operator') {
        q = q.where('status', isEqualTo: 'APPROVAL_1');
      }
      final snap = await q.get();
      kendaraanCount = snap.docs.length;
    }

    final bool countMeeting = widget.role == 'admin' ||
        widget.role == 'manager_umum' ||
        (widget.role == 'user' && _isManagerDivisi) ||
        (widget.role == 'operator' &&
            (_userOperatorType == null || _userOperatorType == 'ruang_meeting'));

    if (countMeeting) {
      Query q = FirebaseFirestore.instance.collection('room_bookings');
      if (widget.role == 'admin' || widget.role == 'manager_umum') {
        q = q.where('status', isEqualTo: 'APPROVAL_2');
      } else if (widget.role == 'user' && _isManagerDivisi) {
        q = q.where('status', isEqualTo: 'SUBMITTED')
             .where('peminjam.divisi', isEqualTo: widget.userDivision);
      } else if (widget.role == 'operator') {
        q = q.where('status', isEqualTo: 'APPROVAL_1');
      }
      final snap = await q.get();
      meetingCount = snap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
        return peminjam['userId'] != widget.userId;
      }).length;
    }

    final bool countGym = widget.role == 'operator' &&
        (_userOperatorType == null || _userOperatorType == 'ruang_meeting');

    if (countGym) {
      final snap = await FirebaseFirestore.instance
          .collection('gym_bookings')
          .where('status', isEqualTo: 'PENDING')
          .get();
      gymCount = snap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
        return peminjam['userId'] != widget.userId;
      }).length;
    }

        return kendaraanCount + meetingCount + gymCount;
      } catch (e) {
        print('Error fetching pending approval count: $e');
        return 0;
      }
    }

  bool _hasAccessToApproval() {
    if (widget.role == 'admin') return true;
    if (widget.role == 'operator') return true;
    if (widget.role == 'manager_umum') return true;
    if (widget.role == 'user' && _isManagerDivisi) return true;
    return false;
  }

  void _showApprovalPopup() {
    // Operator dengan spesialisasi: langsung navigasi
  if (widget.role == 'operator' && _userOperatorType == 'kendaraan') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApprovalKendaraanPage(
          role: widget.role,
          userName: widget.userName,
          userId: widget.userId,
          userDivision: widget.userDivision,
          userJabatan: _userJabatan ?? 'Staff',
          operatorType: _userOperatorType,
        ),
      ),
    );
    return;
  }

  // Operator ruang_meeting: popup dengan pilihan ruang meeting + gym
  if (widget.role == 'operator' && _userOperatorType == 'ruang_meeting') {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApprovalRuangMeetingPage(
                                role: widget.role,
                                userName: widget.userName,
                                userId: widget.userId,
                                userDivision: widget.userDivision,
                                userJabatan: _userJabatan ?? 'Staff',
                                operatorType: _userOperatorType,
                              ),
                            ),
                          );
                        },
                        child: const _ApprovalItem(
                          icon: Icons.meeting_room,
                          label: 'Approval\nRuang Meeting',
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApprovalGymPage(
                                role: widget.role,
                                userName: widget.userName,
                                userId: widget.userId,
                                userDivision: widget.userDivision,
                                userJabatan: _userJabatan ?? 'Staff',
                                operatorType: _userOperatorType,
                              ),
                            ),
                          );
                        },
                        child: const _ApprovalItem(
                          icon: Icons.fitness_center,
                          label: 'Approval\nRuang Gym',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return;
  }

    // Operator umum / admin / manager: tampilkan popup
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label "Operator Umum" jika operator tanpa spesialisasi
                  if (widget.role == 'operator' && _userOperatorType == null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        'Operator Umum — Akses Semua',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ApprovalKendaraanPage(
                                  role: widget.role,
                                  userName: widget.userName,
                                  userId: widget.userId,
                                  userDivision: widget.userDivision,
                                  userJabatan: _userJabatan ?? 'Staff',
                                  operatorType: _userOperatorType,
                                ),
                              ),
                            );
                          },
                          child: const _ApprovalItem(
                            icon: Icons.directions_car,
                            label: 'Approval\nKendaraan',
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ApprovalRuangMeetingPage(
                                  role: widget.role,
                                  userName: widget.userName,
                                  userId: widget.userId,
                                  userDivision: widget.userDivision,
                                  userJabatan: _userJabatan ?? 'Staff',
                                  operatorType: _userOperatorType,
                                ),
                              ),
                            );
                          },
                          child: const _ApprovalItem(
                            icon: Icons.meeting_room,
                            label: 'Approval\nRuang Meeting',
                          ),
                        ),
                        // ← TAMBAH INI
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ApprovalGymPage(
                                  role: widget.role,
                                  userName: widget.userName,
                                  userId: widget.userId,
                                  userDivision: widget.userDivision,
                                  userJabatan: _userJabatan ?? 'Staff',
                                  operatorType: _userOperatorType,
                                ),
                              ),
                            );
                          },
                          child: const _ApprovalItem(
                            icon: Icons.fitness_center,
                            label: 'Approval\nRuang Gym',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

    Future<Map<String, int>> _getRoomStats() async {
    try {
      // Total ruang aktif
      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where('status', isEqualTo: 'available')
          .get();
      final totalRooms = roomsSnapshot.docs.length;

      // Ruang yang sedang dipakai = booking aktif sekarang
      final now = Timestamp.now();
      final activeBookings = await FirebaseFirestore.instance
          .collection('room_bookings')
          .where('status', isEqualTo: 'APPROVAL_3')
          .where('waktuMulai', isLessThanOrEqualTo: now)
          .where('waktuSelesai', isGreaterThan: now)
          .get();

      final busyRoomIds = activeBookings.docs
          .map((doc) => doc.data()['ruang']?['roomId'] as String?)
          .where((id) => id != null)
          .toSet();

      final availableRooms = (totalRooms - busyRoomIds.length).clamp(0, totalRooms);

      return {
        'totalRooms': totalRooms,
        'availableRooms': availableRooms,
      };
    } catch (e) {
      print('Error fetching room stats: $e');
      return {'totalRooms': 0, 'availableRooms': 0};
    }
  }

void _showLaporanPopup() {
  // Cek apakah user berhak melihat laporan gym
  final bool canAccessGymReport = widget.role == 'admin' ||
      (widget.role == 'operator' &&
          (_userOperatorType == null || _userOperatorType == 'ruang_meeting'));

  // Daftar item yang akan ditampilkan
  final List<_ReportItem> items = [];

  // Laporan Kendaraan
  if (widget.role == 'admin' ||
      (widget.role == 'operator' &&
          (_userOperatorType == null || _userOperatorType == 'kendaraan'))) {
    items.add(_ReportItem(
      title: 'Kendaraan',
      icon: Icons.directions_car,
      color: Colors.blue,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LaporanPeminjamanKendaraanPage(
              role: widget.role,
              userName: widget.userName,
              userId: widget.userId,
              userDivision: widget.userDivision,
            ),
          ),
        );
      },
    ));
  }

  // Laporan Ruang Meeting
  if (widget.role == 'admin' ||
      (widget.role == 'operator' &&
          (_userOperatorType == null || _userOperatorType == 'ruang_meeting'))) {
    items.add(_ReportItem(
      title: 'Ruang Meeting',
      icon: Icons.meeting_room,
      color: Colors.teal,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LaporanPeminjamanRuangMeetingPage(
              role: widget.role,
              userName: widget.userName,
              userId: widget.userId,
              userDivision: widget.userDivision,
            ),
          ),
        );
      },
    ));
  }

  // Laporan Gym
  if (canAccessGymReport) {
    items.add(_ReportItem(
      title: 'Ruang Gym',
      icon: Icons.fitness_center,
      color: Colors.orange,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LaporanPeminjamanGymPage(
              role: widget.role,
              userName: widget.userName,
              userId: widget.userId,
              userDivision: widget.userDivision,
            ),
          ),
        );
      },
    ));
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (_) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header dengan tombol tutup
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Laporan Kegiatan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Garis pemisah tipis
              Divider(height: 1, color: Colors.grey.shade200, indent: 24, endIndent: 24),
              const SizedBox(height: 16),
              // Grid kartu laporan
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: item.onTap,
                        borderRadius: BorderRadius.circular(16),
                        splashColor: item.color.withOpacity(0.1),
                        highlightColor: item.color.withOpacity(0.05),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                item.color.shade50,
                                item.color.shade100.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.color.shade100,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: item.color.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: item.color.withOpacity(0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 28,
                                  color: item.color.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Flexible(
                                child: Text(
                                  item.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: item.color.shade800,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildMeetingBookingCard(Map<String, dynamic> booking) {
  final peminjam = booking['peminjam'] as Map<String, dynamic>? ?? {};
  final namaKegiatan = booking['namaKegiatan'] ?? '-';
  final status = booking['status'] ?? 'UNKNOWN';
  final waktuMulai = booking['waktuMulai'] as Timestamp?;
  final waktuSelesai = booking['waktuSelesai'] as Timestamp?;
  final peminjamNama = peminjam['nama'] ?? '-';
  final peminjamDivisi = peminjam['divisi'] ?? '-';

  final bool isApprovalMode = widget.role != 'user' ||
      (widget.role == 'user' && _isManagerDivisi);

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanRuangMeetingPage(
            data: booking,
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: isApprovalMode,
          ),
        ),
      ).then((_) {
        setState(() {});
      });
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.meeting_room_outlined,
                        size: 16, color: Colors.teal.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        namaKegiatan,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: DashboardHelpers.getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DashboardHelpers.getStatusColor(status)),
                ),
                child: Text(
                  DashboardHelpers.getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DashboardHelpers.getStatusColor(status),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.role != 'user' || (widget.role == 'user' && _isManagerDivisi)) ...[
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Peminjam: $peminjamNama',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Divisi: $peminjamDivisi',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                '${DashboardHelpers.formatDate(waktuMulai)} - ${DashboardHelpers.formatDate(waktuSelesai)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildBookingCard(Map<String, dynamic> booking) {
  if (booking['_isGymBooking'] == true) {
    return _buildGymBookingCard(booking);
  } else if (booking['_isMeetingBooking'] == true) {
    return _buildMeetingBookingCard(booking);
  }

  final vehicle = booking['vehicle'] as Map<String, dynamic>? ?? {};
  final platNomor = vehicle['platNomor'] ?? 'Tanpa Plat';
  final tujuan = booking['tujuan'] ?? 'Tidak diketahui';
  final status = booking['status'] ?? 'UNKNOWN';
  final waktuPinjam = booking['waktuPinjam'] as Timestamp?;
  final waktuKembali = booking['waktuKembali'] as Timestamp?;
  final peminjamNama = booking['namaPeminjam'] ?? '';
  final peminjamDivisi = booking['divisi'] ?? '';

  final isApprovalMode = widget.role != 'user' ||
      (widget.role == 'user' && _isManagerDivisi);

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanPage(
            data: booking,
            approvalStep: 0,
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: isApprovalMode,
            operatorType: _userOperatorType,
          ),
        ),
      ).then((_) {
        setState(() {});
      });
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  platNomor,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: DashboardHelpers.getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DashboardHelpers.getStatusColor(status)),
                ),
                child: Text(
                  DashboardHelpers.getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DashboardHelpers.getStatusColor(status),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.role != 'user' || (widget.role == 'user' && _isManagerDivisi)) ...[
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Peminjam: $peminjamNama',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Divisi: $peminjamDivisi',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Icon(Icons.place, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Tujuan: $tujuan',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                '${DashboardHelpers.formatDate(waktuPinjam)} - ${DashboardHelpers.formatDate(waktuKembali)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildMenuItem(DashboardMenuItem item) {
    if (item.title == 'Approval Peminjaman' &&
        widget.role == 'user' &&
        _isLoadingJabatan) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (item.title == 'Peminjaman Mobil') {
            final activeBooking = await _checkActiveBooking();
            if (activeBooking != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailPeminjamanPage(
                    data: activeBooking,
                    approvalStep: 0,
                    role: widget.role,
                    userName: widget.userName,
                    userId: widget.userId,
                    userDivision: widget.userDivision,
                    isApprovalMode: false,
                    operatorType: _userOperatorType,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleBookingFormPage(
                    role: widget.role,
                    userName: widget.userName,
                    userId: widget.userId,
                    userDivision: widget.userDivision,
                  ),
                ),
              );
            }
          } else if (item.title == 'Approval Peminjaman') {
            if (_hasAccessToApproval()) {
              _showApprovalPopup();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Anda tidak memiliki izin untuk approval'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else if (item.title == 'Manajemen User') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManajemenUserPage(
                  role: widget.role,
                  userName: widget.userName,
                  userId: widget.userId,
                  userDivision: widget.userDivision,
                ),
              ),
            );
          } else if (item.title == 'Manajemen Kendaraan') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManajemenKendaraanPage(
                  role: widget.role,
                  userName: widget.userName,
                  userId: widget.userId,
                  userDivision: widget.userDivision,
                ),
              ),
            );
          } else if (item.title == 'Manajemen Ruang Meeting') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManajemenRuangMeetingPage(
                  role: widget.role,
                  userName: widget.userName,
                  userId: widget.userId,
                  userDivision: widget.userDivision,
                ),
              ),
            );
          } else if (item.title == 'Laporan Kegiatan') {
            _showLaporanPopup();
          } else if (item.title == 'Peminjaman Ruang Meeting') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MeetingRoomBookingFormPage(
                  role: widget.role,
                  userName: widget.userName,
                  userId: widget.userId,
                  userDivision: widget.userDivision,
                ),
              ),
            ).then((_) {
              setState(() {});
            });
          } else if (item.title == 'Dashboard & Monitoring') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DashboardMonitoringPage(
                    role: widget.role,
                    userName: widget.userName,
                    userId: widget.userId,
                    userDivision: widget.userDivision,
                    operatorType: _userOperatorType,
                  ),
                ),
              );
            } else if (item.title == 'Peminjaman Ruang Gym') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GymBookingFormPage(
                      role: widget.role,
                      userName: widget.userName,
                      userId: widget.userId,
                      userDivision: widget.userDivision,
                    ),
                  ),
                );
              }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.title == 'Approval Peminjaman' && _hasAccessToApproval())
                  FutureBuilder<int>(
                    future: _getPendingApprovalCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count > 0) {
                        return Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox(height: 14);
                    },
                  )
                else
                  const SizedBox(height: 14),

                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      size: 26,
                      color: item.iconColor,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Flexible(
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM y', 'id_ID').format(now);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/logo-pelindo.webp',
                    height: 32,
                    color: Colors.blue.shade800,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Text(
                          widget.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_userJabatan != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Text(
                            _userJabatan!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade100,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 24,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang, ${widget.userName}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24),
  child: SizedBox(
    height: 140,
    child: StreamBuilder<List<HomeBanner>>(
      stream: _bannerService.streamActiveBanners(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDefaultBanner();
        }

        // Error state → fallback ke gambar default
        if (snapshot.hasError) {
          debugPrint('Banner stream error: ${snapshot.error}');
          return _buildDefaultBanner();
        }

        final banners = snapshot.data ?? [];

        // Data kosong → fallback ke gambar default
        if (banners.isEmpty) {
          return _buildDefaultBanner();
        }

        // Hanya 1 banner → tampilkan langsung tanpa carousel
        if (banners.length == 1) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildBannerImage(banners.first.imageBase64),
          );
        }

        // 2–3 banner → tampilkan carousel
            return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CarouselSlider(
            options: CarouselOptions(
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              enlargeCenterPage: false,
              viewportFraction: 1.0,
              height: 140, // ← pakai height, bukan aspectRatio
            ),
            items: banners.map((banner) {
              return SizedBox(
                width: double.infinity,
                height: 140,
                child: _buildBannerImage(banner.imageBase64),
              );
            }).toList(),
          ),
        );
      },
    ),
  ),
),

            const SizedBox(height: 32),

            FutureBuilder<Map<String, int>>(
              future: _getVehicleStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(loading: true, isVehicle: false),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(loading: true, isVehicle: true),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Center(
                        child: Text(
                          'Error memuat data',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  );
                }

                final stats = snapshot.data ?? {'totalVehicles': 0, 'ongoingBookings': 0};
                final totalVehicles = stats['totalVehicles'] ?? 0;
                final ongoingBookings = stats['ongoingBookings'] ?? 0;
                final availableVehicles = totalVehicles - ongoingBookings;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                    Expanded(
                      child: FutureBuilder<Map<String, int>>(
                        future: _getRoomStats(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildStatCard(loading: true, isVehicle: false);
                          }
                          final roomStats = snapshot.data ?? {'totalRooms': 0, 'availableRooms': 0};
                          final totalRooms = roomStats['totalRooms'] ?? 0;
                          final availableRooms = roomStats['availableRooms'] ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '$availableRooms/$totalRooms',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: availableRooms > 0 ? Colors.blue : Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Ruang Meeting Tersedia',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.blue),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.shade100,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '$availableVehicles/$totalVehicles',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: availableVehicles > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Kendaraan Tersedia',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                              if (ongoingBookings > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${ongoingBookings} sedang dipinjam',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Peminjaman Terkini
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getRecentBookingsTitle(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List Peminjaman Terkini
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getRecentBookings(),
              builder: (context, snapshot) {
                if (_isLoadingJabatan && widget.role == 'user') {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Center(
                        child: Text(
                          'Error memuat data',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  );
                }

                final bookings = snapshot.data ?? [];

                if (bookings.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          _getNoBookingsMessage(),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: bookings.map((booking) {
                      return _buildBookingCard(booking);
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Menu Grid Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  const Text(
                    'Menu Utama',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Grid Menu
            if (widget.role == 'user' && _isLoadingJabatan)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: menus.length,
                  itemBuilder: (context, index) {
                    final item = menus[index];
                    return _buildMenuItem(item);
                  },
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: Stack(
      children: [
        SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildDashboardContent(),
              AktivitasPage(
                role: widget.role,
                userName: widget.userName,
                userId: widget.userId,
                userDivision: widget.userDivision,
              ),
              _buildProfileTab(),
            ],
          ),
        ),
        AIChatbotWidget(
          userId: widget.userId,
          userDivision: widget.userDivision,
          userName: widget.userName,
        ),
      ],
    ),
    bottomNavigationBar: _buildBottomNavigationBar(),
  );
}

  // Helper method untuk judul peminjaman terkini
  String _getRecentBookingsTitle() {
    if (widget.role == 'user') {
      if (_isManagerDivisi) {
        return 'Peminjaman Menunggu Approval Divisi ${widget.userDivision}';
      }
      return 'Peminjaman Terkini Saya';
    } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
      return 'Peminjaman Menunggu Approval Manager Umum';
    } else if (widget.role == 'operator') {
      if (_userOperatorType == 'ruang_meeting') {
        return 'Ruang Meeting dan Gym Menunggu Verifikasi';
      } else if (_userOperatorType == 'kendaraan') {
        return 'Kendaraan Menunggu Verifikasi';
      } else {
        return 'Peminjaman Menunggu Verifikasi Operator';
      }
    }
    return 'Peminjaman Terkini';
  }

  // Helper method untuk pesan ketika tidak ada peminjaman
  String _getNoBookingsMessage() {
    if (widget.role == 'user') {
      if (_isManagerDivisi) {
        return 'Tidak ada peminjaman menunggu approval dari divisi ${widget.userDivision}';
      }
      return 'Belum ada peminjaman';
    } else if (widget.role == 'admin' || widget.role == 'manager_umum') {
      return 'Tidak ada peminjaman yang menunggu approval manager umum';
    } else if (widget.role == 'operator') {
      if (_userOperatorType == 'ruang_meeting') {
        return 'Tidak ada peminjaman ruang meeting dan gym yang menunggu verifikasi';
      } else if (_userOperatorType == 'kendaraan') {
        return 'Tidak ada peminjaman kendaraan yang menunggu verifikasi';
      } else {
        return 'Tidak ada peminjaman yang menunggu verifikasi operator';
      }
    }
    return 'Tidak ada peminjaman';
  }

  // Helper widget untuk stat card loading
  Widget _buildStatCard({bool loading = false, bool isVehicle = true}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVehicle ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVehicle ? Colors.green.shade100 : Colors.blue.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          loading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  '...',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            isVehicle ? 'Kendaraan Operasional' : 'Ruang Meeting',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // Profile Tab dengan data lengkap
  Widget _buildProfileTab() {
    if (_isLoadingProfileData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ProfilePage(
      userId: widget.userId,
      role: widget.role
    );
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 0) {
              setState(() {});
            }
          });
        },
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        iconSize: 28,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: _currentIndex == 0
                  ? BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              child: Icon(
                _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                size: 24,
              ),
            ),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: _currentIndex == 1
                  ? BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              child: Icon(
                _currentIndex == 1 ? Icons.history : Icons.history_outlined,
                size: 24,
              ),
            ),
            label: 'Aktivitas',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: _currentIndex == 2
                  ? BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              child: Icon(
                _currentIndex == 2 ? Icons.person : Icons.person_outline,
                size: 24,
              ),
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// Menu Item Model
class DashboardMenuItem {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  DashboardMenuItem({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
}

// Helper Class untuk Dashboard
class DashboardHelpers {
  static String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMM HH:mm', 'id_ID').format(date);
  }

  static Color getStatusColor(String status) {
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
      // ── Tambahan untuk gym ──
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      // ────────────────────────
      default:
        return Colors.grey;
    }
  }
  static String getStatusLabel(String status) {
    switch (status) {
      case 'SUBMITTED':
        return 'Menunggu Manager Divisi';
      case 'APPROVAL_1':
        return 'Disetujui Manager Divisi';
      case 'APPROVAL_2':
        return 'Disetujui Operator';
      case 'APPROVAL_3':
        return 'Disetujui Manager Umum';
      case 'ON_GOING':
        return 'Sedang Digunakan';
      case 'DONE':
        return 'Selesai';
      case 'CANCELLED':
        return 'Ditolak';
      // ── Tambahan untuk gym ──
      case 'PENDING':
        return 'Menunggu Verifikasi';
      case 'APPROVED':
        return 'Disetujui Operator';
      // ────────────────────────
      default:
        return status;
    }
  }
}