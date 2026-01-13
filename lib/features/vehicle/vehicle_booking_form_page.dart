import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../dashboard/dashboard_page.dart';
import '../vehicle/detail_peminjaman_page.dart';

// Custom Time Picker 24 Jam
class TimePicker24Hour extends StatefulWidget {
  final TimeOfDay? initialTime;
  final Function(TimeOfDay) onTimeSelected;

  const TimePicker24Hour({
    Key? key,
    this.initialTime,
    required this.onTimeSelected,
  }) : super(key: key);

  @override
  _TimePicker24HourState createState() => _TimePicker24HourState();
}

class _TimePicker24HourState extends State<TimePicker24Hour> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  
  final List<int> _hours = List.generate(24, (index) => index);
  final List<int> _minutes = List.generate(60, (index) => index);

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(
      initialItem: widget.initialTime?.hour ?? 8,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: widget.initialTime?.minute ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Jam'),
      content: Container(
        height: 200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Jam picker
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Jam',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListWheelScrollView(
                      controller: _hourController,
                      itemExtent: 50,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (_) {},
                      children: _hours.map((hour) {
                        return Center(
                          child: Text(
                            hour.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            
            // Menit picker
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Menit',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListWheelScrollView(
                      controller: _minuteController,
                      itemExtent: 50,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (_) {},
                      children: _minutes.map((minute) {
                        return Center(
                          child: Text(
                            minute.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final selectedHour = _hours[_hourController.selectedItem];
            final selectedMinute = _minutes[_minuteController.selectedItem];
            widget.onTimeSelected(TimeOfDay(
              hour: selectedHour,
              minute: selectedMinute,
            ));
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
          ),
          child: const Text('Pilih'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }
}

// Halaman Form Peminjaman
class VehicleBookingFormPage extends StatefulWidget {
  final String role;
  final String userName;

  const VehicleBookingFormPage({
    super.key,
    required this.role,
    required this.userName,
  });

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

  // Fungsi untuk memilih tanggal
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

  // Fungsi untuk memilih waktu (menggunakan custom picker)
  Future<void> pickTime(bool isPinjam) async {
    final currentTime = isPinjam ? jamPinjam : jamKembali;
    
    showDialog(
      context: context,
      builder: (context) => TimePicker24Hour(
        initialTime: currentTime ?? TimeOfDay.now(),
        onTimeSelected: (selectedTime) {
          setState(() {
            if (isPinjam) {
              jamPinjam = selectedTime;
            } else {
              jamKembali = selectedTime;
            }
          });
        },
      ),
    );
  }

  // Fungsi format tanggal
  String formatDate(DateTime? d) =>
      d == null ? '-' : DateFormat('dd MMM yyyy').format(d);

  // Fungsi format waktu 24 jam
  String formatTime(TimeOfDay? t) {
    if (t == null) return '-';
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Fungsi submit form
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
      'jamPinjam': formatTime(jamPinjam!),
      'tglKembali': DateFormat('dd MMMM yyyy').format(tglKembali!),
      'jamKembali': formatTime(jamKembali!),
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
              MaterialPageRoute(
                builder: (context) => DashboardPage(
                  role: widget.role,
                  userName: widget.userName,
                ),
              ),
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
                      MaterialPageRoute(
                        builder: (context) => DashboardPage(
                          role: widget.role,
                          userName: widget.userName,
                        ),
                      ),
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
          child: _pickerBox(label1, value1, onTap1, isTime: label1.contains('Jam')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pickerBox(label2, value2, onTap2, isTime: label2.contains('Jam')),
        ),
      ],
    );
  }

  Widget _pickerBox(String label, String value, VoidCallback onTap, {bool isTime = false}) {
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
                  isTime ? Icons.access_time_rounded : Icons.calendar_today_outlined,
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