import 'package:flutter/material.dart';
import '../vehicle/detail_peminjaman_page.dart';

class ApprovalKendaraanPage extends StatefulWidget {
  const ApprovalKendaraanPage({super.key});

  @override
  State<ApprovalKendaraanPage> createState() => _ApprovalKendaraanPageState();
}

class _ApprovalKendaraanPageState extends State<ApprovalKendaraanPage> {
  String activeFilter = 'all';
  String sortOrder = 'terbaru';
  DateTime? startDate;
  DateTime? endDate;
  List<String> selectedCategories = [];

  final List<String> categories = [
    'Permohonan Approval',
    'Permohonan Pembatalan',
    'Ditolak',
    'Disetujui',
    'Dibatalkan',
  ];

  

  final List<Map<String, dynamic>> allData = [
    {
      'id': 'PMN-2025-001',
      'title': 'Peminjaman Mobil 21 Januari 2025',
      'kendaraan': 'Innova Zenix',
      'tujuan': 'Semarang, Jawa Tengah',
      'peminjam': 'Budi Santoso',
      'nipp': '103456',
      'divisi': 'Operasional',
      'status': 'Permohonan Approval',
      'tanggal': DateTime(2025, 1, 21),
      'jam': '08:30',
      'keperluan': 'SPPD Dinas',
      'nomor': '123/SPPD/2025',
      'tglPinjam': '21 Jan 2025',
      'jamPinjam': '08:30',
      'tglKembali': '22 Jan 2025',
      'jamKembali': '17:00',
    },
    {
      'id': 'PMN-2025-002',
      'title': 'Peminjaman Mobil 20 Januari 2025',
      'kendaraan': 'Xenia Hitam',
      'tujuan': 'Cilacap, Jawa Tengah',
      'peminjam': 'Aris Setiawan',
      'nipp': '103457',
      'divisi': 'SDM',
      'status': 'Ditolak',
      'tanggal': DateTime(2025, 1, 20),
      'jam': '09:15',
      'keperluan': 'Undangan',
      'nomor': 'UND-012/2025',
      'tglPinjam': '20 Jan 2025',
      'jamPinjam': '09:15',
      'tglKembali': '20 Jan 2025',
      'jamKembali': '18:00',
    },
    {
      'id': 'PMN-2025-003',
      'title': 'Peminjaman Mobil 19 Januari 2025',
      'kendaraan': 'Avanza Hitam',
      'tujuan': 'Probolinggo, Jawa Timur',
      'peminjam': 'Afif Hidayat',
      'nipp': '103458',
      'divisi': 'Teknologi Informasi',
      'status': 'Disetujui',
      'tanggal': DateTime(2025, 1, 19),
      'jam': '10:00',
      'keperluan': 'SPPD Dinas',
      'nomor': '124/SPPD/2025',
      'tglPinjam': '19 Jan 2025',
      'jamPinjam': '10:00',
      'tglKembali': '21 Jan 2025',
      'jamKembali': '16:30',
    },
    {
      'id': 'PMN-2025-004',
      'title': 'Peminjaman Mobil 18 Januari 2025',
      'kendaraan': 'Innova Putih',
      'tujuan': 'Jakarta',
      'peminjam': 'Tono Wijaya',
      'nipp': '103459',
      'divisi': 'Keuangan',
      'status': 'Permohonan Pembatalan',
      'tanggal': DateTime(2025, 1, 18),
      'jam': '14:30',
      'keperluan': 'Kegiatan Lainnya',
      'nomor': '',
      'tglPinjam': '18 Jan 2025',
      'jamPinjam': '14:30',
      'tglKembali': '19 Jan 2025',
      'jamKembali': '12:00',
    },
    {
      'id': 'PMN-2025-005',
      'title': 'Peminjaman Mobil 17 Januari 2025',
      'kendaraan': 'Xenia Putih',
      'tujuan': 'Surabaya',
      'peminjam': 'Sari Dewi',
      'nipp': '103460',
      'divisi': 'Pemasaran',
      'status': 'Dibatalkan',
      'tanggal': DateTime(2025, 1, 17),
      'jam': '11:00',
      'keperluan': 'SPPD Dinas',
      'nomor': '125/SPPD/2025',
      'tglPinjam': '17 Jan 2025',
      'jamPinjam': '11:00',
      'tglKembali': '18 Jan 2025',
      'jamKembali': '15:00',
    },
  ];

