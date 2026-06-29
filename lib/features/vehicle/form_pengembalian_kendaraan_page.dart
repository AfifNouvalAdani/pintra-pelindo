import 'package:flutter/material.dart';
import '../vehicle/berhasil_pengembalian_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FormPengembalianKendaraanPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String bookingId;
  final String vehicleId;
  final Map<String, dynamic>? vehicleData;
  final Map<String, dynamic> bookingData;

  const FormPengembalianKendaraanPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.bookingId,
    required this.vehicleId,
    this.vehicleData,
    required this.bookingData,
  });

  @override
  State<FormPengembalianKendaraanPage> createState() =>
      _FormPengembalianKendaraanPageState();
}

class _FormPengembalianKendaraanPageState
    extends State<FormPengembalianKendaraanPage> {
  String? kondisi;
  String? kelengkapan;
  String? sisaBBM;

  bool p3k = true;
  bool dongkrak = true;
  bool apar = true;
  bool segitigaBahaya = true;
  bool banSerep = true;

  Map<String, dynamic>? _kondisiAwalData;
  List<String> _kelengkapanKendaraan = [];

  final TextEditingController uraianKondisiController =
      TextEditingController();
  final TextEditingController uraianKelengkapanController =
      TextEditingController();
  final TextEditingController odoController = TextEditingController();

  bool _isUploading = false;
  List<String> _photoBase64List = [];
  static const int _maxPhotos = 4;

  @override
void initState() {
  super.initState();
  _loadKondisiAwal();
}

Future<void> _loadKondisiAwal() async {
  try {
    final bookingDoc = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .doc(widget.bookingId)
        .get();
    
    if (bookingDoc.exists) {
      final data = bookingDoc.data();
      final kondisiAwal = data?['kondisiAwal'] as Map<String, dynamic>?;
      
      setState(() {
        _kondisiAwalData = kondisiAwal;
        
        // 🔥 REVISI: Load kelengkapan items dari kondisi awal
        if (kondisiAwal != null && kondisiAwal['kelengkapanItems'] != null) {
          final kelengkapanItems = kondisiAwal['kelengkapanItems'] as List<dynamic>;
          _kelengkapanKendaraan = kelengkapanItems.map((e) => e.toString()).toList();
          
          // Set checkbox sesuai data awal
          p3k = _kelengkapanKendaraan.contains('P3K');
          dongkrak = _kelengkapanKendaraan.contains('Dongkrak');
          apar = _kelengkapanKendaraan.contains('Apar');
          segitigaBahaya = _kelengkapanKendaraan.contains('Segitiga Bahaya');
          banSerep = _kelengkapanKendaraan.contains('ban serep');
        }
      });
    }
  } catch (e) {
    print('Error loading kondisi awal: $e');
  }
}

  // Fungsi untuk menghitung persentase kelengkapan
  double _calculateCompleteness() {
    final items = [p3k, dongkrak, apar, segitigaBahaya, banSerep];
    final completed = items.where((item) => item == true).length;
    return completed / items.length;
  }

  // Widget untuk checklist item yang konsisten
  Widget _buildChecklistItem(
      String label, bool value, Function(bool?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            onChanged(!value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value ? Colors.blue.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color:
                          value ? Colors.blue.shade700 : Colors.grey.shade300,
                      width: value ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: value
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.blue.shade700,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
                Icon(
                  value ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: value ? Colors.green.shade600 : Colors.orange.shade600,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSaving = false;

  Future<void> _simpanForm() async {
    // Validasi form
    if (kondisi == null) {
      _showSnackBar('Pilih kondisi kendaraan saat pengembalian');
      return;
    }

    if (kondisi == 'Tidak Seperti Awal Peminjaman' && uraianKondisiController.text.isEmpty) {
      _showSnackBar('Uraikan perubahan kondisi kendaraan');
      return;
    }

    if (kelengkapan == null) {
      _showSnackBar('Pilih kelengkapan kendaraan saat pengembalian');
      return;
    }

    if (kelengkapan == 'Tidak Seperti Awal Peminjaman') {
      // 🔥 FIX: Cek apakah ADA yang unchecked (kehilangan)
      // Jika TIDAK ADA yang unchecked, berarti semua masih ada = salah pilih opsi
      final adaYangHilang = !p3k || !dongkrak || !apar || !segitigaBahaya || !banSerep;
      
      if (!adaYangHilang) {
        _showSnackBar('Semua kelengkapan masih ada. Pilih "Seperti Awal Peminjaman" atau uncheck item yang hilang');
        return;
      }

      if (uraianKelengkapanController.text.isEmpty) {
        _showSnackBar('Uraikan perubahan kelengkapan');
        return;
      }
    }

    if (sisaBBM == null) {
      _showSnackBar('Pilih sisa BBM kendaraan saat pengembalian');
      return;
    }

    if (odoController.text.isEmpty) {
      _showSnackBar('Masukkan odometer akhir');
      return;
    }

    final int? odometerValue = int.tryParse(odoController.text);
    if (odometerValue == null) {
      _showSnackBar('Odometer harus berupa angka');
      return;
    }

    final int? odometerAwal = _kondisiAwalData?['odometerAwal'] as int?;
    if (odometerAwal != null && odometerValue < odometerAwal) {
      _showSnackBar('Odometer akhir ($odometerValue km) tidak boleh kurang dari odometer awal ($odometerAwal km)');
      return;
    }
    if (odometerAwal != null && odometerValue == odometerAwal) {
      _showSnackBar('Odometer akhir tidak boleh sama dengan odometer awal. Minimal bertambah 1 km');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1️⃣ CEK STATUS BOOKING
      final bookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Data peminjaman tidak ditemukan');
      }

      final currentStatus = bookingDoc.data()?['status'];
      if (currentStatus != 'ON_GOING') {
        throw Exception('Peminjaman tidak dalam status ON_GOING');
      }

      List<String> kelengkapanTersedia = [];
      if (p3k) kelengkapanTersedia.add('P3K');
      if (dongkrak) kelengkapanTersedia.add('Dongkrak');
      if (apar) kelengkapanTersedia.add('Apar');
      if (segitigaBahaya) kelengkapanTersedia.add('Segitiga Bahaya');
      if (banSerep) kelengkapanTersedia.add('ban serep');

      Map<String, dynamic> kondisiAkhirData;

      if (kondisi == 'Seperti Awal Peminjaman' && kelengkapan == 'Seperti Awal Peminjaman') {
        kondisiAkhirData = Map<String, dynamic>.from(_kondisiAwalData ?? {});
        kondisiAkhirData['statusPengembalian'] = 'Seperti Awal Peminjaman';
        kondisiAkhirData['sisaBBM'] = sisaBBM;
        kondisiAkhirData['odometerAkhir'] = odometerValue;
        kondisiAkhirData['timestampPengembalian'] = Timestamp.now();
        kondisiAkhirData['returnedBy'] = widget.userId;
        kondisiAkhirData['returnedByName'] = widget.userName;
        
          if (_photoBase64List.isNotEmpty) {
            kondisiAkhirData['fotoPengembalianBase64List'] = _photoBase64List;
            kondisiAkhirData['fotoPengembalianCount'] = _photoBase64List.length;
            kondisiAkhirData['fotoPengembalianTimestamp'] = Timestamp.now();
          }
        } else {
          // Ada perubahan dari kondisi awal
          kondisiAkhirData = {
            'statusPengembalian': 'Ada Perubahan',
            'kondisiAwal': _kondisiAwalData?['kondisi'] ?? 'Tidak Diketahui',
            'kondisiAkhir': kondisi == 'Tidak Seperti Awal Peminjaman' ? 'Tidak Baik' : (_kondisiAwalData?['kondisi'] ?? 'Baik'),
            'kelengkapanAwal': _kondisiAwalData?['kelengkapan'] ?? 'Tidak Diketahui',
            'kelengkapanAkhir': kelengkapan == 'Tidak Seperti Awal Peminjaman' ? 'Tidak Lengkap' : (_kondisiAwalData?['kelengkapan'] ?? 'Lengkap'),
            'kelengkapanItems': kelengkapanTersedia,
            'sisaBBM': sisaBBM,
            'odometerAkhir': odometerValue,
            'timestampPengembalian': Timestamp.now(),
            'returnedBy': widget.userId,
            'returnedByName': widget.userName,
          };

          if (kondisi == 'Tidak Seperti Awal Peminjaman' && uraianKondisiController.text.isNotEmpty) {
            kondisiAkhirData['uraianKondisi'] = uraianKondisiController.text;
          }

          if (kelengkapan == 'Tidak Seperti Awal Peminjaman' && uraianKelengkapanController.text.isNotEmpty) {
            kondisiAkhirData['uraianKelengkapan'] = uraianKelengkapanController.text;
          }

          if (_photoBase64List.isNotEmpty) {
            kondisiAkhirData['fotoPengembalianBase64List'] = _photoBase64List;
            kondisiAkhirData['fotoPengembalianCount'] = _photoBase64List.length;
            kondisiAkhirData['fotoPengembalianTimestamp'] = Timestamp.now();
          }
        }

      // Update booking
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .update({
        'kondisiAkhir': kondisiAkhirData,
        'status': 'DONE',
        'actualReturnTime': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      print('✅ Booking updated to DONE');

      List<String> kelengkapanFinal = kondisi == 'Seperti Awal Peminjaman' && kelengkapan == 'Seperti Awal Peminjaman'
          ? (_kondisiAwalData?['kelengkapanItems'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? []
          : kelengkapanTersedia;

      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vehicleId)
          .update({
        'kelengkapan': kelengkapanFinal,
        'odometerTerakhir': odometerValue,
        'sisaBBMTerakhir': sisaBBM!,
        'updatedAt': Timestamp.now(),
      });

      print('✅ Vehicle updated');

      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'VEHICLE_RETURNED',
        'oldStatus': 'ON_GOING',
        'newStatus': 'DONE',
        'status': 'DONE',
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'userId': widget.userId,
        'timestamp': Timestamp.now(),
        'note': 'Kendaraan telah dikembalikan dan kondisi akhir telah dicatat oleh ${widget.userName}',
        'odometerAkhir': odometerValue,
      });
      print('✅ Approval history added');

      setState(() => _isSaving = false);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      print('❌ Error saving form: $e');
      
      if (mounted) {
        _showSnackBar('Gagal menyimpan: ${e.toString()}');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

void _showSuccessDialog() {
  if (mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BerhasilPengembalianPage(
          bookingId: widget.bookingId,
        ),
      ),
    );
  }
}

Future<void> _uploadFoto() async {
  if (_photoBase64List.length >= _maxPhotos) {
    _showSnackBar('Maksimal $_maxPhotos foto');
    return;
  }

  try {
    final ImagePicker picker = ImagePicker();

    ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Sumber Foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              subtitle: kIsWeb ? const Text('Gunakan webcam atau kamera HP', style: TextStyle(fontSize: 12)) : null,
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              subtitle: kIsWeb ? const Text('Pilih dari file', style: TextStyle(fontSize: 12)) : null,
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final sizeInKB = base64String.length * 0.75 / 1024;

        if (sizeInKB > 800) {
          _showSnackBar('Foto terlalu besar (${sizeInKB.toStringAsFixed(0)}KB). Maksimal 800KB');
          setState(() => _isUploading = false);
          return;
        }

        setState(() {
          _photoBase64List.add(base64String);
          _isUploading = false;
        });
      } catch (e) {
        setState(() => _isUploading = false);
        _showSnackBar('Gagal memproses foto');
      }
    }
  } catch (e) {
    setState(() => _isUploading = false);
    _showSnackBar(kIsWeb && e.toString().contains('camera')
        ? 'Kamera tidak tersedia. Gunakan opsi Galeri'
        : 'Gagal mengambil foto');
  }
}

void _hapusFoto(int index) {
  setState(() {
    _photoBase64List.removeAt(index);
  });
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
          'Pengembalian Kendaraan',
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
              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pastikan kondisi kendaraan sesuai dengan saat peminjaman. Data ini akan menjadi acuan untuk peminjaman berikutnya.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Kondisi Kendaraan Saat Pengembalian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah kondisi kendaraan sama seperti saat awal peminjaman?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: kondisi,
                  items: const [
                    DropdownMenuItem(
                      value: 'Seperti Awal Peminjaman',
                      child: Text('Seperti Awal Peminjaman'),
                    ),
                    DropdownMenuItem(
                      value: 'Tidak Seperti Awal Peminjaman',
                      child: Text('Tidak Seperti Awal Peminjaman'),
                    ),
                  ],
                  onChanged: (v) => setState(() => kondisi = v),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue.shade700,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade500,
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                ),
              ),

              if (kondisi == 'Tidak Seperti Awal Peminjaman') ...[
                const SizedBox(height: 16),
                Text(
                  'Uraian Kondisi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: uraianKondisiController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Uraikan perubahan kondisi kendaraan dari awal peminjaman...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue.shade700,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Text(
                'Foto Kendaraan Saat Pengembalian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unggah foto kondisi kendaraan saat dikembalikan (maks. $_maxPhotos foto)',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),

              if (_photoBase64List.isNotEmpty) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _photoBase64List.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(_photoBase64List[index]),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => _hapusFoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Foto ${index + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              if (_photoBase64List.length < _maxPhotos)
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: InkWell(
                    onTap: _isUploading ? null : _uploadFoto,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isUploading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue.shade700,
                                ),
                              )
                            : Icon(Icons.add_photo_alternate_rounded,
                                size: 32, color: Colors.blue.shade700),
                        const SizedBox(height: 8),
                        Text(
                          _isUploading
                              ? 'Mengunggah...'
                              : '+ Tambah Foto (${_photoBase64List.length}/$_maxPhotos)',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),
              Text(
                'Kelengkapan Kendaraan Saat Pengembalian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah kelengkapan kendaraan sama seperti saat awal peminjaman?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: kelengkapan,
                  items: const [
                    DropdownMenuItem(
                      value: 'Seperti Awal Peminjaman',
                      child: Text('Seperti Awal Peminjaman'),
                    ),
                    DropdownMenuItem(
                      value: 'Tidak Seperti Awal Peminjaman',
                      child: Text('Tidak Seperti Awal Peminjaman'),
                    ),
                  ],
                  onChanged: (v) => setState(() => kelengkapan = v),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue.shade700,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade500,
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                ),
              ),

              if (kelengkapan == 'Tidak Seperti Awal Peminjaman') ...[
                const SizedBox(height: 24),
                Container(
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
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.checklist_rtl_rounded,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kelengkapan Kendaraan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Centang item yang masih tersedia saat pengembalian',
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

                      const SizedBox(height: 20),

                      // Tiga Item Checklist dalam satu kolom
                      Column(
                      children: [
                        _buildChecklistItem(
                          'P3K',
                          p3k,
                          (value) => setState(() => p3k = value ?? false),
                        ),
                        const SizedBox(height: 8),
                        _buildChecklistItem(
                          'Dongkrak',
                          dongkrak,
                          (value) => setState(() => dongkrak = value ?? false),
                        ),
                        const SizedBox(height: 8),
                        _buildChecklistItem(
                          'Apar',
                          apar,
                          (value) => setState(() => apar = value ?? false),
                        ),
                        const SizedBox(height: 8),
                        _buildChecklistItem(
                          'Segitiga Bahaya',
                          segitigaBahaya,
                          (value) => setState(() => segitigaBahaya = value ?? false),
                        ),
                        const SizedBox(height: 8),
                        _buildChecklistItem(
                          'Ban Serep',
                          banSerep,
                          (value) => setState(() => banSerep = value ?? false),
                        ),

                          const SizedBox(height: 16),

                          // Status Kelengkapan
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _calculateCompleteness() >= 1.0
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _calculateCompleteness() >= 1.0
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _calculateCompleteness() >= 1.0
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  color: _calculateCompleteness() >= 1.0
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _calculateCompleteness() >= 1.0
                                            ? 'Semua kelengkapan tersedia'
                                            : 'Kelengkapan tidak lengkap',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _calculateCompleteness() >= 1.0
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800,
                                        ),
                                      ),
                                      Text(
                                        '${(_calculateCompleteness() * 100).toInt()}% item tersedia',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _calculateCompleteness() >= 1.0
                                              ? Colors.green.shade600
                                              : Colors.orange.shade600,
                                        ),
                                      ),
                                    ],
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

                const SizedBox(height: 24),

                // Uraian Kehilangan
                Container(
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
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.description_rounded,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keterangan Kehilangan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Jelaskan kronologi kehilangan kelengkapan saat pengembalian',
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

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: uraianKelengkapanController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Segitiga darurat hilang saat perjalanan menuju tujuan...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.blue.shade700,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Sisa BBM
              Text(
                'Sisa BBM Saat Pengembalian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih perkiraan sisa bahan bakar kendaraan',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: sisaBBM,
                items: const [
                  DropdownMenuItem(
                    value: '0-25%',
                    child: Text('0-25% (Hampir Habis)'),
                  ),
                  DropdownMenuItem(
                    value: '25-50%',
                    child: Text('25-50% (Kurang dari Setengah)'),
                  ),
                  DropdownMenuItem(
                    value: '50-75%',
                    child: Text('50-75% (Lebih dari Setengah)'),
                  ),
                  DropdownMenuItem(
                    value: '75-100%',
                    child: Text('75-100% (Hampir Penuh)'),
                  ),
                ],
                onChanged: (v) => setState(() => sisaBBM = v),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue.shade700,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade500,
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                ),
              ),

              const SizedBox(height: 24),

              // Odometer Akhir
              Text(
                'Odometer Akhir',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan angka odometer saat pengembalian',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              if (_kondisiAwalData?['odometerAwal'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.speed_rounded, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Odometer saat awal pinjam: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        '${_kondisiAwalData!['odometerAwal']} km',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: odoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.speed_rounded,
                    color: Colors.grey.shade500,
                  ),
                  hintText: 'Contoh: 45678',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue.shade700,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                ),
              ),

              const SizedBox(height: 40),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _simpanForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSaving ? Colors.grey.shade400 : Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Menyimpan...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Simpan Pengembalian',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Tombol Batal
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
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
            ],
          ),
        ),
      ),
    );
  }
}