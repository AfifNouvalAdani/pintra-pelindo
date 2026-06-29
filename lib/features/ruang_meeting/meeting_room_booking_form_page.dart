import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'detail_peminjaman_ruang_meeting_page.dart';
import '../services/meeting_room_auto_complete_service.dart';
import '../services/approval_notification_service.dart';

// ──────────────────────────────────────────────────────────────
// Custom Time Picker 24 Jam (sama persis dengan form kendaraan)
// ──────────────────────────────────────────────────────────────
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Container(
        padding: const EdgeInsets.only(bottom: 8),
        child: const Text(
          'Pilih Jam',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      content: SizedBox(
        height: 200,
        width: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(0, 15),
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Jam
                  Expanded(
                    child: SizedBox(
                      height: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Jam',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: _hourController,
                              itemExtent: 50,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (_) =>
                                  HapticFeedback.selectionClick(),
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) {
                                  final isSelected =
                                      index == _hourController.selectedItem;
                                  return Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      _hours[index].toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? Colors.blue.shade700
                                            : Colors.grey.shade700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  );
                                },
                                childCount: _hours.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, 10),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  // Menit
                  Expanded(
                    child: SizedBox(
                      height: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Menit',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: _minuteController,
                              itemExtent: 50,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (_) =>
                                  HapticFeedback.selectionClick(),
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) {
                                  final isSelected =
                                      index == _minuteController.selectedItem;
                                  return Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      _minutes[index].toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? Colors.blue.shade700
                                            : Colors.grey.shade700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  );
                                },
                                childCount: _minutes.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  final selectedHour = _hours[_hourController.selectedItem];
                  final selectedMinute = _minutes[_minuteController.selectedItem];
                  widget.onTimeSelected(
                    TimeOfDay(hour: selectedHour, minute: selectedMinute),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Pilih',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
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

// ──────────────────────────────────────────────────────────────
// Halaman Form Peminjaman Ruang Meeting (dengan TimePicker24Hour)
// ──────────────────────────────────────────────────────────────
class MeetingRoomBookingFormPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const MeetingRoomBookingFormPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<MeetingRoomBookingFormPage> createState() =>
      _MeetingRoomBookingFormPageState();
}

class _MeetingRoomBookingFormPageState
    extends State<MeetingRoomBookingFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _namaKegiatanController = TextEditingController();
  final _pesertaController = TextEditingController();

  // State fields
  String _jenisRapat = 'OFFLINE';
  List<String> _konsumsiSelected = [];
  final _layoutController = TextEditingController();
  final _konsumsiNoteController = TextEditingController();

  // Waktu peminjaman (pisah date + time seperti form kendaraan)
  DateTime? _tglMulai;
  TimeOfDay? _jamMulai;
  DateTime? _tglSelesai;
  TimeOfDay? _jamSelesai;

  Map<String, dynamic>? _selectedRoom;
  List<Map<String, dynamic>> _availableRooms = [];
  bool _isLoadingRooms = false;
  bool _isSubmitting = false;
  bool _hasCheckedAvailability = false;

  Map<String, dynamic>? _userData;

  final List<String> _konsumsiOptions = [
    'NASI',
    'SNACK',
    'MINUMAN',
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _fetchUserData();
    MeetingRoomAutoCompleteService.checkAndCompleteExpiredBookings();
  }

  @override
  void dispose() {
    _namaKegiatanController.dispose();
    _pesertaController.dispose();
    _layoutController.dispose();
    _konsumsiNoteController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  String _getInitialStatus() {
    final role = widget.role;
    final jabatan = (_userData?['jabatan'] ?? '').toString().toLowerCase();

    if (role == 'admin' || role == 'manager_umum') {
      return 'APPROVAL_3';
    } else if (role == 'operator') {
      return 'APPROVAL_2';
    } else if (role == 'user' && jabatan.contains('manager')) {
      return 'APPROVAL_1';
    } else {
      return 'SUBMITTED';
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Date & Time Pickers (sama persis dengan form kendaraan)
  // ──────────────────────────────────────────────────────────────
  Future<void> _pickDate(bool isMulai) async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: isMulai ? now : (_tglMulai ?? now),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue.shade700,
            colorScheme: ColorScheme.light(primary: Colors.blue.shade700),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() {
        if (isMulai) {
          _tglMulai = result;
          // Reset waktu selesai jika tanggal mulai berubah
          if (_tglSelesai != null && _tglSelesai!.isBefore(_tglMulai!)) {
            _tglSelesai = null;
            _jamSelesai = null;
          }
        } else {
          _tglSelesai = result;
        }
        // Reset ketersediaan
        _selectedRoom = null;
        _availableRooms = [];
        _hasCheckedAvailability = false;
      });
    }
  }

  Future<void> _pickTime(bool isMulai) async {
    final currentTime = isMulai ? _jamMulai : _jamSelesai;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        HapticFeedback.lightImpact();
        return TimePicker24Hour(
          initialTime: currentTime ?? const TimeOfDay(hour: 8, minute: 0),
          onTimeSelected: (selectedTime) {
            setState(() {
              if (isMulai) {
                _jamMulai = selectedTime;
              } else {
                _jamSelesai = selectedTime;
              }
              // Reset ketersediaan
              _selectedRoom = null;
              _availableRooms = [];
              _hasCheckedAvailability = false;
            });
          },
        );
      },
    );
  }

  DateTime? get _waktuMulai {
    if (_tglMulai == null || _jamMulai == null) return null;
    return DateTime(
      _tglMulai!.year,
      _tglMulai!.month,
      _tglMulai!.day,
      _jamMulai!.hour,
      _jamMulai!.minute,
    );
  }

  DateTime? get _waktuSelesai {
    if (_tglSelesai == null || _jamSelesai == null) return null;
    return DateTime(
      _tglSelesai!.year,
      _tglSelesai!.month,
      _tglSelesai!.day,
      _jamSelesai!.hour,
      _jamSelesai!.minute,
    );
  }

  String formatDate(DateTime? d) =>
      d == null ? '-' : DateFormat('dd MMM yyyy', 'id_ID').format(d);
  String formatTime(TimeOfDay? t) =>
      t == null ? '-' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Future<void> _checkRoomAvailability() async {
  final waktuMulai = _waktuMulai;
  final waktuSelesai = _waktuSelesai;
  if (waktuMulai == null || waktuSelesai == null) {
    _showSnackBar('Pilih tanggal dan jam mulai serta selesai terlebih dahulu',
        Colors.orange);
    return;
  }

  if (waktuSelesai.isBefore(waktuMulai)) {
    _showSnackBar('Waktu selesai harus setelah waktu mulai', Colors.red);
    return;
  }

  setState(() {
    _isLoadingRooms = true;
    _selectedRoom = null;
    _availableRooms = [];
  });

  try {
    await MeetingRoomAutoCompleteService.checkAndCompleteExpiredBookings();

    final roomsSnapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .where('status', isEqualTo: 'available')
        .get();

    final allRooms = roomsSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    // Filter kapasitas & kompatibilitas jenis rapat
    final jumlahPeserta = int.tryParse(_pesertaController.text.trim()) ?? 0;

    final List<Map<String, dynamic>> filteredRooms = allRooms.where((room) {
      final kapasitasRaw = room['kapasitas'];
      final kapasitas = kapasitasRaw is num
    ? kapasitasRaw.toInt()
    : int.tryParse(kapasitasRaw?.toString() ?? '') ?? 0;
      final tipeRuang = (room['tipe'] as String? ?? '').toUpperCase();

      // Filter kapasitas
      if (jumlahPeserta > 0 && kapasitas < jumlahPeserta) return false;

      // Filter kompatibilitas jenis rapat
      if (_jenisRapat == 'ONLINE' || _jenisRapat == 'HYBRID') {
        if (tipeRuang == 'OFFLINE') return false;
      }

      return true;
    }).toList();

    if (filteredRooms.isEmpty) {
      setState(() {
        _availableRooms = [];
        _isLoadingRooms = false;
        _hasCheckedAvailability = true;
      });

      final pesertaMsg = jumlahPeserta > 0
          ? ' dengan kapasitas ≥ $jumlahPeserta orang'
          : '';
      final rapatMsg = (_jenisRapat == 'ONLINE' || _jenisRapat == 'HYBRID')
          ? ' dan mendukung rapat $_jenisRapat'
          : '';
      _showSnackBar(
        'Tidak ada ruang tersedia$pesertaMsg$rapatMsg.',
        Colors.orange,
      );
      return;
    }

    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('room_bookings')
        .where('status', whereIn: [
      'SUBMITTED',
      'APPROVAL_1',
      'APPROVAL_2',
      'APPROVAL_3',
    ]).get();

    final Map<String, String> conflictedRooms = {};

    for (final doc in bookingsSnapshot.docs) {
      final data = doc.data();
      final bookingMulai = (data['waktuMulai'] as Timestamp?)?.toDate();
      final bookingSelesaiRaw = (data['waktuSelesai'] as Timestamp?)?.toDate();
      final roomId = data['ruang']?['roomId'] as String?;
      if (bookingMulai == null || bookingSelesaiRaw == null || roomId == null)
        continue;

      final bookingSelesaiEfektif =
          MeetingRoomAutoCompleteService.effectiveEndTime(bookingSelesaiRaw);

      final isConflict = waktuMulai.isBefore(bookingSelesaiEfektif) &&
          waktuSelesai.isAfter(bookingMulai);

      if (isConflict && !conflictedRooms.containsKey(roomId)) {
        final isCleaningConflict =
            waktuMulai.isAfter(bookingSelesaiRaw) ||
                waktuMulai.isAtSameMomentAs(bookingSelesaiRaw);
        final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};
        final namaPeminjam = peminjam['nama'] ?? '-';
        final fmtTime = (DateTime? dt) => dt != null
            ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : '-';

        if (isCleaningConflict) {
          conflictedRooms[roomId] =
              'Sedang dibersihkan s/d ${fmtTime(bookingSelesaiEfektif)}';
        } else {
          conflictedRooms[roomId] =
              'Dipesan $namaPeminjam ${fmtTime(bookingMulai)}–${fmtTime(bookingSelesaiRaw)}';
        }
      }
    }

    final List<Map<String, dynamic>> available = [];
    final List<Map<String, dynamic>> unavailable = [];

    for (final room in filteredRooms) {
      final roomId = room['id'] as String;
      if (conflictedRooms.containsKey(roomId)) {
        unavailable.add({
          ...room,
          '_isUnavailable': true,
          '_unavailableReason': conflictedRooms[roomId],
        });
      } else {
        available.add({...room, '_isUnavailable': false});
      }
    }

    final combined = [...available, ...unavailable];

    setState(() {
      _availableRooms = combined;
      _isLoadingRooms = false;
      _hasCheckedAvailability = true;
    });

    if (available.isEmpty) {
      _showSnackBar(
        'Tidak ada ruang tersedia di waktu yang dipilih. '
        'Semua ruang sedang dipakai atau dalam pembersihan.',
        Colors.orange,
      );
    }
  } catch (e) {
    debugPrint('Error checking availability: $e');
    setState(() => _isLoadingRooms = false);
    _showSnackBar('Gagal memeriksa ketersediaan ruang', Colors.red);
  }
}

