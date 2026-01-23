import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../dashboard/dashboard_page.dart';
import '../vehicle/detail_peminjaman_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String userId;
  final String userDivision; // ✅ TAMBAHKAN

  const VehicleBookingFormPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision, // ✅
  });

  @override
  State<VehicleBookingFormPage> createState() =>
      _VehicleBookingFormPageState();
}

class _VehicleBookingFormPageState extends State<VehicleBookingFormPage> {
  String? keperluan;
  String? kendaraanId;
  Map<String, dynamic>? selectedVehicle;
  
  final TextEditingController nomorController = TextEditingController();
  final TextEditingController kegiatanController = TextEditingController();
  final TextEditingController tujuanController = TextEditingController();

  DateTime? tglPinjam;
  TimeOfDay? jamPinjam;
  DateTime? tglKembali;
  TimeOfDay? jamKembali;

  bool _isLoading = true;
  List<Map<String, dynamic>> _availableVehicles = [];
  List<Map<String, dynamic>> _userBookings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load data dari Firestore
  Future<void> _loadData() async {
    try {
      // 1. Cek apakah user sudah punya booking aktif
      await _checkExistingBookings();
      
      // 2. Load kendaraan yang tersedia
      await _loadAvailableVehicles();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading data: $e');
    }
  }

