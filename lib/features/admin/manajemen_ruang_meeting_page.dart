import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_ruang_meeting_page.dart';

class ManajemenRuangMeetingPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const ManajemenRuangMeetingPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<ManajemenRuangMeetingPage> createState() =>
      _ManajemenRuangMeetingPageState();
}

class _ManajemenRuangMeetingPageState
    extends State<ManajemenRuangMeetingPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _ruangList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRuang();
  }

  Future<void> _loadRuang() async {
    setState(() => _isLoading = true);
    try {
      print('🏢 Mulai load ruang meeting...');

      final snapshot =
          await FirebaseFirestore.instance.collection('rooms').get();

      print('🏢 Data ditemukan: ${snapshot.docs.length}');

      _ruangList = snapshot.docs.map((doc) {
        print('🏢 Ruang: ${doc.data()}');
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      print('🏢 Total ruang di list: ${_ruangList.length}');
    } catch (e) {
      print('❌ Error loading ruang meeting: $e');
      _showSnackbar('Error memuat data ruang meeting: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRuang {
    if (_searchQuery.isEmpty) return _ruangList;

    return _ruangList.where((ruang) {
      final namaRuang =
          (ruang['namaRuang'] ?? '').toString().toLowerCase();
      final lokasi = (ruang['lokasi'] ?? '').toString().toLowerCase();
      final tipe = (ruang['tipe'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return namaRuang.contains(query) ||
          lokasi.contains(query) ||
          tipe.contains(query);
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

  Future<void> _deleteRuang(String ruangId, String namaRuang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text(
            'Yakin ingin menghapus ruang meeting "$namaRuang"?'),
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
          .collection('rooms')
          .doc(ruangId)
          .delete();

      _showSnackbar('Ruang meeting berhasil dihapus');
      await _loadRuang();
    } catch (e) {
      print('Error deleting ruang: $e');
      _showSnackbar('Error menghapus ruang meeting: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToAddRuang() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormRuangMeetingPage(
          role: widget.role,
          userName: widget.userName,
          userId: widget.userId,
          userDivision: widget.userDivision,
        ),
      ),
    );

    if (result == true) {
      await _loadRuang();
    }
  }

  void _navigateToEditRuang(Map<String, dynamic> ruangData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormRuangMeetingPage(
          role: widget.role,
          userName: widget.userName,
          userId: widget.userId,
          userDivision: widget.userDivision,
          ruangData: ruangData,
          isEdit: true,
        ),
      ),
    );

    if (result == true) {
      await _loadRuang();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green.shade600;
      case 'unavailable':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'available':
        return 'Tersedia';
      case 'unavailable':
        return 'Tidak Tersedia';
      default:
        return status;
    }
  }

  Color _getTipeColor(String tipe) {
    switch (tipe) {
      case 'online': return Colors.blue.shade600;
      case 'hybrid': return Colors.purple.shade600;
      default: return Colors.orange.shade600;
    }
  }

  String _getTipeLabel(String tipe) {
    switch (tipe) {
      case 'online': return 'Online';
      case 'hybrid': return 'Hybrid';
      default: return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRuang,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                          Icons.meeting_room_outlined,
                          size: 24,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manajemen Ruang Meeting',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola data ruang meeting',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Cari ruang berdasarkan nama, lokasi, atau tipe...',
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade600),
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

                // List Header
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
                        'Daftar Ruang Meeting',
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
                          '${_filteredRuang.length} ruang',
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

                // Content
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filteredRuang.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.meeting_room_outlined
                              : Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Belum ada ruang meeting terdaftar'
                              : 'Ruang meeting tidak ditemukan',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Tekan tombol "Tambah Ruang" untuk menambahkan ruang baru'
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
                        ..._filteredRuang.map((ruang) {
                          return _buildRuangCard(ruang);
                        }).toList(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 16),
        child: FloatingActionButton.extended(
          onPressed: _navigateToAddRuang,
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Tambah Ruang',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuangCard(Map<String, dynamic> ruang) {
    final namaRuang = ruang['namaRuang'] ?? '-';
    final lokasi = ruang['lokasi'] ?? '-';
    final kapasitas = ruang['kapasitas']?.toString() ?? '-';
    final status = ruang['status'] ?? 'available';
    final tipe = ruang['tipe'] ?? 'offline';
    final fasilitasArray = ruang['fasilitas'] as List<dynamic>?;
    final fasilitasList =
        fasilitasArray?.map((e) => e.toString()).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToEditRuang(ruang),
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
              // Header Card
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
                      Icons.meeting_room_rounded,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                namaRuang,
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
                                lokasi,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(status)
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _getStatusLabel(status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Tipe badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    _getTipeColor(tipe).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getTipeColor(tipe)
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _getTipeLabel(tipe),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getTipeColor(tipe),
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

              // Detail Rows
              _buildDetailRow(
                icon: Icons.people_outlined,
                label: 'Kapasitas',
                value: '$kapasitas orang',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.checklist_rtl_rounded,
                label: 'Fasilitas',
                value: fasilitasList.isEmpty
                    ? 'Tidak ada data'
                    : fasilitasList.join(', '),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _navigateToEditRuang(ruang),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
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
                      onPressed: () => _deleteRuang(
                        ruang['id'],
                        namaRuang,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
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
          child: Icon(icon, size: 18, color: Colors.grey.shade600),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}