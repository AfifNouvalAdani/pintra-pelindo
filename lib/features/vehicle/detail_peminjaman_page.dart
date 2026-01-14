import 'package:flutter/material.dart';
import '../vehicle/form_kondisi_kendaraan_awal_page.dart';
import '../vehicle/form_pengembalian_kendaraan_page.dart';

class DetailPeminjamanPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final int approvalStep;
  final bool isReturn; // <- tambah ini

  const DetailPeminjamanPage({
    super.key,
    required this.data,
    required this.approvalStep,
    this.isReturn = false, // default: false (mode awal)
  });

  @override
  Widget build(BuildContext context) {
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();

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
                        _getStatusIcon(),
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
                            _getStatusDescription(),
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
                    _buildDetailItem('ID Peminjaman', data['id']),
                    _buildDetailItem('Nama Peminjam', data['nama']),
                    _buildDetailItem('NIPP', data['nipp']),
                    _buildDetailItem('Divisi', data['divisi']),
                    _buildDetailItem('Keperluan', data['keperluan']),
                    if (data['nomor'] != null && data['nomor'].isNotEmpty)
                      _buildDetailItem('Nomor SPPD/Undangan', data['nomor']),
                    _buildDetailItem('Tujuan', data['tujuan']),
                    _buildDetailItem('Kendaraan', data['kendaraan']),

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
                                data['tglPinjam'],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                data['jamPinjam'],
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
                                data['tglKembali'],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                data['jamKembali'],
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
                  ],
                ),
              ),

              const SizedBox(height: 40),

                // Tombol Aksi
                if (approvalStep == 3)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isReturn) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FormPengembalianKendaraanPage(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FormKondisiKendaraanAwalPage(),
                            ),
                          );
                        }
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
                        'Selanjutnya',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

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
                      'Kembali ke Dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
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
      'Pengajuan oleh peminjam',
      'Approval Penanggung Jawab',
      'Verifikasi oleh Operator',
      'Approval Manager Umum',
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final isActive = index <= approvalStep;
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
                      steps[index],
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
                      _getTimelineDate(index),
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

  String _getTimelineDate(int step) {
    final dates = [
      data['tanggalPengajuan'] ?? 'Hari ini, 09:30',
      data['tanggalApproval1'] ?? 'Menunggu',
      data['tanggalApproval2'] ?? 'Menunggu',
      data['tanggalApproval3'] ?? 'Menunggu',
    ];
    return dates[step];
  }

  String _getStatusText() {
    switch (approvalStep) {
      case 0:
        return 'Menunggu Persetujuan';
      case 1:
        return 'Disetujui Penanggung Jawab';
      case 2:
        return 'Diverifikasi Operator';
      case 3:
        return 'Disetujui Manager Umum';
      default:
        return 'Menunggu';
    }
  }

  Color _getStatusColor() {
    switch (approvalStep) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (approvalStep) {
      case 0:
        return Icons.hourglass_empty_rounded;
      case 1:
        return Icons.check_circle_outline_rounded;
      case 2:
        return Icons.verified_outlined;
      case 3:
        return Icons.thumb_up_alt_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _getStatusDescription() {
    switch (approvalStep) {
      case 0:
        return 'Pengajuan Anda sedang menunggu persetujuan dari penanggung jawab';
      case 1:
        return 'Pengajuan telah disetujui penanggung jawab, menunggu verifikasi operator';
      case 2:
        return 'Pengajuan telah diverifikasi, menunggu persetujuan akhir';
      case 3:
        return 'Pengajuan telah disetujui. Silakan ambil kunci sesuai jadwal';
      default:
        return 'Status tidak diketahui';
    }
  }
}