Future<void> _submitBooking() async {
  if (!_formKey.currentState!.validate()) return;

  final waktuMulai = _waktuMulai;
  final waktuSelesai = _waktuSelesai;
  if (waktuMulai == null || waktuSelesai == null) {
    _showSnackBar('Pilih tanggal dan jam mulai serta selesai', Colors.orange);
    return;
  }

  if (_selectedRoom == null) {
    _showSnackBar('Pilih ruang meeting terlebih dahulu', Colors.orange);
    return;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Konfirmasi Peminjaman'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _confirmRow('Kegiatan', _namaKegiatanController.text),
          _confirmRow('Ruang', _selectedRoom!['namaRuang'] ?? '-'),
          _confirmRow('Jenis Rapat', _jenisRapat),
          _confirmRow(
            'Waktu',
            '${_formatDateTime(waktuMulai)} s/d ${_formatDateTime(waktuSelesai)}',
          ),
          _confirmRow('Peserta', '${_pesertaController.text} orang'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Konfirmasi'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  setState(() => _isSubmitting = true);

  try {
    final userData = _userData ?? {};
    final now = Timestamp.now();
    final initialStatus = _getInitialStatus();

    // ✅ FIX 1: namaRuang & lokasi disimpan lengkap di bookingData
    final bookingData = {
      'namaKegiatan': _namaKegiatanController.text.trim(),
      'jenisRapat': _jenisRapat,
      'layoutRuangan': _layoutController.text.trim(),
      'konsumsi': _konsumsiSelected,
      'konsumsiNote': _konsumsiNoteController.text.trim(),
      'peserta': _pesertaController.text.trim(),
      'waktuMulai': Timestamp.fromDate(waktuMulai),
      'waktuSelesai': Timestamp.fromDate(waktuSelesai),
      'ruang': {
        'roomId': _selectedRoom!['id'],
        'namaRuang': _selectedRoom!['namaRuang'] ?? '-',   // ✅ tambahan
        'lokasi': _selectedRoom!['lokasi'] ?? '-',          // ✅ tambahan
      },
      // ✅ FIX 2: root-level field untuk kemudahan akses di service notifikasi
      'namaRuang': _selectedRoom!['namaRuang'] ?? '-',
      'lokasiRuang': _selectedRoom!['lokasi'] ?? '-',
      'peminjam': {
        'userId': widget.userId,
        'nama': widget.userName,
        'divisi': widget.userDivision,
        'jabatan': userData['jabatan'] ?? 'Staff',
        'email': userData['email'] ?? '',
        'nipp': userData['nipp'] ?? widget.userId,
        'role': widget.role,
      },
      'status': initialStatus,
      'approval': {'manager': null, 'operator': null, 'admin': null},
      'createdAt': now,
      'updatedAt': now,
    };

    // ✅ FIX 3: gunakan await + docRef terpisah agar id tersedia sebelum notif dikirim
    final docRef = await FirebaseFirestore.instance
        .collection('room_bookings')
        .add(bookingData);

    if (!mounted) return;

    // ✅ FIX 4: bookingData lengkap dengan id untuk dikirim ke service notifikasi
    final bookingDataWithId = {'id': docRef.id, ...bookingData};

    // ✅ FIX 5: panggil notifikasi WA setelah booking tersimpan
    _sendNotificationByStatus(
      bookingId: docRef.id,
      bookingData: bookingDataWithId,
      status: initialStatus,
    );

    _showSnackBar(_getStatusMessage(initialStatus), Colors.green);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPeminjamanRuangMeetingPage(
          data: bookingDataWithId,
          role: widget.role,
          userName: widget.userName,
          userId: widget.userId,
          userDivision: widget.userDivision,
          isApprovalMode: false,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error submitting booking: $e');
    _showSnackBar('Gagal mengajukan peminjaman: $e', Colors.red);
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}

void _sendNotificationByStatus({
  required String bookingId,
  required Map<String, dynamic> bookingData,
  required String status,
}) {
  switch (status) {
    case 'SUBMITTED':
      // Role: user biasa → notif ke Manager Divisi
      ApprovalNotificationService.sendRoomApprovalNotificationToManagerDivisi(
        bookingId: bookingId,
        bookingData: bookingData,
      );
      break;
    case 'APPROVAL_1':
      // Role: user dengan jabatan manager → notif ke Operator ruang meeting
      ApprovalNotificationService.sendRoomApprovalNotificationToOperator(
        bookingId: bookingId,
        bookingData: bookingData,
      );
      break;
    case 'APPROVAL_2':
      // Role: operator → notif ke Manager Umum / Admin
      ApprovalNotificationService.sendRoomApprovalNotificationToManagerUmum(
        bookingId: bookingId,
        bookingData: bookingData,
      );
      break;
    case 'APPROVAL_3':
      // Role: admin / manager_umum → langsung approved, notif ke peminjam
      ApprovalNotificationService.sendRoomApprovedNotificationToPeminjam(
        bookingId: bookingId,
        bookingData: bookingData,
      );
      break;
    default:
      debugPrint('⚠️ Status tidak dikenali untuk notifikasi: $status');
  }
}

  String _getStatusMessage(String initialStatus) {
    switch (initialStatus) {
      case 'APPROVAL_3':
        return 'Peminjaman berhasil diajukan dan langsung disetujui!';
      case 'APPROVAL_2':
        return 'Peminjaman berhasil diajukan, menunggu persetujuan Manager Umum';
      case 'APPROVAL_1':
        return 'Peminjaman berhasil diajukan, menunggu verifikasi Operator';
      default:
        return 'Peminjaman berhasil diajukan!';
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  Widget _confirmRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  // ──────────────────────────────────────────────────────────────
  // Widget UI (sama persis dengan form kendaraan untuk bagian waktu)
  // ──────────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title, IconData icon) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      );

  Widget _buildCard({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator ??
          (val) =>
              (val == null || val.trim().isEmpty) ? '$label tidak boleh kosong' : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  // Widget untuk row date + time (sama persis dengan form kendaraan)
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
        Expanded(child: _pickerBox(label1, value1, onTap1, isTime: label1.contains('Jam'))),
        const SizedBox(width: 12),
        Expanded(child: _pickerBox(label2, value2, onTap2, isTime: label2.contains('Jam'))),
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
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
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

  Widget _buildJenisRapatSelector() {
    final options = ['OFFLINE', 'ONLINE', 'HYBRID'];
    final labels = {'OFFLINE': 'Offline', 'ONLINE': 'Online', 'HYBRID': 'Hybrid'};
    final icons = {'OFFLINE': Icons.people, 'ONLINE': Icons.videocam, 'HYBRID': Icons.devices};

    return Row(
      children: options.map((opt) {
        final isSelected = _jenisRapat == opt;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _jenisRapat = opt),
            child: Container(
              margin: EdgeInsets.only(right: opt != 'HYBRID' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Icon(icons[opt]!, size: 20,
                      color: isSelected ? Colors.white : Colors.grey.shade500),
                  const SizedBox(height: 4),
                  Text(labels[opt]!,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

    Widget _buildLayoutField() {
      return TextFormField(
        controller: _layoutController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Layout Ruangan',
          hintText: 'Contoh: Meja U-shape untuk 20 orang, proyektor di depan...',
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      );
    }

  Widget _buildKonsumsiCheckboxes() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _konsumsiOptions.map((option) {
        final isSelected = _konsumsiSelected.contains(option);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected)
                _konsumsiSelected.remove(option);
              else
                _konsumsiSelected.add(option);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? Colors.orange.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected ? Colors.orange.shade400 : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: isSelected ? Colors.orange.shade600 : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Text(option,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.orange.shade700 : Colors.grey.shade600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final isUnavailable = room['_isUnavailable'] == true;
    final unavailableReason = room['_unavailableReason'] as String? ?? '';
    final isSelected = _selectedRoom?['id'] == room['id'];

    return GestureDetector(
      onTap: isUnavailable
          ? () => _showSnackBar('🧹 Ruang tidak tersedia: $unavailableReason', Colors.orange)
          : () => setState(() => _selectedRoom = room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnavailable
              ? Colors.grey.shade100
              : isSelected
                  ? Colors.teal.shade50
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnavailable
                ? Colors.grey.shade300
                : isSelected
                    ? Colors.teal.shade400
                    : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isUnavailable
              ? []
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Opacity(
          opacity: isUnavailable ? 0.55 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.meeting_room_outlined, size: 20,
                      color: isUnavailable ? Colors.grey : Colors.teal.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(room['namaRuang'] ?? 'Ruang Meeting',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isUnavailable ? Colors.grey.shade500 : Colors.grey.shade900)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUnavailable ? Colors.orange.shade50 : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isUnavailable ? Colors.orange.shade200 : Colors.teal.shade200),
                    ),
                    child: Text(isUnavailable ? 'Tidak Tersedia' : 'Tersedia',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isUnavailable ? Colors.orange.shade700 : Colors.teal.shade700)),
                  ),
                  if (isSelected && !isUnavailable) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle_rounded, color: Colors.teal.shade600, size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _roomInfoChip(Icons.location_on_outlined, room['lokasi'] ?? '-'),
                  const SizedBox(width: 8),
                  _roomInfoChip(Icons.people_outline, '${room['kapasitas'] ?? '-'} orang'),
                  const SizedBox(width: 8),
                  _roomInfoChip(Icons.category_outlined, room['tipe'] ?? '-'),
                ],
              ),
              if ((room['fasilitas'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (room['fasilitas'] as List).take(4).map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Text(f.toString(),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      )).toList(),
                ),
              ],
              if (isUnavailable) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200)),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(unavailableReason,
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _roomInfoChip(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 10),
          Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: Colors.grey.shade800,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Peminjaman Ruang Meeting',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Peminjam
              _buildSectionTitle('Informasi Peminjam', Icons.person_outline),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    _infoRow(Icons.person, 'Nama', widget.userName),
                    const Divider(height: 16),
                    _infoRow(Icons.business, 'Divisi', widget.userDivision),
                    const Divider(height: 16),
                    _infoRow(Icons.badge_outlined, 'Jabatan',
                        _userData?['jabatan'] ?? 'Staff'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Detail Kegiatan
              _buildSectionTitle('Detail Kegiatan', Icons.event_note_outlined),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    _buildTextField(
                        controller: _namaKegiatanController,
                        label: 'Nama Kegiatan',
                        hint: 'Contoh: Rapat Koordinasi Bulanan'),
                    const SizedBox(height: 14),
                    _buildTextField(
                        controller: _pesertaController,
                        label: 'Jumlah Peserta',
                        hint: 'Contoh: 20',
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Jumlah peserta tidak boleh kosong';
                          final n = int.tryParse(val.trim());
                          if (n == null || n <= 0) return 'Masukkan angka yang valid';
                          return null;
                        }),
                    const SizedBox(height: 16),
                    Text('Jenis Rapat',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    _buildJenisRapatSelector(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pilih Ruang & Waktu (dengan layout row date+time seperti kendaraan)
              _buildSectionTitle('Pilih Ruang & Waktu', Icons.meeting_room_outlined),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    // Row untuk Tanggal Mulai & Jam Mulai
                    _dateTimeRow(
                      'Tanggal Mulai',
                      formatDate(_tglMulai),
                      () => _pickDate(true),
                      'Jam Mulai',
                      formatTime(_jamMulai),
                      () => _pickTime(true),
                    ),
                    const SizedBox(height: 16),
                    // Row untuk Tanggal Selesai & Jam Selesai
                    _dateTimeRow(
                      'Tanggal Selesai',
                      formatDate(_tglSelesai),
                      () => _pickDate(false),
                      'Jam Selesai',
                      formatTime(_jamSelesai),
                      () => _pickTime(false),
                    ),
                    const SizedBox(height: 14),
                    // Tombol Cek Ketersediaan
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_waktuMulai != null && _waktuSelesai != null && !_isLoadingRooms)
                            ? _checkRoomAvailability
                            : null,
                        icon: _isLoadingRooms
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.blue.shade700),
                              )
                            : const Icon(Icons.search, size: 18),
                        label: Text(_isLoadingRooms ? 'Memeriksa...' : 'Cek Ketersediaan Ruang',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_hasCheckedAvailability) ...[
                      const SizedBox(height: 14),
                      if (_availableRooms.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200)),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.red.shade400, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      'Tidak ada ruang yang tersedia di waktu tersebut. Coba pilih waktu lain.',
                                      style: TextStyle(
                                          fontSize: 13, color: Colors.red.shade700))),
                            ],
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: Colors.green.shade600, size: 16),
                            const SizedBox(width: 6),
                            Text('${_availableRooms.length} ruang tersedia',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade700)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._availableRooms.map(_buildRoomCard).toList(),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Fasilitas Tambahan
              _buildSectionTitle('Fasilitas Tambahan', Icons.room_service_outlined),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Konsumsi',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 10),
                    _buildKonsumsiCheckboxes(),
                    if (_konsumsiSelected.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Tidak ada konsumsi (opsional)',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _konsumsiNoteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan Konsumsi',
                        hintText: 'Contoh: Nasi kotak ayam bakar, snack ringan, air mineral...',
                        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Layout Ruangan',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 10),
                    _buildLayoutField(),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.blue.shade200,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Ajukan Peminjaman',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}