  List<Map<String, dynamic>> get filteredData {
    List<Map<String, dynamic>> result = allData;

    // Filter berdasarkan kategori
    if (selectedCategories.isNotEmpty) {
      result = result.where((e) => selectedCategories.contains(e['status'])).toList();
    }

    // Filter berdasarkan tanggal
    if (startDate != null && endDate != null) {
      result = result.where((e) {
        final itemDate = e['tanggal'];
        return (itemDate.isAfter(startDate!) || itemDate.isAtSameMomentAs(startDate!)) &&
               (itemDate.isBefore(endDate!) || itemDate.isAtSameMomentAs(endDate!));
      }).toList();
    }

    // Sort berdasarkan tanggal
    if (sortOrder == 'terbaru') {
      result.sort((a, b) => b['tanggal'].compareTo(a['tanggal']));
    } else {
      result.sort((a, b) => a['tanggal'].compareTo(b['tanggal']));
    }

    return result;
  }

  void _resetFilters() {
    setState(() {
      selectedCategories.clear();
      startDate = null;
      endDate = null;
    });
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    final tempCategories = List<String>.from(selectedCategories);
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
                    'Kategori Status',
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
                    children: categories.map((category) {
                      final isSelected = tempCategories.contains(category);
                      return FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              tempCategories.add(category);
                            } else {
                              tempCategories.remove(category);
                            }
                          });
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.blue.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.blue.shade800 : Colors.grey.shade700,
                        ),
                        checkmarkColor: Colors.blue.shade700,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Periode Tanggal',
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
                              lastDate: DateTime(2026),
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
                                      ? '${tempStartDate!.day}/${tempStartDate!.month}/${tempStartDate!.year}'
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
                              lastDate: DateTime(2026),
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
                                      ? '${tempEndDate!.day}/${tempEndDate!.month}/${tempEndDate!.year}'
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
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempCategories.clear();
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
                    'categories': tempCategories,
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

    // Update state setelah dialog ditutup
    if (result != null) {
      setState(() {
        selectedCategories = List<String>.from(result['categories']);
        startDate = result['startDate'];
        endDate = result['endDate'];
      });
    }
  }

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
                  setState(() => sortOrder = value.toString());
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
                  setState(() => sortOrder = value.toString());
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

  @override
  Widget build(BuildContext context) {
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
      body: Column(
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
                  value: allData.length.toString(),
                  icon: Icons.list_alt_rounded,
                  color: Colors.blue,
                ),
                _buildStatItem(
                  label: 'Menunggu',
                  value: allData.where((e) => e['status'] == 'Permohonan Approval').length.toString(),
                  icon: Icons.access_time_rounded,
                  color: Colors.orange,
                ),
                _buildStatItem(
                  label: 'Selesai',
                  value: allData.where((e) => e['status'] == 'Disetujui' || e['status'] == 'Ditolak').length.toString(),
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
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
                      selectedCategories.isNotEmpty || startDate != null
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
                  onPressed: selectedCategories.isNotEmpty || startDate != null
                      ? _resetFilters
                      : null,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: selectedCategories.isNotEmpty || startDate != null
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
          if (selectedCategories.isNotEmpty || startDate != null)
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
                      if (selectedCategories.isNotEmpty)
                        ...selectedCategories.map((category) {
                          return Chip(
                            label: Text(category),
                            backgroundColor: Colors.blue.shade100,
                            deleteIcon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            onDeleted: () {
                              setState(() {
                                selectedCategories.remove(category);
                              });
                            },
                          );
                        }).toList(),
                      if (startDate != null && endDate != null)
                        Chip(
                          label: Text(
                            '${startDate!.day}/${startDate!.month}/${startDate!.year} - ${endDate!.day}/${endDate!.month}/${endDate!.year}',
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
                Text(
                  'Daftar Approval',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filteredData.length} item',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Data List
          Expanded(
            child: filteredData.isEmpty
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
                          'Coba ubah filter atau periode tanggal',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      final item = filteredData[index];
                      return _buildApprovalCard(item);
                    },
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
  final statusColor = _getStatusColor(item['status']);
  final statusIcon = _getStatusIcon(item['status']);

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
                    item['id'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['tanggal'].day}/${item['tanggal'].month}/${item['tanggal'].year} • ${item['jam']}',
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
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Text(
                item['status'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Divider(color: Colors.grey.shade200),
        const SizedBox(height: 16),

        // Detail Peminjaman
        _buildDetailRow(
          icon: Icons.person_outline_rounded,
          label: 'Peminjam',
          value: '${item['peminjam']} (${item['nipp']})',
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          icon: Icons.business_rounded,
          label: 'Divisi',
          value: item['divisi'],
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          icon: Icons.directions_car_rounded,
          label: 'Kendaraan',
          value: item['kendaraan'],
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          icon: Icons.location_on_rounded,
          label: 'Tujuan',
          value: item['tujuan'],
        ),

        const SizedBox(height: 20),

        // Tombol Aksi
        Row(
          children: [
            // Tombol Lihat Detail
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailPeminjamanPage(
                        data: {
                          'id': item['id'],
                          'nama': item['peminjam'],
                          'nipp': item['nipp'],
                          'divisi': item['divisi'],
                          'keperluan': item['keperluan'],
                          'nomor': item['nomor'],
                          'tujuan': item['tujuan'],
                          'kendaraan': item['kendaraan'],
                          'tglPinjam': item['tglPinjam'],
                          'jamPinjam': item['jamPinjam'],
                          'tglKembali': item['tglKembali'],
                          'jamKembali': item['jamKembali'],
                        },
                        approvalStep: 0,
                        isApprovalMode: true, // <- mode admin
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    const Text('Lihat Detail'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Tombol Setujui (hanya untuk Permohonan Approval)
            if (item['status'] == 'Permohonan Approval')
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Tampilkan dialog konfirmasi
                    _showApprovalConfirmationDialog(context, item);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text('Setujui'),
                    ],
                  ),
                ),
              ),
            
            // Tombol Aksi lain untuk status yang berbeda
            if (item['status'] == 'Permohonan Pembatalan')
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Proses pembatalan
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text('Proses'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

// Tambahkan fungsi untuk dialog konfirmasi approval
void _showApprovalConfirmationDialog(BuildContext context, Map<String, dynamic> item) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Konfirmasi
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.question_mark_rounded,
                size: 32,
                color: Colors.blue.shade700,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Judul Dialog
            Text(
              'Konfirmasi Approval',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Pesan Konfirmasi
            Text(
              'Apakah Anda yakin ingin menyetujui peminjaman ini?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Tombol Aksi
            Row(
              children: [
                // Tombol Batal (Merah)
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text('Batal'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Tombol Ya, Setujui (Hijau)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Update status menjadi Disetujui
                      setState(() {
                        item['status'] = 'Disetujui';
                      });
                      Navigator.pop(context);
                      
                      // Tampilkan snackbar konfirmasi
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Peminjaman ${item['id']} telah disetujui',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          backgroundColor: Colors.green.shade600,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade500,
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Permohonan Approval':
        return Colors.orange;
      case 'Permohonan Pembatalan':
        return Colors.blue;
      case 'Disetujui':
        return Colors.green;
      case 'Ditolak':
        return Colors.red;
      case 'Dibatalkan':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Permohonan Approval':
        return Icons.access_time_rounded;
      case 'Permohonan Pembatalan':
        return Icons.cancel_presentation_rounded;
      case 'Disetujui':
        return Icons.check_circle_rounded;
      case 'Ditolak':
        return Icons.cancel_rounded;
      case 'Dibatalkan':
        return Icons.block_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}