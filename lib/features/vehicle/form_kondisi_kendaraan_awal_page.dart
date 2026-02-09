import 'package:flutter/material.dart';
import '../dashboard/dashboard_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FormKondisiKendaraanAwalPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String bookingId;           
  final String vehicleId;           
  final Map<String, dynamic>? vehicleData;
  final String userDivision;

  const FormKondisiKendaraanAwalPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.bookingId,        
    required this.vehicleId,        
    this.vehicleData,
    required this.userDivision,               
  });

  @override
  State<FormKondisiKendaraanAwalPage> createState() =>
      _FormKondisiKendaraanAwalPageState();
}

class _FormKondisiKendaraanAwalPageState
    extends State<FormKondisiKendaraanAwalPage> {
  String? kondisi;
  String? kelengkapan;
  bool p3k = true;
  bool dongkrak = true;
  bool apar = true;
  bool segitigaBahaya = true;
  bool banSerep = true;


  final TextEditingController uraianKondisiController =
      TextEditingController();
  final TextEditingController uraianKelengkapanController =
      TextEditingController();
  final TextEditingController odoController = TextEditingController();

  bool _isUploading = false;
  bool _hasPhoto = false;
  File? _photoFile;
  String? _photoBase64; // ✅ Ganti dari _photoUrl ke _photoBase64
  bool _isSaving = false;

  List<String> _kelengkapanKendaraan = [];

  @override
void initState() {
  super.initState();
  _loadKelengkapanKendaraan();
}

Future<void> _loadKelengkapanKendaraan() async {
  try {
    final vehicleDoc = await FirebaseFirestore.instance
        .collection('vehicles')
        .doc(widget.vehicleId)
        .get();
    
    if (vehicleDoc.exists) {
      final data = vehicleDoc.data();
      final kelengkapanArray = data?['kelengkapan'] as List<dynamic>?;
      
      if (kelengkapanArray != null) {
        setState(() {
          _kelengkapanKendaraan = kelengkapanArray.map((e) => e.toString()).toList();
          
          // Set default value berdasarkan data dari database
          p3k = _kelengkapanKendaraan.contains('P3K');
          dongkrak = _kelengkapanKendaraan.contains('Dongkrak');
          apar = _kelengkapanKendaraan.contains('Apar');
          segitigaBahaya = _kelengkapanKendaraan.contains('Segitiga Bahaya');
          banSerep = _kelengkapanKendaraan.contains('ban serep');
        });
      }
    }
  } catch (e) {
    print('Error loading kelengkapan kendaraan: $e');
  }
}

  double _calculateCompleteness() {
    final items = [p3k, dongkrak, apar, segitigaBahaya, banSerep];
    final completed = items.where((item) => item == true).length;
    return completed / items.length;
  }
  // Widget untuk checklist item yang konsisten
  Widget _buildChecklistItem(String label, bool value, Function(bool?) onChanged) {
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
                      color: value ? Colors.blue.shade700 : Colors.grey.shade300,
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

  Future<void> _simpanForm() async {
    // ========== VALIDASI FORM ==========
    if (kondisi == null) {
      _showSnackBar('Pilih kondisi kendaraan');
      return;
    }

    if (kondisi == 'Tidak Baik' && uraianKondisiController.text.isEmpty) {
      _showSnackBar('Uraikan kondisi tidak baik');
      return;
    }

    if (kelengkapan == null) {
      _showSnackBar('Pilih kelengkapan kendaraan');
      return;
    }

    if (kelengkapan == 'Tidak Lengkap') {
      // 🔥 FIX: Cek apakah ADA yang unchecked (hilang)
      final adaYangHilang = !p3k || !dongkrak || !apar || !segitigaBahaya || !banSerep;
      
      if (!adaYangHilang) {
        _showSnackBar('Semua kelengkapan masih ada. Pilih "Lengkap" atau uncheck item yang hilang');
        return;
      }

      if (uraianKelengkapanController.text.isEmpty) {
        _showSnackBar('Uraikan kronologi kehilangan kelengkapan');
        return;
      }
    }

    if (odoController.text.isEmpty) {
      _showSnackBar('Masukkan odometer awal');
      return;
    }

    final int? odometerValue = int.tryParse(odoController.text);
    if (odometerValue == null) {
      _showSnackBar('Odometer harus berupa angka');
      return;
    }

    // ========== MULAI PROSES SIMPAN ==========
    setState(() => _isSaving = true);

    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Data peminjaman tidak ditemukan');
      }

      final currentStatus = bookingDoc.data()?['status'];
      if (currentStatus != 'APPROVAL_3') {
        throw Exception('Peminjaman tidak dalam status yang tepat untuk pengambilan kendaraan. Status saat ini: $currentStatus');
      }

      // 🔥 REVISI: Siapkan array kelengkapan yang tersedia
      List<String> kelengkapanTersedia = [];
      if (p3k) kelengkapanTersedia.add('P3K');
      if (dongkrak) kelengkapanTersedia.add('Dongkrak');
      if (apar) kelengkapanTersedia.add('Apar');
      if (segitigaBahaya) kelengkapanTersedia.add('Segitiga Bahaya');
      if (banSerep) kelengkapanTersedia.add('ban serep');

      // Siapkan data kondisi awal
      Map<String, dynamic> kondisiAwalData = {
        'kondisi': kondisi,
        'kelengkapan': kelengkapan,
        'kelengkapanItems': kelengkapanTersedia, // 🔥 REVISI: Simpan sebagai array
        'odometerAwal': odometerValue,
        'timestamp': Timestamp.now(),
        'filledBy': widget.userId,
        'filledByName': widget.userName,
      };

      if (kondisi == 'Tidak Baik' && uraianKondisiController.text.isNotEmpty) {
        kondisiAwalData['uraianKondisi'] = uraianKondisiController.text;
      }

      if (kelengkapan == 'Tidak Lengkap' && uraianKelengkapanController.text.isNotEmpty) {
        kondisiAwalData['uraianKelengkapan'] = uraianKelengkapanController.text;
      }

      if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
        kondisiAwalData['fotoBase64'] = _photoBase64;
        kondisiAwalData['fotoTimestamp'] = Timestamp.now();
      }

      // Update booking
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .update({
        'kondisiAwal': kondisiAwalData,
        'status': 'ON_GOING',
        'actualPickupTime': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      print('✅ Booking updated to ON_GOING');

      // 🔥 REVISI: Update vehicles collection dengan struktur yang benar
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vehicleId)
          .update({
        'kelengkapan': kelengkapanTersedia, // 🔥 Update array kelengkapan
        'odometerTerakhir': odometerValue,
        'updatedAt': Timestamp.now(),
      });

      print('✅ Vehicle updated');

      // Approval history tetap sama
      await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(widget.bookingId)
          .collection('approval_history')
          .add({
        'action': 'VEHICLE_PICKED_UP',
        'oldStatus': 'APPROVAL_3',
        'newStatus': 'ON_GOING',
        'status': 'ON_GOING',
        'actionBy': widget.userName,
        'actionRole': widget.role,
        'userId': widget.userId,
        'timestamp': Timestamp.now(),
        'note': 'Kendaraan telah diambil dan kondisi awal telah dicatat oleh ${widget.userName}',
        'odometerAwal': odometerValue,
      });

      print('✅ Approval history added');

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kondisi kendaraan berhasil dicatat'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              role: widget.role,
              userName: widget.userName,
              userId: widget.userId,
              userDivision: widget.userDivision,
            ),
          ),
          (route) => false,
        );
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

