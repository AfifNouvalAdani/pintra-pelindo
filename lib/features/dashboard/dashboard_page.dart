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

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    initializeDateFormatting('id_ID', null);
    _fetchUserJabatan();
    _fetchUserProfileData();
  }

  bool get _isManagerDivisi {
    final jab = (_userJabatan ?? '').toLowerCase();
    return jab.contains('manager');
  }

  // Ambil jabatan user dari Firestore
  Future<void> _fetchUserJabatan() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _userJabatan = userDoc.data()?['jabatan'] ?? 'Staff';
          _isLoadingJabatan = false;
        });
      } else {
        setState(() {
          _userJabatan = 'Staff';
          _isLoadingJabatan = false;
        });
      }
    } catch (e) {
      print('Error fetching user jabatan: $e');
      setState(() {
        _userJabatan = 'Staff';
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
            'noTelp': data['noTelp'] ?? '-',
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
      // Gunakan _isManagerDivisi, BUKAN _userJabatan == 'Manager'
      if (_isManagerDivisi) {
        // Manager Divisi (role tetap user) -> dapat menu Approval
        return [
          allMenus[0], // Peminjaman Mobil
          allMenus[2], // Peminjaman Ruang Meeting
          allMenus[4], // Peminjaman Ruang Gym
          allMenus[5], // Approval Peminjaman
            ];
      } else {
        return [
          allMenus[0], // Peminjaman Mobil
          allMenus[2], // Peminjaman Ruang Meeting
          allMenus[4], // Peminjaman Ruang Gym
        ];
      }
    } else if (widget.role == 'admin') {
      return allMenus;
    } else if (widget.role == 'operator') {
      return allMenus.where((menu) => menu.title != 'Manajemen User').toList();
    } else if (widget.role == 'manager_umum') {
      return allMenus.where((menu) => menu.title != 'Manajemen User').toList();
    }

    return allMenus;
  }

  // Fungsi untuk mengambil statistik kendaraan
  Future<Map<String, int>> _getVehicleStats() async {
    try {
      // 1. Ambil semua kendaraan aktif
      final vehiclesSnapshot = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('statusAktif', isEqualTo: true)
          .get();
      
      // 2. Ambil kendaraan yang sedang dipinjam (status ON_GOING)
      final ongoingBookingsSnapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', isEqualTo: 'ON_GOING')
          .get();
      
      return {
        'totalVehicles': vehiclesSnapshot.docs.length,
        'ongoingBookings': ongoingBookingsSnapshot.docs.length,
      };
    } catch (e) {
      print('Error fetching vehicle stats: $e');
      return {'totalVehicles': 0, 'ongoingBookings': 0};
    }
  }

  // Fungsi untuk mengambil booking terbaru - LOGIKA DIPERBAIKI!
  Future<List<Map<String, dynamic>>> _getRecentBookings() async {
    try {
      if (_isLoadingJabatan) {
        return [];
      }

      QuerySnapshot snapshot;
      
      if (widget.role == 'user') {
        // Gunakan _isManagerDivisi
        if (_isManagerDivisi) {
          // Manager Divisi: melihat SUBMITTED dari divisinya
          snapshot = await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .where('divisi', isEqualTo: widget.userDivision)
              .where('status', isEqualTo: 'SUBMITTED')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .get();
          
          print('Found ${snapshot.docs.length} bookings for Manager Divisi (SUBMITTED)');
          
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();
        } else {
          // User biasa: ambil semua bookingnya
          snapshot = await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .where('peminjamId', isEqualTo: widget.userId)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .get();
                
          // Filter untuk user biasa (semua status)
          List<String> allowedStatuses = ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'ON_GOING', 'DONE', 'CANCELLED'];
          
          final filtered = snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return allowedStatuses.contains(data['status']);
          }).take(5).toList();
          
          return filtered.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();
        }
              
      } else if (widget.role == 'admin') {
        // Manager Umum: melihat booking yang APPROVAL_2
        snapshot = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('status', isEqualTo: 'APPROVAL_2')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
        
        print('Found ${snapshot.docs.length} bookings for Manager Umum (APPROVAL_2)');
        
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();
            
      } else if (widget.role == 'operator') {
        // Operator: melihat booking yang APPROVAL_1
        snapshot = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('status', isEqualTo: 'APPROVAL_1')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
        
        print('Found ${snapshot.docs.length} bookings for operator (APPROVAL_1)');
        
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();
              
      } else if (widget.role == 'manager_umum') {
        // Manager Umum (alternatif): melihat booking yang APPROVAL_2
        snapshot = await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .where('status', isEqualTo: 'APPROVAL_2')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
        
        print('Found ${snapshot.docs.length} bookings for manager_umum (APPROVAL_2)');
        
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();
              
      } else {
        return [];
      }
      
    } catch (e) {
      print('Error fetching recent bookings: $e');
      return [];
    }
  }

  // Fungsi untuk mengambil jumlah approval yang menunggu - LOGIKA DIPERBAIKI!
  Future<int> _getPendingApprovalCount() async {
    try {
      if (_isLoadingJabatan) {
        return 0;
      }

      Query query = FirebaseFirestore.instance.collection('vehicle_bookings');
      
      if (widget.role == 'admin') {
        // Manager Umum: hitung APPROVAL_2
        query = query.where('status', isEqualTo: 'APPROVAL_2');
              
      } else if (widget.role == 'user' && _isManagerDivisi) {
        // Gunakan _isManagerDivisi
        // Manager Divisi: hitung SUBMITTED dari divisinya
        query = query
            .where('status', isEqualTo: 'SUBMITTED')
            .where('divisi', isEqualTo: widget.userDivision);
          
      } else if (widget.role == 'operator') {
        // Operator: hitung APPROVAL_1
        query = query.where('status', isEqualTo: 'APPROVAL_1');
          
      } else if (widget.role == 'manager_umum') {
        // Manager Umum (alternatif): hitung APPROVAL_2
        query = query.where('status', isEqualTo: 'APPROVAL_2');
          
      } else {
        return 0;
      }
      
      final snapshot = await query.get();
      return snapshot.docs.length;
        
    } catch (e) {
      print('Error fetching pending approval count: $e');
      return 0;
    }
  }

  // Cek apakah user memiliki akses approval - LOGIKA DIPERBAIKI!
  bool _hasAccessToApproval() {
    if (widget.role == 'admin') return true;
    if (widget.role == 'operator') return true;
    if (widget.role == 'manager_umum') return true;
    // Gunakan _isManagerDivisi
    if (widget.role == 'user' && _isManagerDivisi) return true;
    return false;
  }

  // Popup untuk Approval
  void _showApprovalPopup() {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur Approval Ruang Meeting dalam pengembangan'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                    child: const _ApprovalItem(
                      icon: Icons.meeting_room,
                      label: 'Approval\nRuang Meeting',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget untuk booking card
  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final vehicle = booking['vehicle'] as Map<String, dynamic>? ?? {};
    final platNomor = vehicle['platNomor'] ?? 'Tanpa Plat';
    final tujuan = booking['tujuan'] ?? 'Tidak diketahui';
    final status = booking['status'] ?? 'UNKNOWN';
    final waktuPinjam = booking['waktuPinjam'] as Timestamp?;
    final waktuKembali = booking['waktuKembali'] as Timestamp?;
    final peminjamNama = booking['namaPeminjam'] ?? '';
    final peminjamDivisi = booking['divisi'] ?? '';
      
    return Container(
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
            ],
          ),
          const SizedBox(height: 8),
          // Tampilkan info peminjam untuk selain user biasa
          if (widget.role != 'user' || (widget.role == 'user' && _isManagerDivisi)) ...[
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Peminjam: $peminjamNama',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
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
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build menu item dengan pengecekan loading
  Widget _buildMenuItem(DashboardMenuItem item) {
    // Jika menu Approval dan masih loading jabatan untuk user, tampilkan loading
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
            // Cek apakah user memiliki peminjaman aktif
            final activeBooking = await _checkActiveBooking();
            
            if (activeBooking != null) {
              // Jika ada peminjaman aktif, arahkan ke detail peminjaman
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
                  ),
                ),
              );
            } else {
              // Jika tidak ada peminjaman aktif, arahkan ke form booking
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
            }
          // TODO: Tambahkan navigasi untuk menu lainnya
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
                // Badge untuk approval count
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
                      return const SizedBox(height: 14); // jaga tinggi tetap konsisten
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

  // Widget untuk konten dashboard utama
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
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/logo-pelindo.webp',
                    height: 32,
                    color: Colors.blue.shade800,
                  ),
                  // Role Badge
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

            // Welcome Section
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

            // Banner sederhana
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/banner-dashboard.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Quick Stats
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
                      // Statistik Ruang Meeting
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade100,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 4),
                              const Text(
                                '3/5',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Ruang Meeting Tersedia',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Statistik Kendaraan
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
                                'Kendaraan Operasional Tersedia',
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

            // Peminjaman Terkini - JUDUL DIPERBAIKI
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

            // Grid Menu - TUNGGU JIKA MASIH LOADING JABATAN UNTUK MANAGER
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
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 0: Dashboard
            _buildDashboardContent(),
            
            // Tab 1: Aktivitas
            AktivitasPage(
              role: widget.role,
              userName: widget.userName,
              userId: widget.userId,
              userDivision: widget.userDivision,
            ),
            
            // Tab 2: Profile (dengan data lengkap)
            _buildProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Helper method untuk judul peminjaman terkini
  String _getRecentBookingsTitle() {
    if (widget.role == 'user') {
      // Gunakan _isManagerDivisi
      if (_isManagerDivisi) {
        return 'Peminjaman Menunggu Approval Divisi ${widget.userDivision}';
      } else {
        return 'Peminjaman Terkini Saya';
      }
    } else if (widget.role == 'admin') {
      return 'Peminjaman Menunggu Approval Manager Umum';
    } else if (widget.role == 'operator') {
      return 'Peminjaman Menunggu Verifikasi Operator';
    } else if (widget.role == 'manager_umum') {
      return 'Peminjaman Menunggu Approval Manager Umum';
    } else {
      return 'Peminjaman Terkini';
    }
  }

  // Helper method untuk pesan ketika tidak ada peminjaman
  String _getNoBookingsMessage() {
    if (widget.role == 'user') {
      // Gunakan _isManagerDivisi
      if (_isManagerDivisi) {
        return 'Tidak ada peminjaman yang menunggu approval dari divisi ${widget.userDivision}';
      } else {
        return 'Belum ada peminjaman kendaraan';
      }
    } else if (widget.role == 'admin') {
      return 'Tidak ada peminjaman yang menunggu approval manager umum';
    } else if (widget.role == 'operator') {
      return 'Tidak ada peminjaman yang menunggu verifikasi operator';
    } else if (widget.role == 'manager_umum') {
      return 'Tidak ada peminjaman yang menunggu approval manager umum';
    } else {
      return 'Tidak ada peminjaman';
    }
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
      userId: widget.userId,  // ✅ HANYA KIRIM userId
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
            // Refresh data ketika kembali ke dashboard
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
      default:
        return status;
    }
  }
}