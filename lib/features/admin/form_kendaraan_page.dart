import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormKendaraanPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;
  final Map<String, dynamic>? kendaraanData;
  final bool isEdit;

  const FormKendaraanPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
    this.kendaraanData,
    this.isEdit = false,
  });

  @override
  State<FormKendaraanPage> createState() => _FormKendaraanPageState();
}

class _FormKendaraanPageState extends State<FormKendaraanPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _platNomorController;
  late TextEditingController _namaController;
  late TextEditingController _merkController;
  late TextEditingController _tahunController;
  late TextEditingController _warnaController;
  late TextEditingController _kursiController;
  late TextEditingController _odometerController;

  String _selectedJenis = 'Mobil';
  String _selectedTransmisi = 'A/T';
  String _selectedBBM = 'Bensin';
  bool _statusAktif = true;
  bool _p3k = false;
  bool _dongkrak = false;
  bool _apar = false;
  bool _segitigaBahaya = false;
  bool _banSerep = false;

  final List<String> _jenisOptions = [
    'Mobil',
    'Motor',
    'Truk',
    'Bus',
  ];

  final List<String> _transmisiOptions = [
    'A/T',
    'M/T',
  ];

  final List<String> _bbmOptions = [
    'Bensin',
    'Solar',
    'Listrik',
  ];

  @override
  void initState() {
    super.initState();
    _platNomorController = TextEditingController(
      text: widget.kendaraanData?['platNomor'] ?? '',
    );
    _namaController = TextEditingController(
      text: widget.kendaraanData?['nama'] ?? '',
    );
    _merkController = TextEditingController(
      text: widget.kendaraanData?['merk'] ?? '',
    );
    _tahunController = TextEditingController(
      text: widget.kendaraanData?['tahun']?.toString() ?? '',
    );
    _warnaController = TextEditingController(
      text: widget.kendaraanData?['warna'] ?? '',
    );
    _kursiController = TextEditingController(
      text: widget.kendaraanData?['kursi']?.toString() ?? '',
    );
    _odometerController = TextEditingController(
      text: widget.kendaraanData?['odometerTerakhir']?.toString() ?? '0',
    );

      if (widget.kendaraanData != null) {
    final kelengkapanArray = widget.kendaraanData!['kelengkapan'] as List<dynamic>?;
    if (kelengkapanArray != null) {
      _p3k = kelengkapanArray.contains('P3K');
      _dongkrak = kelengkapanArray.contains('Dongkrak');
      _apar = kelengkapanArray.contains('Apar');
      _segitigaBahaya = kelengkapanArray.contains('Segitiga Bahaya');
      _banSerep = kelengkapanArray.contains('ban serep');
    }
  }

    _selectedJenis = widget.kendaraanData?['jenis'] ?? 'Mobil';
    _selectedTransmisi = widget.kendaraanData?['transmisi'] ?? 'A/T';
    _selectedBBM = widget.kendaraanData?['bbm'] ?? 'Bensin';
    _statusAktif = widget.kendaraanData?['statusAktif'] ?? true;
  }

  @override
  void dispose() {
    _platNomorController.dispose();
    _namaController.dispose();
    _merkController.dispose();
    _tahunController.dispose();
    _warnaController.dispose();
    _kursiController.dispose();
    _odometerController.dispose();
    super.dispose();
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

  Future<void> _saveKendaraan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final platNomor = _platNomorController.text.trim();
      final nama = _namaController.text.trim();
      final merk = _merkController.text.trim();
      final tahun = int.tryParse(_tahunController.text.trim()) ?? 0;
      final warna = _warnaController.text.trim();
      final kursi = int.tryParse(_kursiController.text.trim()) ?? 0;
      final odometer = int.tryParse(_odometerController.text.trim()) ?? 0;

      if (widget.isEdit) {
        await _updateKendaraan(
          platNomor: platNomor,
          nama: nama,
          merk: merk,
          tahun: tahun,
          warna: warna,
          kursi: kursi,
          odometer: odometer,
        );
      } else {
        await _createKendaraan(
          platNomor: platNomor,
          nama: nama,
          merk: merk,
          tahun: tahun,
          warna: warna,
          kursi: kursi,
          odometer: odometer,
        );
      }
    } catch (e) {
      print('Error saving kendaraan: $e');
      _showSnackbar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createKendaraan({
    required String platNomor,
    required String nama,
    required String merk,
    required int tahun,
    required String warna,
    required int kursi,
    required int odometer,
  }) async {
    try {
      // Cek apakah plat nomor sudah digunakan
      final platCheck = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('platNomor', isEqualTo: platNomor)
          .get();

      if (platCheck.docs.isNotEmpty) {
        throw 'Plat nomor sudah terdaftar';
      }

      List<String> kelengkapanArray = [];
      if (_p3k) kelengkapanArray.add('P3K');
      if (_dongkrak) kelengkapanArray.add('Dongkrak');
      if (_apar) kelengkapanArray.add('Apar');
      if (_segitigaBahaya) kelengkapanArray.add('Segitiga Bahaya');
      if (_banSerep) kelengkapanArray.add('ban serep');

      // Simpan data kendaraan ke Firestore
      await FirebaseFirestore.instance
          .collection('vehicles')
          .add({
        'platNomor': platNomor,
        'nama': nama,
        'jenis': _selectedJenis,
        'merk': merk,
        'tahun': tahun,
        'warna': warna,
        'kursi': kursi,
        'transmisi': _selectedTransmisi,
        'bbm': _selectedBBM,
        'odometerTerakhir': odometer,
        'statusAktif': _statusAktif,
        'kelengkapan': kelengkapanArray,
        'photos': [], // Bisa diisi nanti
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('Kendaraan berhasil ditambahkan!');
      Navigator.pop(context, true);
      
    } catch (e) {
      throw e;
    }
  }

  Future<void> _updateKendaraan({
    required String platNomor,
    required String nama,
    required String merk,
    required int tahun,
    required String warna,
    required int kursi,
    required int odometer,
  }) async {
    try {
      final kendaraanId = widget.kendaraanData!['id'];
      final oldPlatNomor = widget.kendaraanData!['platNomor'];

      // Jika plat nomor berubah, cek apakah plat nomor baru sudah digunakan
      if (platNomor != oldPlatNomor) {
        final platCheck = await FirebaseFirestore.instance
            .collection('vehicles')
            .where('platNomor', isEqualTo: platNomor)
            .get();

        if (platCheck.docs.isNotEmpty) {
          throw 'Plat nomor sudah terdaftar';
        }
      }

    List<String> kelengkapanArray = [];
    if (_p3k) kelengkapanArray.add('P3K');
    if (_dongkrak) kelengkapanArray.add('Dongkrak');
    if (_apar) kelengkapanArray.add('Apar');
    if (_segitigaBahaya) kelengkapanArray.add('Segitiga Bahaya');
    if (_banSerep) kelengkapanArray.add('ban serep');

      // Update data di Firestore
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(kendaraanId)
          .update({
        'platNomor': platNomor,
        'nama': nama,
        'jenis': _selectedJenis,
        'merk': merk,
        'tahun': tahun,
        'warna': warna,
        'kursi': kursi,
        'transmisi': _selectedTransmisi,
        'bbm': _selectedBBM,
        'odometerTerakhir': odometer,
        'statusAktif': _statusAktif,
        'kelengkapan': kelengkapanArray,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('Kendaraan berhasil diupdate!');
      Navigator.pop(context, true);
      
    } catch (e) {
      throw e;
    }
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName wajib diisi';
    }
    if (int.tryParse(value) == null) {
      return '$fieldName harus berupa angka';
    }
    return null;
  }

  Widget _buildChecklistItem(String label, bool value, Function(bool?) onChanged) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: CheckboxListTile(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade900,
        ),
      ),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: Colors.blue.shade700,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      dense: true,
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.grey.shade700,
                        size: 20,
                      ),
                    ),
                    Text(
                      widget.isEdit ? 'Edit Kendaraan' : 'Tambah Kendaraan',
                      style: TextStyle(
                        fontSize: 18,
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
                        Icons.directions_car_outlined,
                        size: 24,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // Judul
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEdit ? 'Edit Data Kendaraan' : 'Tambah Kendaraan Baru',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isEdit 
                          ? 'Perbarui data kendaraan yang sudah ada'
                          : 'Tambahkan kendaraan baru ke dalam sistem',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Plat Nomor
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plat Nomor',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _platNomorController,
                            decoration: InputDecoration(
                              hintText: 'Masukkan plat nomor (contoh: L 1234 ABC)',
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
                              prefixIcon: Icon(
                                Icons.confirmation_number_outlined,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) => _validateRequired(v, 'Plat nomor'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Nama Kendaraan
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nama Kendaraan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _namaController,
                            decoration: InputDecoration(
                              hintText: 'Masukkan nama kendaraan',
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
                              prefixIcon: Icon(
                                Icons.drive_file_rename_outline,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            validator: (v) => _validateRequired(v, 'Nama kendaraan'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Jenis Kendaraan
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jenis Kendaraan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedJenis,
                              decoration: InputDecoration(
                                hintText: 'Pilih jenis',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.category_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                              ),
                              items: _jenisOptions.map((jenis) {
                                return DropdownMenuItem(
                                  value: jenis,
                                  child: Text(jenis),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedJenis = value!;
                                });
                              },
                              dropdownColor: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Merk
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Merk',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _merkController,
                            decoration: InputDecoration(
                              hintText: 'Masukkan merk kendaraan',
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
                              prefixIcon: Icon(
                                Icons.branding_watermark_outlined,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            validator: (v) => _validateRequired(v, 'Merk'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Tahun dan Warna
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tahun',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _tahunController,
                                  decoration: InputDecoration(
                                    hintText: '2020',
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
                                    prefixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => _validateNumber(v, 'Tahun'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Warna',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _warnaController,
                                  decoration: InputDecoration(
                                    hintText: 'Putih',
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
                                    prefixIcon: Icon(
                                      Icons.palette_outlined,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  validator: (v) => _validateRequired(v, 'Warna'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Kursi dan Odometer
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jumlah Kursi',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _kursiController,
                                  decoration: InputDecoration(
                                    hintText: '7',
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
                                    prefixIcon: Icon(
                                      Icons.event_seat_outlined,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => _validateNumber(v, 'Jumlah kursi'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Odometer (km)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _odometerController,
                                  decoration: InputDecoration(
                                    hintText: '0',
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
                                    prefixIcon: Icon(
                                      Icons.speed_outlined,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => _validateNumber(v, 'Odometer'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Transmisi
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transmisi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedTransmisi,
                              decoration: InputDecoration(
                                hintText: 'Pilih transmisi',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.settings_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                              ),
                              items: _transmisiOptions.map((transmisi) {
                                return DropdownMenuItem(
                                  value: transmisi,
                                  child: Text(transmisi == 'A/T' ? 'Otomatis (A/T)' : 'Manual (M/T)'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedTransmisi = value!;
                                });
                              },
                              dropdownColor: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // BBM
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jenis BBM',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedBBM,
                              decoration: InputDecoration(
                                hintText: 'Pilih jenis BBM',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.local_gas_station_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                              ),
                              items: _bbmOptions.map((bbm) {
                                return DropdownMenuItem(
                                  value: bbm,
                                  child: Text(bbm),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedBBM = value!;
                                });
                              },
                              dropdownColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ✅ KELENGKAPAN KENDARAAN
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.checklist_rtl_rounded,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Kelengkapan Kendaraan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            _buildChecklistItem('P3K', _p3k, (value) {
                              setState(() => _p3k = value ?? false);
                            }),
                            const SizedBox(height: 8),
                            _buildChecklistItem('Dongkrak', _dongkrak, (value) {
                              setState(() => _dongkrak = value ?? false);
                            }),
                            const SizedBox(height: 8),
                            _buildChecklistItem('Apar', _apar, (value) {
                              setState(() => _apar = value ?? false);
                            }),
                            const SizedBox(height: 8),
                            _buildChecklistItem('Segitiga Bahaya', _segitigaBahaya, (value) {
                              setState(() => _segitigaBahaya = value ?? false);
                            }),
                            const SizedBox(height: 8),
                            _buildChecklistItem('Ban Serep', _banSerep, (value) {
                              setState(() => _banSerep = value ?? false);
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ✅ STATUS AKTIF
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.toggle_on_outlined,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status Kendaraan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _statusAktif ? 'Aktif' : 'Tidak Aktif',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _statusAktif,
                              onChanged: (value) {
                                setState(() {
                                  _statusAktif = value;
                                });
                              },
                              activeColor: Colors.green,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveKendaraan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isEdit ? 'Update Kendaraan' : 'Tambah Kendaraan',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tombol Batal
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}