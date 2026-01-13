import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../dashboard/dashboard_page.dart';
import '../vehicle/detail_peminjaman_page.dart';

class VehicleBookingFormPage extends StatefulWidget {
  const VehicleBookingFormPage({super.key});

  @override
  State<VehicleBookingFormPage> createState() =>
      _VehicleBookingFormPageState();
}

class _VehicleBookingFormPageState extends State<VehicleBookingFormPage> {
  String? keperluan;
  String? kendaraan;

  final TextEditingController nomorController = TextEditingController();
  final TextEditingController kegiatanController = TextEditingController();
  final TextEditingController tujuanController = TextEditingController();

  DateTime? tglPinjam;
  TimeOfDay? jamPinjam;
  DateTime? tglKembali;
  TimeOfDay? jamKembali;

  Future<void> pickDate(bool isPinjam) async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue.shade700,
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
            ),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() {
        if (isPinjam) {
          tglPinjam = result;
        } else {
          tglKembali = result;
        }
      });
    }
  }

  Future<void> pickTime(bool isPinjam) async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue.shade700,
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() {
        if (isPinjam) {
          jamPinjam = result;
        } else {
          jamKembali = result;
        }
      });
    }
  }

  void _submitForm() {
  // Validasi form
  if (keperluan == null) {
    _showSnackBar('Pilih keperluan peminjaman');
    return;
  }

  if (tglPinjam == null || jamPinjam == null) {
    _showSnackBar('Pilih tanggal dan jam pinjam');
    return;
  }

  if (tglKembali == null || jamKembali == null) {
    _showSnackBar('Pilih tanggal dan jam kembali');
    return;
  }

  if (tujuanController.text.isEmpty) {
    _showSnackBar('Masukkan tujuan lokasi');
    return;
  }

  if (kendaraan == null) {
    _showSnackBar('Pilih kendaraan');
    return;
  }

  // Siapkan data untuk halaman detail
  final data = {
    'nama': 'Tono', // nanti ambil dari user login
    'nipp': '103884',
    'divisi': 'Teknologi Informasi',
    'keperluan': keperluan!,
    'nomor': keperluan == 'Lainnya'
        ? kegiatanController.text
        : nomorController.text,
    'tujuan': tujuanController.text,
    'tglPinjam': DateFormat('dd MMMM yyyy').format(tglPinjam!),
    'jamPinjam': jamPinjam!.format(context),
    'tglKembali': DateFormat('dd MMMM yyyy').format(tglKembali!),
    'jamKembali': jamKembali!.format(context),
    'kendaraan': kendaraan!,
  };

  // Pindah ke halaman Detail Peminjaman
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DetailPeminjamanPage(
        data: data,
        approvalStep: 0, // baru diajukan
      ),
    ),
  );
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


  @override
  Widget build(BuildContext context) {
    String formatDate(DateTime? d) =>
        d == null ? '-' : DateFormat('dd MMM yyyy').format(d);
    String formatTime(TimeOfDay? t) =>
        t == null ? '-' : t.format(context);

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
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DashboardPage(
                role: 'user', // Ganti dengan role yang sesuai
                userName: 'User', // Ganti dengan nama user yang sesuai
              )),
            );
          },
        ),
        title: Text(
          'Peminjaman Kendaraan',
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
              // Header Info
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
                        'Pastikan semua data diisi dengan benar. Pengajuan akan diproses maksimal 2x24 jam.',
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

              // Keperluan Peminjaman
              Text(
                'Keperluan Peminjaman',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: keperluan,
                items: const [
                  DropdownMenuItem(value: 'Dinas', child: Text('Dinas (SPPD)')),
                  DropdownMenuItem(value: 'Undangan', child: Text('Undangan')),
                  DropdownMenuItem(
                      value: 'Lainnya', child: Text('Kegiatan Lainnya')),
                ],
                onChanged: (v) => setState(() => keperluan = v),
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
                icon: Icon(Icons.keyboard_arrow_down_rounded, 
                  color: Colors.grey.shade500),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                ),
              ),

              const SizedBox(height: 20),

              // Nomor SPPD / Nama Kegiatan
              if (keperluan == 'Dinas' || keperluan == 'Undangan')
                TextFormField(
                  controller: nomorController,
                  decoration: InputDecoration(
                    labelText: 'Nomor SPPD / Undangan',
                    labelStyle: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                    floatingLabelStyle: TextStyle(
                      color: Colors.blue.shade700,
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

              if (keperluan == 'Lainnya')
                TextFormField(
                  controller: kegiatanController,
                  decoration: InputDecoration(
                    labelText: 'Nama Kegiatan',
                    labelStyle: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                    floatingLabelStyle: TextStyle(
                      color: Colors.blue.shade700,
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

              if (keperluan != null) const SizedBox(height: 20),

              // Waktu Peminjaman
              Text(
                'Waktu Peminjaman',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),

              _dateTimeRow(
                'Tanggal Pinjam',
                formatDate(tglPinjam),
                () => pickDate(true),
                'Jam Pinjam',
                formatTime(jamPinjam),
                () => pickTime(true),
              ),

              const SizedBox(height: 16),

              _dateTimeRow(
                'Tanggal Kembali',
                formatDate(tglKembali),
                () => pickDate(false),
                'Jam Kembali',
                formatTime(jamKembali),
                () => pickTime(false),
              ),

              const SizedBox(height: 20),

              // Tujuan Lokasi
              TextFormField(
                controller: tujuanController,
                decoration: InputDecoration(
                  labelText: 'Tujuan Lokasi',
                  labelStyle: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: Colors.blue.shade700,
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
                maxLines: 2,
              ),

              const SizedBox(height: 20),

              // Pilih Kendaraan
              Text(
                'Pilih Kendaraan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: kendaraan,
                items: const [
                  DropdownMenuItem(value: 'Xenia Putih', child: Text('Xenia Putih')),
                  DropdownMenuItem(value: 'Avanza Hitam', child: Text('Avanza Hitam')),
                  DropdownMenuItem(value: 'Innova Abu', child: Text('Innova Abu')),
                ],
                onChanged: (v) => setState(() => kendaraan = v),
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
                icon: Icon(Icons.keyboard_arrow_down_rounded, 
                  color: Colors.grey.shade500),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                ),
              ),

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Ajukan Peminjaman',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => DashboardPage(
                        role: 'user',
                        userName: 'User',
                      )),
                    );
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

  Widget _dateTimeRow(
    String label1,
    String value1,
    VoidCallback onTap1,
    String label2,
    String value2,
    VoidCallback onTap2,
  ) {
    return Row(
      children: [
        Expanded(
          child: _pickerBox(label1, value1, onTap1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pickerBox(label2, value2, onTap2),
        ),
      ],
    );
  }

  Widget _pickerBox(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}