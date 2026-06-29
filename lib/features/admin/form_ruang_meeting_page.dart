import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormRuangMeetingPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;
  final Map<String, dynamic>? ruangData;
  final bool isEdit;

  const FormRuangMeetingPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
    this.ruangData,
    this.isEdit = false,
  });

  @override
  State<FormRuangMeetingPage> createState() => _FormRuangMeetingPageState();
}

class _FormRuangMeetingPageState extends State<FormRuangMeetingPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _namaRuangController;
  late TextEditingController _lokasiController;
  late TextEditingController _kapasitasController;
  final TextEditingController _customFasilitasController =
      TextEditingController();

  String _selectedStatus = 'available';
  String _selectedTipe = 'offline';

  // Preset fasilitas — key = nilai Firestore, value = label tampilan
  final Map<String, String> _presetFasilitas = {
    'proyektor': 'Proyektor',
    'whiteboard': 'Whiteboard',
    'ac': 'AC',
    'tv': 'TV',
    'microphone': 'Microphone',
    'speaker': 'Speaker',
    'webcam': 'Webcam',
  };

  // State checklist preset (key = nilai Firestore)
  final Map<String, bool> _presetChecked = {};

  // Custom fasilitas yang ditambah user (nilai bebas)
  final List<String> _customFasilitas = [];

  final List<String> _statusOptions = ['available', 'unavailable'];
  final List<String> _tipeOptions = ['offline', 'online', 'hybrid'];

  @override
  void initState() {
    super.initState();

    // Init semua preset ke false dulu
    for (final key in _presetFasilitas.keys) {
      _presetChecked[key] = false;
    }

    _namaRuangController = TextEditingController(
      text: widget.ruangData?['namaRuang'] ?? '',
    );
    _lokasiController = TextEditingController(
      text: widget.ruangData?['lokasi'] ?? '',
    );
    _kapasitasController = TextEditingController(
      text: widget.ruangData?['kapasitas']?.toString() ?? '',
    );

    final statusFromDb = widget.ruangData?['status'] ?? 'available';
    _selectedStatus = _statusOptions.contains(statusFromDb) ? statusFromDb : 'available';

    final tipeFromDb = widget.ruangData?['tipe'] ?? 'offline';
    _selectedTipe = _tipeOptions.contains(tipeFromDb) ? tipeFromDb : 'offline';

    // Load fasilitas dari data existing
    if (widget.ruangData != null) {
      final fasilitasArray =
          widget.ruangData!['fasilitas'] as List<dynamic>?;
      if (fasilitasArray != null) {
        final fasilitasList =
            fasilitasArray.map((e) => e.toString()).toList();

        // Centang preset yang cocok
        for (final key in _presetFasilitas.keys) {
          _presetChecked[key] = fasilitasList.contains(key);
        }

        // Sisanya masuk custom
        for (final item in fasilitasList) {
          if (!_presetFasilitas.containsKey(item)) {
            _customFasilitas.add(item);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _namaRuangController.dispose();
    _lokasiController.dispose();
    _kapasitasController.dispose();
    _customFasilitasController.dispose();
    super.dispose();
  }

  // Gabungkan preset yang dicentang + custom jadi satu array
  List<String> _buildFasilitasArray() {
    final List<String> result = [];
    for (final key in _presetFasilitas.keys) {
      if (_presetChecked[key] == true) result.add(key);
    }
    result.addAll(_customFasilitas);
    return result;
  }

  void _addCustomFasilitas() {
    final value = _customFasilitasController.text.trim();
    if (value.isEmpty) return;

    // Jangan duplikat dengan preset
    if (_presetFasilitas.containsKey(value.toLowerCase())) {
      _showSnackbar(
        '"${_presetFasilitas[value.toLowerCase()]}" sudah ada di daftar preset.',
        isError: true,
      );
      return;
    }

    // Jangan duplikat dengan custom yang sudah ada
    if (_customFasilitas
        .any((e) => e.toLowerCase() == value.toLowerCase())) {
      _showSnackbar('Fasilitas "$value" sudah ditambahkan.', isError: true);
      return;
    }

    setState(() {
      _customFasilitas.add(value);
      _customFasilitasController.clear();
    });
  }

  void _removeCustomFasilitas(String item) {
    setState(() => _customFasilitas.remove(item));
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

  Future<void> _saveRuang() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final namaRuang = _namaRuangController.text.trim();
      final lokasi = _lokasiController.text.trim();
      final kapasitas =
          int.tryParse(_kapasitasController.text.trim()) ?? 0;

      if (widget.isEdit) {
        await _updateRuang(
            namaRuang: namaRuang, lokasi: lokasi, kapasitas: kapasitas);
      } else {
        await _createRuang(
            namaRuang: namaRuang, lokasi: lokasi, kapasitas: kapasitas);
      }
    } catch (e) {
      print('Error saving ruang: $e');
      _showSnackbar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createRuang({
    required String namaRuang,
    required String lokasi,
    required int kapasitas,
  }) async {
    final namaCheck = await FirebaseFirestore.instance
        .collection('rooms')
        .where('namaRuang', isEqualTo: namaRuang)
        .get();

    if (namaCheck.docs.isNotEmpty) throw 'Nama ruang meeting sudah terdaftar';

    await FirebaseFirestore.instance.collection('rooms').add({
      'namaRuang': namaRuang,
      'lokasi': lokasi,
      'kapasitas': kapasitas,
      'status': _selectedStatus,
      'tipe': _selectedTipe,
      'fasilitas': _buildFasilitasArray(),
      'photos': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _showSnackbar('Ruang meeting berhasil ditambahkan!');
    Navigator.pop(context, true);
  }

  Future<void> _updateRuang({
    required String namaRuang,
    required String lokasi,
    required int kapasitas,
  }) async {
    final ruangId = widget.ruangData!['id'];
    final oldNamaRuang = widget.ruangData!['namaRuang'];

    if (namaRuang != oldNamaRuang) {
      final namaCheck = await FirebaseFirestore.instance
          .collection('rooms')
          .where('namaRuang', isEqualTo: namaRuang)
          .get();

      if (namaCheck.docs.isNotEmpty) {
        throw 'Nama ruang meeting sudah terdaftar';
      }
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(ruangId)
        .update({
      'namaRuang': namaRuang,
      'lokasi': lokasi,
      'kapasitas': kapasitas,
      'status': _selectedStatus,
      'tipe': _selectedTipe,
      'fasilitas': _buildFasilitasArray(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _showSnackbar('Ruang meeting berhasil diupdate!');
    Navigator.pop(context, true);
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) return '$fieldName wajib diisi';
    return null;
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) return '$fieldName wajib diisi';
    if (int.tryParse(value) == null) return '$fieldName harus berupa angka';
    return null;
  }

  // ── UI Helpers ──────────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade800,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade600),
    );
  }

  Widget _buildPresetCheckbox(String key) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: CheckboxListTile(
        title: Text(
          _presetFasilitas[key]!,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade900,
          ),
        ),
        value: _presetChecked[key] ?? false,
        onChanged: (v) => setState(() => _presetChecked[key] = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: Colors.blue.shade700,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
      ),
    );
  }

  Widget _buildCustomChips() {
    if (_customFasilitas.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _customFasilitas.map((item) {
        return Chip(
          label: Text(
            item,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.blue.shade50,
          side: BorderSide(color: Colors.blue.shade200),
          deleteIcon:
              Icon(Icons.close, size: 16, color: Colors.blue.shade700),
          onDeleted: () => _removeCustomFasilitas(item),
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        );
      }).toList(),
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
              // ── Header ─────────────────────────────────────────────
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
                      widget.isEdit
                          ? 'Edit Ruang Meeting'
                          : 'Tambah Ruang Meeting',
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
                        Icons.meeting_room_outlined,
                        size: 24,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Subtitle ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEdit
                          ? 'Edit Data Ruang Meeting'
                          : 'Tambah Ruang Meeting Baru',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isEdit
                          ? 'Perbarui data ruang meeting yang sudah ada'
                          : 'Tambahkan ruang meeting baru ke dalam sistem',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Form ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama Ruang
                      _buildLabel('Nama Ruang'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _namaRuangController,
                        decoration: _inputDecoration(
                          hint: 'Contoh: Ruang Tanjung Emas',
                          icon: Icons.meeting_room_outlined,
                        ),
                        validator: (v) =>
                            _validateRequired(v, 'Nama ruang'),
                      ),

                      const SizedBox(height: 16),

                      // Lokasi
                      _buildLabel('Lokasi'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _lokasiController,
                        decoration: _inputDecoration(
                          hint: 'Contoh: Gedung A Lantai 2',
                          icon: Icons.location_on_outlined,
                        ),
                        validator: (v) =>
                            _validateRequired(v, 'Lokasi'),
                      ),

                      const SizedBox(height: 16),

                      // Kapasitas
                      _buildLabel('Kapasitas (orang)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _kapasitasController,
                        decoration: _inputDecoration(
                          hint: 'Contoh: 20',
                          icon: Icons.people_outlined,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            _validateNumber(v, 'Kapasitas'),
                      ),

                      const SizedBox(height: 16),

                      // Status
                      _buildLabel('Status Ruang'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: _inputDecoration(
                          hint: 'Pilih status',
                          icon: Icons.toggle_on_outlined,
                        ),
                        items: _statusOptions.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s == 'available'
                                ? 'Tersedia'
                                : 'Tidak Tersedia'),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedStatus = v!),
                        dropdownColor: Colors.white,
                      ),

                      const SizedBox(height: 16),

                      // Tipe
                      _buildLabel('Tipe Ruang'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedTipe,
                        decoration: _inputDecoration(
                          hint: 'Pilih tipe',
                          icon: Icons.category_outlined,
                        ),
                          items: _tipeOptions.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(
                                t == 'online' ? 'Online' : t == 'hybrid' ? 'Hybrid' : 'Offline',
                              ),
                            );
                          }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedTipe = v!),
                        dropdownColor: Colors.white,
                      ),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header seksi fasilitas
                            Row(
                              children: [
                                Icon(Icons.checklist_rtl_rounded,
                                    color: Colors.grey.shade600),
                                const SizedBox(width: 12),
                                Text(
                                  'Fasilitas Ruang',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Centang fasilitas yang tersedia, atau tambahkan fasilitas lainnya secara manual.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),

                            // Sub-header preset
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade400,
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'FASILITAS UMUM',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Preset checkboxes
                            ...(_presetFasilitas.keys.map((key) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: _buildPresetCheckbox(key),
                              );
                            })),

                            // Divider
                            Divider(color: Colors.grey.shade200,
                                height: 24),

                            // Sub-header custom
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade400,
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'FASILITAS TAMBAHAN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Input + tombol tambah
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller:
                                        _customFasilitasController,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Contoh: Podium, Layar LED...',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color:
                                                Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color:
                                                Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color:
                                                Colors.blue.shade400),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12),
                                      hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade400),
                                    ),
                                    style:
                                        const TextStyle(fontSize: 14),
                                    onSubmitted: (_) =>
                                        _addCustomFasilitas(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _addCustomFasilitas,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                    ),
                                    child: const Icon(
                                        Icons.add_rounded,
                                        size: 22),
                                  ),
                                ),
                              ],
                            ),

                            // Chips custom yang sudah ditambahkan
                            if (_customFasilitas.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildCustomChips(),
                            ] else ...[
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada fasilitas tambahan.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveRuang,
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
                                  widget.isEdit
                                      ? 'Update Ruang'
                                      : 'Tambah Ruang',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                                color: Colors.grey.shade300),
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