import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ Tambahkan import ini
import 'package:cloud_firestore/cloud_firestore.dart';


class BerhasilPengembalianPage extends StatefulWidget {
  final String bookingId; // ✅ Cukup kirim ID saja

  const BerhasilPengembalianPage({
    super.key,
    required this.bookingId,
  });

  @override
  State<BerhasilPengembalianPage> createState() => _BerhasilPengembalianPageState();
}

class _BerhasilPengembalianPageState extends State<BerhasilPengembalianPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _vehicleData;
  List<Map<String, dynamic>> _approvalHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // 1. Ambil data booking
      final bookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Data booking tidak ditemukan');
      }

      _bookingData = {
        'id': bookingDoc.id,
        ...bookingDoc.data() as Map<String, dynamic>,
      };

      // 2. Ambil data kendaraan
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

      // 3. Ambil riwayat approval
      final historySnapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .orderBy('timestamp', descending: false)
          .get();

      _approvalHistory = historySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Format helpers
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(date);
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('HH:mm', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Pengembalian Selesai',
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

    if (_bookingData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text('Pengembalian Selesai'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Data tidak ditemukan',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Ambil data dari Firestore
    final booking = _bookingData!;
    final vehicle = _vehicleData;
    final kondisiAkhir = booking['kondisiAkhir'] as Map<String, dynamic>?;
    
    final waktuPinjam = booking['waktuPinjam'] as Timestamp?;
    final waktuKembali = booking['waktuKembali'] as Timestamp?;

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
          'Pengembalian Selesai',
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
              // Status Banner Sukses
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.shade100,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
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
                            'Pengembalian Berhasil!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kendaraan telah berhasil dikembalikan dan data telah tersimpan',
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
                'Proses Peminjaman',
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
                    _buildDetailItem('Nama Peminjam', booking['namaPeminjam'] ?? '-'),
                    _buildDetailItem('Divisi', booking['divisi'] ?? '-'),
                    _buildDetailItem('Keperluan', booking['keperluan'] ?? '-'),
                    
                    if (booking['nomorSurat'] != null && 
                        booking['nomorSurat'].toString().isNotEmpty && 
                        booking['nomorSurat'] != '-')
                      _buildDetailItem('Nomor SPPD/Undangan', booking['nomorSurat'].toString()),
                    
                    _buildDetailItem('Tujuan', booking['tujuan'] ?? '-'),
                    
                    // Data Kendaraan
                    if (vehicle != null)
                      _buildDetailItem('Kendaraan', '${vehicle['nama']} (${vehicle['platNomor']})'),

                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 16),

                    // Waktu Peminjaman
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
                                _formatDate(waktuPinjam),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                _formatTime(waktuPinjam),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
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
                                _formatDate(waktuKembali),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                _formatTime(waktuKembali),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Data Pengembalian
                    if (kondisiAkhir != null) ...[
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
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
                      _buildDetailItem('Kondisi Saat Kembali', kondisiAkhir['kondisi'] ?? '-'),
                      _buildDetailItem('Sisa BBM', kondisiAkhir['sisaBBM'] ?? '-'),
                      _buildDetailItem('Odometer Akhir', kondisiAkhir['odometerAkhir']?.toString() ?? '-'),
                      _buildDetailItem('Dikembalikan Pada', _formatTimestamp(kondisiAkhir['timestamp'] as Timestamp?)),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Tombol Kembali ke Dashboard
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
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
                    'Kembali ke Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final steps = [
      {'label': 'Pengajuan oleh peminjam', 'status': 'SUBMITTED'},
      {'label': 'Approval Manager Divisi', 'status': 'APPROVAL_1'},
      {'label': 'Verifikasi oleh Operator', 'status': 'APPROVAL_2'},
      {'label': 'Approval Manager Umum', 'status': 'APPROVAL_3'},
      {'label': 'Kendaraan Digunakan', 'status': 'ON_GOING'},
      {'label': 'Pengembalian Selesai', 'status': 'DONE'},
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isActive = index <= 5; // Semua aktif karena sudah selesai
        final isLast = index == steps.length - 1;

        // Cari timestamp dari approval history
        final history = _approvalHistory.firstWhere(
          (h) => h['newStatus'] == step['status'],
          orElse: () => {},
        );

        String timeText = 'Menunggu';
        if (history.isNotEmpty && history['timestamp'] != null) {
          timeText = _formatTimestamp(history['timestamp']);
        } else if (step['status'] == 'SUBMITTED' && _bookingData?['createdAt'] != null) {
          timeText = _formatTimestamp(_bookingData!['createdAt']);
        } else if (step['status'] == 'ON_GOING' && _bookingData?['actualPickupTime'] != null) {
          timeText = _formatTimestamp(_bookingData!['actualPickupTime']);
        } else if (step['status'] == 'DONE' && _bookingData?['actualReturnTime'] != null) {
          timeText = _formatTimestamp(_bookingData!['actualReturnTime']);
        }

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
                    color: isActive ? Colors.blue.shade700 : Colors.grey.shade300,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: isActive
                      ? Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isActive ? Colors.blue.shade300 : Colors.grey.shade200,
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
                      timeText,
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