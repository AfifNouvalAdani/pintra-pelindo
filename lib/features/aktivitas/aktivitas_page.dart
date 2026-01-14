import 'package:flutter/material.dart';
import '../vehicle/detail_peminjaman_page.dart';

class AktivitasPage extends StatefulWidget {
  const AktivitasPage({super.key});

  @override
  State<AktivitasPage> createState() => _AktivitasPageState();
}

class _AktivitasPageState extends State<AktivitasPage> {
  bool showOnGoing = true;

  // Dummy data sementara (nanti ganti dari Firestore)
  final List<Map<String, dynamic>> onGoingList = [
    {
      'title': 'Peminjaman Mobil 20 Januari 2025',
      'kendaraan': 'Xenia Hitam',
      'kegiatan': 'SPPD',
      'tujuan': 'Semarang, Jawa Tengah',
      'kondisi': 'Baik',
      'status': 'On Going',
      'tanggal': '20 Jan 2025',
      'jam': '08:30 - 17:00',
    }
  ];

  final List<Map<String, dynamic>> historyList = [
    {
      'title': 'Peminjaman Mobil 20 Januari 2025',
      'kendaraan': 'Xenia Hitam',
      'kegiatan': 'SPPD',
      'tujuan': 'Semarang, Jawa Tengah',
      'kondisi': 'Baik',
      'status': 'Selesai',
      'tanggal': '20 Jan 2025',
      'jam': '08:30 - 17:00',
    },
    {
      'title': 'Peminjaman Mobil 12 Januari 2025',
      'kendaraan': 'Innova Putih',
      'kegiatan': 'Rapat',
      'tujuan': 'Jakarta',
      'kondisi': 'Baik',
      'status': 'Selesai',
      'tanggal': '12 Jan 2025',
      'jam': '10:00 - 15:30',
    },
    {
      'title': 'Peminjaman Mobil 5 Januari 2025',
      'kendaraan': 'Avanza Abu',
      'kegiatan': 'Undangan',
      'tujuan': 'Bandung',
      'kondisi': 'Baik',
      'status': 'Selesai',
      'tanggal': '5 Jan 2025',
      'jam': '09:00 - 16:00',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final list = showOnGoing ? onGoingList : historyList;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
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
              if (list.isEmpty)
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
    );
  }

  Widget _buildAktivitasCard(Map<String, dynamic> item) {
    final isOnGoing = item['status'] == 'On Going';
    final statusColor = isOnGoing ? Colors.orange : Colors.green;

    return Container(
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
                      item['title'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['tanggal'] + ' • ' + item['jam'],
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
                  color: statusColor.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.shade100),
                ),
                child: Text(
                  item['status'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor.shade800,
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
                value: item['kendaraan'],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.assignment_rounded,
                label: 'Kegiatan',
                value: item['kegiatan'],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.location_on_rounded,
                label: 'Tujuan',
                value: item['tujuan'],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Kondisi',
                value: item['kondisi'],
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
                        data: {
                          'id': 'PMJ-20250120-001',
                          'nama': 'Budi Santoso',
                          'nipp': '123456',
                          'divisi': 'Operasional',
                          'keperluan': 'SPPD',
                          'tujuan': 'Semarang',
                          'kendaraan': item['kendaraan'],
                          'tglPinjam': item['tanggal'],
                          'jamPinjam': '08:30',
                          'tglKembali': item['tanggal'],
                          'jamKembali': '17:00',
                        },
                        approvalStep: 3,
                        isReturn: true, // mode pengembalian
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Akhiri Peminjaman',
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