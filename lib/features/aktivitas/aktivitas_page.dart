import 'package:flutter/material.dart';
import '../vehicle/detail_peminjaman_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AktivitasPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const AktivitasPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<AktivitasPage> createState() => _AktivitasPageState();
}


class _AktivitasPageState extends State<AktivitasPage> {
  bool showOnGoing = true;
  bool _isLoading = false;
  List<Map<String, dynamic>> _onGoingList = [];
  List<Map<String, dynamic>> _historyList = [];
  
  // Hapus semua dummy data onGoingList dan historyList yang lama

    @override
  void initState() {
    super.initState();
    _loadData();
  }

    Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchOnGoingBookings(),
      _fetchHistoryBookings(),
    ]);
    setState(() => _isLoading = false);
  }

Future<void> _fetchOnGoingBookings() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .where('peminjamId', isEqualTo: widget.userId)
        .where('status', whereIn: ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'ON_GOING'])
        .get(); // Hapus orderBy dari query

    // Sort di memory setelah data diambil
    _onGoingList = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
    
    // Sort by waktuPinjam descending
    _onGoingList.sort((a, b) {
      final aTime = (a['waktuPinjam'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTime = (b['waktuPinjam'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime); // Descending
    });
    
    print('Found ${_onGoingList.length} ongoing bookings');
  } catch (e) {
    print('Error fetching ongoing bookings: $e');
    _onGoingList = [];
  }
}

Future<void> _fetchHistoryBookings() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .where('peminjamId', isEqualTo: widget.userId)
        .where('status', whereIn: ['DONE', 'CANCELLED'])
        .get(); // Hapus orderBy dan limit dari query

    _historyList = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
    
    // Sort by updatedAt descending
    _historyList.sort((a, b) {
      final aTime = (a['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTime = (b['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime); // Descending
    });
    
    // Limit to 20 items
    if (_historyList.length > 20) {
      _historyList = _historyList.sublist(0, 20);
    }
    
    print('Found ${_historyList.length} history bookings');
  } catch (e) {
    print('Error fetching history bookings: $e');
    _historyList = [];
  }
}
    String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('HH:mm', 'id_ID').format(date);
  }

  String _getVehicleDisplay(Map<String, dynamic> item) {
    final vehicle = item['vehicle'] as Map<String, dynamic>?;
    if (vehicle == null) return 'Kendaraan tidak diketahui';
    return '${vehicle['nama']} (${vehicle['platNomor']})';
  }

  @override
  Widget build(BuildContext context) {
  final list = showOnGoing ? _onGoingList : _historyList;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
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

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktivitas',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Riwayat dan peminjaman aktif',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Filter Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() => showOnGoing = true);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: showOnGoing
                                  ? Colors.blue.shade700
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Sedang Berlangsung',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: showOnGoing
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() => showOnGoing = false);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: !showOnGoing
                                  ? Colors.blue.shade700
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Riwayat',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: !showOnGoing
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // List Aktivitas
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada aktivitas',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        showOnGoing
                            ? 'Tidak ada peminjaman yang sedang berlangsung'
                            : 'Riwayat peminjaman akan muncul di sini',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
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
                            showOnGoing
                                ? 'Peminjaman Aktif'
                                : 'Riwayat Peminjaman',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${list.length} item',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...list.map((item) {
                        return _buildAktivitasCard(item);
                      }).toList(),
                    ],
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      ),
    );
  }

Widget _buildAktivitasCard(Map<String, dynamic> item) {
  final status = item['status'] ?? 'UNKNOWN';
  final isOnGoing = status == 'ON_GOING';
  final isDone = status == 'DONE';
  final isCancelled = status == 'CANCELLED';
  
  Color statusColor;
  if (isOnGoing) {
    statusColor = Colors.orange;
  } else if (isDone) {
    statusColor = Colors.green;
  } else if (isCancelled) {
    statusColor = Colors.red;
  } else {
    statusColor = Colors.grey;
  }

  final waktuPinjam = item['waktuPinjam'] as Timestamp?;
  final waktuKembali = item['waktuKembali'] as Timestamp?;
  final vehicleDisplay = _getVehicleDisplay(item);
  final keperluan = item['keperluan'] ?? '-';
  final tujuan = item['tujuan'] ?? '-';

  String statusText;
  if (isOnGoing) {
    statusText = 'Sedang Digunakan';
  } else if (isDone) {
    statusText = 'Selesai';
  } else if (isCancelled) {
    statusText = 'Dibatalkan';
  } else {
    statusText = status;
  }

  return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanPage(
            data: item,
            approvalStep: 0,
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: false,
          ),
        ),
      ).then((_) {
        // Refresh data setelah kembali dari detail
        _loadData();
      });
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peminjaman ${_formatDate(waktuPinjam)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatTime(waktuPinjam)} - ${_formatTime(waktuKembali)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor.withOpacity(0.9),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Detail Peminjaman
          Column(
            children: [
              _buildDetailRow(
                icon: Icons.car_repair_rounded,
                label: 'Kendaraan',
                value: vehicleDisplay,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.assignment_rounded,
                label: 'Kegiatan',
                value: keperluan,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.location_on_rounded,
                label: 'Tujuan',
                value: tujuan,
              ),
            ],
          ),

          if (isOnGoing) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailPeminjamanPage(
                        data: item,
                        approvalStep: 0,
                        role: widget.role,
                        userName: widget.userName,
                        userId: widget.userId,
                        userDivision: widget.userDivision,
                        isApprovalMode: false,
                        isReturn: true,
                      ),
                    ),
                  ).then((_) {
                    // Refresh data setelah kembali
                    _loadData();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Lihat Detail',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
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
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}