  // Cek apakah user sudah punya booking aktif
Future<void> _checkExistingBookings() async {
  try {
    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .where('peminjamId', isEqualTo: widget.userId)
        .get();

    // Filter booking yang masih aktif (belum selesai/dibatalkan)
    final activeBookings = bookingsSnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      return ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'ON_GOING'].contains(status);
    }).toList();

    if (activeBookings.isNotEmpty) {
      _userBookings = activeBookings.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    }
  } catch (e) {
    print('Error checking existing bookings: $e');
  }
}

  // Load kendaraan yang tersedia (status aktif dan tidak sedang dipinjam)
  Future<void> _loadAvailableVehicles() async {
    try {
      // 1. Ambil semua kendaraan aktif
      final vehiclesSnapshot = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('statusAktif', isEqualTo: true)
          .get();

      // 2. ✅ PERBAIKAN: Ambil kendaraan yang sedang dipinjam ATAU menunggu approval
      final activeBookingsSnapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', whereIn: [
            'APPROVAL_2',  // ✅ Tambahkan ini
            'APPROVAL_3',  // ✅ Tambahkan ini
            'ON_GOING'     // ✅ Tetap ada
          ])
          .get();

      final bookedVehicleIds = activeBookingsSnapshot.docs
          .map((doc) => doc.data()['vehicleId'] as String?)
          .where((id) => id != null)
          .toList();

      print('🚗 Total kendaraan aktif: ${vehiclesSnapshot.docs.length}');
      print('🔴 Kendaraan yang sudah dibooking/digunakan: ${bookedVehicleIds.length}');
      print('🔴 IDs: $bookedVehicleIds');

      // 3. Filter kendaraan yang tidak sedang dipinjam/dibooking
      final availableVehicles = vehiclesSnapshot.docs
          .where((doc) => !bookedVehicleIds.contains(doc.id))
          .map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nama': data['nama'] ?? 'Tanpa Nama',
          'platNomor': data['platNomor'] ?? '-',
          'jenis': data['jenis'] ?? 'Mobil',
          'tahun': data['tahun'] ?? '-',
          'kursi': data['kursi'] ?? '0',
          'bbm': data['bbm'] ?? '-',
          'transmisi': data['transmisi'] ?? '-',
          'kelengkapan': (data['kelengkapan'] as List?) ?? [],
          'odometerTerakhir': data['odometerTerakhir'] ?? 0,
        };
      }).toList();

      setState(() {
        _availableVehicles = availableVehicles;
      });
    } catch (e) {
      print('Error loading available vehicles: $e');
    }
  }

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

  // Gabungkan tanggal dan waktu menjadi DateTime
  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _submitForm() async {
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

    if (kendaraanId == null) {
      _showSnackBar('Pilih kendaraan');
      return;
    }

    // Validasi tanggal dan waktu
    final waktuPinjam = _combineDateTime(tglPinjam!, jamPinjam!);
    final waktuKembali = _combineDateTime(tglKembali!, jamKembali!);
    
    if (waktuKembali.isBefore(waktuPinjam)) {
      _showSnackBar('Waktu kembali harus setelah waktu pinjam');
      return;
    }

    if (waktuPinjam.isBefore(DateTime.now())) {
      _showSnackBar('Waktu pinjam tidak boleh di masa lalu');
      return;
    }

    try {
      // Ambil data user dari Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final userData = userDoc.data();
      final divisi = userData?['divisi'] ?? '';

      // Buat data booking
      final bookingData = {
        'peminjamId': widget.userId,
        'namaPeminjam': widget.userName,
        'emailPeminjam': userData?['email'] ?? widget.userName,
        'divisi': divisi,
        'keperluan': keperluan!,
        'nomorSurat': keperluan == 'DINAS' ? nomorController.text : '-',
        'alasan': keperluan == 'KEGIATAN_LAIN' ? kegiatanController.text : '-',
        'tujuan': tujuanController.text,
        'waktuPinjam': Timestamp.fromDate(waktuPinjam),
        'waktuKembali': Timestamp.fromDate(waktuKembali),
        'vehicleId': kendaraanId!,
        'vehicle': {
          'jenis': selectedVehicle?['jenis'] ?? 'Mobil',
          'nama': selectedVehicle?['nama'] ?? 'Tanpa Nama',
          'platNomor': selectedVehicle?['platNomor'] ?? '-',
          'tahun': selectedVehicle?['tahun'] ?? '-',
        },
        'status': 'SUBMITTED',
        'createdAt': Timestamp.now(),
      };

      // Simpan ke Firestore
      final bookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .add(bookingData);

      // Prepare data untuk halaman detail
      final uiData = {
        'id': bookingDoc.id,
        'nama': widget.userName,
        'divisi': divisi,
        'keperluan': keperluan!,
        'nomor': keperluan == 'DINAS' ? nomorController.text : '-',
        'alasan': keperluan == 'KEGIATAN_LAIN' ? kegiatanController.text : '-',
        'tujuan': tujuanController.text,
        'tglPinjam': DateFormat('dd MMMM yyyy').format(tglPinjam!),
        'jamPinjam': formatTime(jamPinjam),
        'tglKembali': DateFormat('dd MMMM yyyy').format(tglKembali!),
        'jamKembali': formatTime(jamKembali),
        'kendaraan': selectedVehicle?['nama'] ?? '',
        'platNomor': selectedVehicle?['platNomor'] ?? '',
        'status': 'SUBMITTED',
        'waktuPinjam': waktuPinjam,
        'waktuKembali': waktuKembali,
      };

      // Navigasi ke halaman detail
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPeminjamanPage(
              data: uiData,
              approvalStep: 0,
              role: widget.role,
              userName: widget.userName,
              userId: widget.userId,
              userDivision: widget.userDivision,
            ),
          ),
        );
      }

    } catch (e) {
      _showSnackBar('Gagal menyimpan data: $e');
      print('Error submitting booking: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
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
  }

  // Widget untuk menampilkan dialog kendaraan yang sedang dipinjam
  void _showExistingBookingsDialog() {
    if (_userBookings.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Peminjaman Aktif'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _userBookings.map((booking) {
              final vehicle = booking['vehicle'] as Map<String, dynamic>? ?? {};
              final platNomor = vehicle['platNomor'] ?? 'Tanpa Plat';
              final status = booking['status'] ?? 'UNKNOWN';
              final tujuan = booking['tujuan'] ?? 'Tidak diketahui';
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.car_rental),
                  title: Text('Kendaraan: $platNomor'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $_getStatusLabel(status)'),
                      Text('Tujuan: $tujuan'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Navigasi ke detail booking
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'SUBMITTED':
        return 'Menunggu Persetujuan';
      case 'APPROVAL_1':
        return 'Disetujui Manager Divisi';
      case 'APPROVAL_2':
        return 'Diverifikasi Operator';
      case 'APPROVAL_3':
        return 'Disetujui Manager Umum';
      case 'ON_GOING':
        return 'Sedang Digunakan';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan loading saat mengecek peminjaman
    if (_isLoading) {
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
                    userId: widget.userId,
                    userDivision: widget.userDivision,
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Memuat data...',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Jika user sudah punya booking aktif, tampilkan dialog

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
                  userId: widget.userId,
                  userDivision: widget.userDivision,
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
        actions: [
          if (_userBookings.isNotEmpty)
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_none),
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        _userBookings.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: _showExistingBookingsDialog,
            ),
        ],
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
child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Kendaraan Tersedia: ${_availableVehicles.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pastikan semua data diisi dengan benar. Pengajuan akan diproses maksimal 2x24 jam.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ WARNING ORANGE DIMULAI DI SINI (SEJAJAR DENGAN CONTAINER BIRU)
// ✅ WARNING ORANGE DIMULAI DI SINI
              if (_userBookings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Anda memiliki ${_userBookings.length} peminjaman aktif',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            TextButton(
                              onPressed: _showExistingBookingsDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Lihat detail',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                  DropdownMenuItem(value: 'DINAS', child: Text('Dinas (SPPD)')),
                  DropdownMenuItem(value: 'UNDANGAN', child: Text('Undangan')),
                  DropdownMenuItem(
                    value: 'KEGIATAN_LAIN',
                    child: Text('Kegiatan Lainnya'),
                  ),
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
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade500,
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                ),
              ),

              const SizedBox(height: 20),

              // Nomor SPPD / Nama Kegiatan
              if (keperluan == 'DINAS' || keperluan == 'UNDANGAN')
                TextFormField(
                  controller: nomorController,
                  decoration: InputDecoration(
                    labelText: keperluan == 'DINAS'
                        ? 'Nomor SPPD'
                        : 'Nomor Undangan',
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

              if (keperluan == 'KEGIATAN_LAIN')
                TextFormField(
                  controller: kegiatanController,
                  decoration: InputDecoration(
                    labelText: 'Alasan/Keterangan',
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
                  hintText: 'Contoh: Terminal Petikemas, Solo, dll.',
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
                'Pilih Kendaraan (${_availableVehicles.length} tersedia)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              
              if (_availableVehicles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tidak ada kendaraan tersedia saat ini. Silakan coba lagi nanti.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: kendaraanId,
                  itemHeight: 56,

                  // 🔽 Tampilan SAAT DROPDOWN DIBUKA
                  items: _availableVehicles.map((vehicle) {
                    return DropdownMenuItem<String>(
                      value: vehicle['id'],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${vehicle['nama']} (${vehicle['platNomor']})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${vehicle['tahun']} | ${vehicle['jenis']} | ${vehicle['kursi']} kursi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  // 🔽 Tampilan SAAT SUDAH DIPILIH
                  selectedItemBuilder: (context) {
                    return _availableVehicles.map((vehicle) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${vehicle['nama']} (${vehicle['platNomor']})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList();
                  },

                  onChanged: (value) {
                    setState(() {
                      kendaraanId = value;
                      selectedVehicle = _availableVehicles.firstWhere(
                        (v) => v['id'] == value,
                      );
                    });
                  },

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
                  isExpanded: true,
                ),
              // Detail kendaraan yang dipilih
              if (selectedVehicle != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kendaraan Dipilih',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${selectedVehicle!['nama']} (${selectedVehicle!['platNomor']})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tahun: ${selectedVehicle!['tahun']} | Jenis: ${selectedVehicle!['jenis']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kursi: ${selectedVehicle!['kursi']} | BBM: ${selectedVehicle!['bbm']} | Transmisi: ${selectedVehicle!['transmisi']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if ((selectedVehicle!['kelengkapan'] as List).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Kelengkapan: ${(selectedVehicle!['kelengkapan'] as List).join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _availableVehicles.isEmpty ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _availableVehicles.isEmpty
                        ? Colors.grey.shade400
                        : Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _availableVehicles.isEmpty
                        ? 'Tidak Ada Kendaraan Tersedia'
                        : 'Ajukan Peminjaman',
                    style: const TextStyle(
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
                          userId: widget.userId,
                          userDivision: widget.userDivision,
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
          child: _pickerBox(label1, value1, onTap1,
              isTime: label1.contains('Jam')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pickerBox(label2, value2, onTap2,
              isTime: label2.contains('Jam')),
        ),
      ],
    );
  }

  Widget _pickerBox(String label, String value, VoidCallback onTap,
      {bool isTime = false}) {
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
                  isTime
                      ? Icons.access_time_rounded
                      : Icons.calendar_today_outlined,
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