Future<void> _uploadFoto() async {
  try {
    final ImagePicker picker = ImagePicker();
    
    // ✅ Deteksi apakah running di Web atau Mobile
    final bool isWebPlatform = kIsWeb;
    
    ImageSource? source;
    
    if (isWebPlatform) {
      // 🌐 UNTUK WEB: Hanya tampilkan opsi yang tersedia
      source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pilih Sumber Foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Di web, kamera hanya muncul jika ada device kamera
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                subtitle: const Text('Gunakan webcam atau kamera HP', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                subtitle: const Text('Pilih dari file', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    } else {
      // 📱 UNTUK MOBILE (APK): Tampilkan kedua opsi normal
      source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pilih Sumber Foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }

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
          if (mounted) {
            _showSnackBar('Foto terlalu besar (${sizeInKB.toStringAsFixed(0)}KB). Maksimal 800KB');
          }
          setState(() => _isUploading = false);
          return;
        }

        setState(() {
          _photoFile = null;
          _photoBase64 = base64String;
          _hasPhoto = true;
          _isUploading = false;
        });
        
        print('✅ Foto berhasil dipilih. Size: ${sizeInKB.toStringAsFixed(2)} KB');
      } catch (e) {
        print('❌ Error converting image: $e');
        setState(() => _isUploading = false);
        if (mounted) {
          _showSnackBar('Gagal memproses foto');
        }
      }
    }
  } catch (e) {
    print('❌ Error picking image: $e');
    setState(() => _isUploading = false);
    if (mounted) {
      // ✅ Pesan error yang lebih informatif
      String errorMessage = 'Gagal mengambil foto';
      if (kIsWeb && e.toString().contains('camera')) {
        errorMessage = 'Kamera tidak tersedia. Gunakan opsi Galeri atau pastikan browser memiliki izin kamera';
      }
      _showSnackBar(errorMessage);
    }
  }
}

  void _hapusFoto() {
    setState(() {
      _hasPhoto = false;
      _photoFile = null;
      _photoBase64 = null;
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
          'Kondisi Kendaraan Awal',
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
                        'Isi form dengan teliti. Data ini akan menjadi acuan saat pengembalian kendaraan.',
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

              // Kondisi Peminjaman Kendaraan
              Text(
                'Kondisi Kendaraan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bagaimana kondisi kendaraan saat ini?',
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
                    value: 'Baik',
                    child: Text('Baik'),
                  ),
                  DropdownMenuItem(
                    value: 'Tidak Baik',
                    child: Text('Tidak Baik'),
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

              if (kondisi == 'Tidak Baik') ...[
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
                    hintText: 'Uraikan kondisi terkini kendaraan...',
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

              // Upload Foto
              Text(
                'Foto Kendaraan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unggah foto kondisi kendaraan saat ini',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),

              _hasPhoto
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Column(
                        children: [
                          // ✅ TAMBAHKAN PREVIEW FOTO
                          if (_photoBase64 != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(_photoBase64!),
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Foto terunggah',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Size: ${(_photoBase64!.length * 0.75 / 1024).toStringAsFixed(2)} KB',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _hapusFoto,
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
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
                                : Icon(
                                    Icons.cloud_upload_rounded,
                                    size: 40,
                                    color: Colors.blue.shade700,
                                  ),
                            const SizedBox(height: 12),
                            Text(
                              _isUploading
                                  ? 'Mengunggah...'
                                  : 'Klik untuk upload foto',
                              style: TextStyle(
                                color: _isUploading
                                    ? Colors.grey.shade600
                                    : Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Format: JPG, PNG (max 5MB)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

              const SizedBox(height: 32),

              // Kelengkapan Peminjaman Kendaraan
              Text(
                'Kelengkapan Kendaraan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah kelengkapan kendaraan lengkap?',
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
                    value: 'Lengkap',
                    child: Text('Lengkap'),
                  ),
                  DropdownMenuItem(
                    value: 'Tidak Lengkap',
                    child: Text('Tidak Lengkap'),
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

              if (kelengkapan == 'Tidak Lengkap') ...[
                const SizedBox(height: 24),

                // Checklist Kelengkapan
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
                                  'Centang item yang masih tersedia',
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
                                  'Jelaskan kronologi kehilangan kelengkapan',
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
                          hintText: 'Contoh: Segitiga darurat hilang sejak peminjaman terakhir pada 15 Januari 2024...',
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

              // Odometer Awal
              Text(
                'Odometer Awal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan angka odometer saat ini',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: odoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.speed_rounded,
                    color: Colors.grey.shade500,
                  ),
                  hintText: 'Contoh: 12345',
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
                      onPressed: _isSaving ? null : _simpanForm, // ✅ Disable saat saving
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSaving ? Colors.grey.shade400 : Colors.blue.shade700, // ✅ Ubah warna
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
                              'Selesai',
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