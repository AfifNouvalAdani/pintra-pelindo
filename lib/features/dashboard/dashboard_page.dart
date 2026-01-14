import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../vehicle/vehicle_booking_form_page.dart';
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

class DashboardPage extends StatefulWidget {
  final String role;
  final String userName;

  const DashboardPage({
    super.key,
    required this.role,
    required this.userName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
  }

  List<DashboardMenuItem> get menus {
    final allMenus = [
      DashboardMenuItem(
        title: 'Peminjaman Mobil',
        iconPath: 'assets/images/booking-kendaraan.png',
        iconSize: 36,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Manajemen Kendaraan',
        iconPath: 'assets/images/manajemen-mobil.png',
        iconSize: 50,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Peminjaman Ruang Meeting',
        iconPath: 'assets/images/booking-ruang-meeting.png',
        iconSize: 44,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Manajemen Ruang Meeting',
        iconPath: 'assets/images/manajemen-ruang-meeting.png',
        iconSize: 50,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Peminjaman Ruang Gym',
        iconPath: 'assets/images/booking-ruang-gym.png',
        iconSize: 42,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Approval Peminjaman',
        iconPath: 'assets/images/approval.png',
        iconSize: 44,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Laporan Kegiatan',
        iconPath: 'assets/images/laporan-kegiatan.png',
        iconSize: 35,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Dashboard & Monitoring',
        iconPath: 'assets/images/monitoring.png',
        iconSize: 40,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
      DashboardMenuItem(
        title: 'Manajemen User',
        iconPath: 'assets/images/manajemen-user.png',
        iconSize: 44,
        backgroundColor: Colors.blue.shade50,
        iconColor: Colors.blue.shade700,
      ),
    ];

    if (widget.role == 'user') {
      return allMenus.take(3).toList();
    }
    return allMenus;
  }

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
                children: const [
                  _ApprovalItem(
                    icon: Icons.directions_car,
                    label: 'Approval\nKendaraan',
                  ),
                  _ApprovalItem(
                    icon: Icons.meeting_room,
                    label: 'Approval\nRuang Meeting',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM y', 'id_ID').format(now);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _currentIndex == 0
            ? SingleChildScrollView(
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
                          Image.asset(
                            'assets/images/logo-pelindo.webp',
                            height: 28,
                            color: Colors.blue.shade800,
                          ),
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
                    ),

                    // Welcome Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat Datang, ${widget.userName}',
                            style: TextStyle(
                              fontSize: 18,
                              color: const Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: const Color.fromARGB(255, 97, 97, 97),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/banner-dashboard.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Quick Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
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
                                  Text(
                                    '3/5',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ruang Meeting Tersedia',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                                ],
                              ),
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
                                    '1/3',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kendaraan Operasional Tersedia',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
                          Text(
                            'Menu Utama',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Grid Menu
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
              )
            : _currentIndex == 1
                : _buildProfileTab(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildMenuItem(DashboardMenuItem item) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // PERBAIKAN: Tambahkan kedua kondisi navigasi
          if (item.title == 'Peminjaman Mobil') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VehicleBookingFormPage(
                  role: widget.role,
                  userName: widget.userName,
                ),
              ),
            );
          } else if (item.title == 'Approval Peminjaman') {
            _showApprovalPopup();
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
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: item.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      item.iconPath,
                      width: item.iconSize,
                      height: item.iconSize,
                      color: item.iconColor,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Profil',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
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
      ),
      const Expanded(
        child: Center(
          child: Text(
            'Fitur profil dalam pengembangan',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    ],
  );
}


  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: TextStyle(fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        iconSize: 36,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Aktivitas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class DashboardMenuItem {
  final String title;
  final String iconPath;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;

  DashboardMenuItem({
    required this.title,
    required this.iconPath,
    this.iconSize = 36,
    required this.backgroundColor,
    required this.iconColor,
  });
}