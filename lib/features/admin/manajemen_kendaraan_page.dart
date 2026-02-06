import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_kendaraan_page.dart';  // ✅ IMPORT INI


class ManajemenKendaraanPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const ManajemenKendaraanPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<ManajemenKendaraanPage> createState() => _ManajemenKendaraanPageState();
}

class _ManajemenKendaraanPageState extends State<ManajemenKendaraanPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _kendaraanList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadKendaraan();
  }

Future<void> _loadKendaraan() async {
  setState(() => _isLoading = true);
  try {
    print('🚗 Mulai load kendaraan...'); // ✅ Debug
    
    final snapshot = await FirebaseFirestore.instance
        .collection('vehicles')
        .get();
    
    print('🚗 Data ditemukan: ${snapshot.docs.length}'); // ✅ Debug

    _kendaraanList = snapshot.docs.map((doc) {
      print('🚗 Kendaraan: ${doc.data()}'); // ✅ Debug
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
    
    print('🚗 Total kendaraan di list: ${_kendaraanList.length}'); // ✅ Debug
    
  } catch (e) {
    print('❌ Error loading kendaraan: $e'); // ✅ Debug
    _showSnackbar('Error memuat data kendaraan: $e', isError: true);
  } finally {
    setState(() => _isLoading = false);
  }
}

  List<Map<String, dynamic>> get _filteredKendaraan {
    if (_searchQuery.isEmpty) return _kendaraanList;
    
    return _kendaraanList.where((kendaraan) {
      final platNomor = (kendaraan['platNomor'] ?? '').toString().toLowerCase();
      final nama = (kendaraan['nama'] ?? '').toString().toLowerCase();
      final jenis = (kendaraan['jenis'] ?? '').toString().toLowerCase();
      final merk = (kendaraan['merk'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return platNomor.contains(query) || 
             nama.contains(query) || 
             jenis.contains(query) ||
             merk.contains(query);
    }).toList();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteKendaraan(String kendaraanId, String platNomor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Yakin ingin menghapus kendaraan dengan plat nomor: $platNomor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(kendaraanId)
          .delete();
      
      _showSnackbar('Kendaraan berhasil dihapus');
      await _loadKendaraan();
    } catch (e) {
      print('Error deleting kendaraan: $e');
      _showSnackbar('Error menghapus kendaraan: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToAddKendaraan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormKendaraanPage(
          role: widget.role,
          userName: widget.userName,
          userId: widget.userId,
          userDivision: widget.userDivision,
        ),
      ),
    );

    if (result == true) {
      await _loadKendaraan();
    }
  }

  void _navigateToEditKendaraan(Map<String, dynamic> kendaraanData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormKendaraanPage(
          role: widget.role,
          userName: widget.userName,
          userId: widget.userId,
          userDivision: widget.userDivision,
          kendaraanData: kendaraanData,
          isEdit: true,
        ),
      ),
    );

    if (result == true) {
      await _loadKendaraan();
    }
  }

  Color _getStatusColor(bool statusAktif) {
    return statusAktif ? Colors.green.shade600 : Colors.red.shade600;
  }

  String _getStatusLabel(bool statusAktif) {
    return statusAktif ? 'Aktif' : 'Tidak Aktif';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadKendaraan,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.grey.shade700,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      Image.asset(
                        'assets/images/logo-pelindo.webp',
                        height: 28,
                        color: Colors.blue.shade800,
                      ),
                      
                      const Spacer(),
                      
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade100,
                        ),
                        child: Icon(
                          Icons.directions_car_outlined,
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
                        'Manajemen Kendaraan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola data kendaraan operasional',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari kendaraan berdasarkan plat nomor, nama, jenis, atau merk...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

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
                        'Daftar Kendaraan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_filteredKendaraan.length} kendaraan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_filteredKendaraan.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.directions_car_outlined
                              : Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Belum ada kendaraan terdaftar'
                              : 'Kendaraan tidak ditemukan',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Tekan tombol "Tambah Kendaraan" untuk menambahkan kendaraan baru'
                              : 'Coba dengan kata kunci yang berbeda',
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
                        ..._filteredKendaraan.map((kendaraan) {
                          return _buildKendaraanCard(kendaraan);
                        }).toList(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 16),
        child: FloatingActionButton.extended(
          onPressed: _navigateToAddKendaraan,
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Tambah Kendaraan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKendaraanCard(Map<String, dynamic> kendaraan) {
    final platNomor = kendaraan['platNomor'] ?? '-';
    final nama = kendaraan['nama'] ?? '-';
    final jenis = kendaraan['jenis'] ?? '-';
    final merk = kendaraan['merk'] ?? '-';
    final tahun = kendaraan['tahun']?.toString() ?? '-';
    final warna = kendaraan['warna'] ?? '-';
    final kursi = kendaraan['kursi']?.toString() ?? '-';
    final transmisi = kendaraan['transmisi'] ?? '-';
    final bbm = kendaraan['bbm'] ?? '-';
    final statusAktif = kendaraan['statusAktif'] ?? true;
    final odometerTerakhir = kendaraan['odometerTerakhir']?.toString() ?? '0';
    final kelengkapanArray = kendaraan['kelengkapan'] as List<dynamic>?;
    final kelengkapanList = kelengkapanArray?.map((e) => e.toString()).toList() ?? [];


    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToEditKendaraan(kendaraan),
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nama,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    platNomor,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(statusAktif).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(statusAktif).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _getStatusLabel(statusAktif),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(statusAktif),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.category_outlined,
                    label: 'Jenis',
                    value: jenis,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.branding_watermark_outlined,
                    label: 'Merk',
                    value: merk,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Tahun',
                          value: tahun,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailRow(
                          icon: Icons.palette_outlined,
                          label: 'Warna',
                          value: warna,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          icon: Icons.event_seat_outlined,
                          label: 'Kursi',
                          value: '$kursi penumpang',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailRow(
                          icon: Icons.settings_outlined,
                          label: 'Transmisi',
                          value: transmisi,
                        ),
                      ),
                    ],
                  ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailRow(
                            icon: Icons.local_gas_station_outlined,
                            label: 'BBM',
                            value: bbm,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailRow(
                          icon: Icons.speed_outlined,
                          label: 'Odometer',
                          value: '$odometerTerakhir km',
                        ),
                      ),
                    ],
                  ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.checklist_rtl_rounded,
                        label: 'Kelengkapan',
                        value: kelengkapanList.isEmpty 
                            ? 'Tidak ada data' 
                            : kelengkapanList.join(', '),
                      ),
                ],
              ),



              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _navigateToEditKendaraan(kendaraan),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _deleteKendaraan(
                        kendaraan['id'],
                        platNomor,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 16),
                          SizedBox(width: 6),
                          Text('Hapus'),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}