import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../gym/detail_peminjaman_gym_page.dart';
import '../services/approval_notification_service.dart';

class _TimePicker24Hour extends StatefulWidget {
  final TimeOfDay? initialTime;
  final Function(TimeOfDay) onTimeSelected;

  const _TimePicker24Hour({
    Key? key,
    this.initialTime,
    required this.onTimeSelected,
  }) : super(key: key);

  @override
  _TimePicker24HourState createState() => _TimePicker24HourState();
}

class _TimePicker24HourState extends State<_TimePicker24Hour> {
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
                                      _hours[index]
                                          .toString()
                                          .padLeft(2, '0'),
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
                                      _minutes[index]
                                          .toString()
                                          .padLeft(2, '0'),
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
                  final selectedMinute =
                      _minutes[_minuteController.selectedItem];
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

class GymBookingFormPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const GymBookingFormPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<GymBookingFormPage> createState() => _GymBookingFormPageState();
}

class _GymBookingFormPageState extends State<GymBookingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  // Waktu peminjaman (pisah date + time, sama seperti form ruang meeting)
  DateTime? _tglMulai;
  TimeOfDay? _jamMulai;
  DateTime? _tglSelesai;
  TimeOfDay? _jamSelesai;

  bool _isSubmitting = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _fetchUserData();
  }

  @override
  void dispose() {
    _noteController.dispose();
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

  String _formatDate(DateTime? d) =>
      d == null ? '-' : DateFormat('dd MMM yyyy', 'id_ID').format(d);

  String _formatTime(TimeOfDay? t) => t == null
      ? '-'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);


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
          if (_tglSelesai != null && _tglSelesai!.isBefore(_tglMulai!)) {
            _tglSelesai = null;
            _jamSelesai = null;
          }
        } else {
          _tglSelesai = result;
        }
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
        return _TimePicker24Hour(
          initialTime: currentTime ?? const TimeOfDay(hour: 8, minute: 0),
          onTimeSelected: (selectedTime) {
            setState(() {
              if (isMulai) {
                _jamMulai = selectedTime;
              } else {
                _jamSelesai = selectedTime;
              }
            });
          },
        );
      },
    );
  }

  String _getInitialStatus() {
    final jabatan = (_userData?['jabatan'] ?? '').toString().toLowerCase();
    
    // Admin, manager umum, manager divisi → langsung approved
    if (widget.role == 'admin' || 
        (widget.role == 'user' && jabatan.contains('manager'))) {
      return 'APPROVED';
    }
    
    // Operator yang meminjam → langsung approved juga
    if (widget.role == 'operator') {
      return 'APPROVED';
    }
    
    // User biasa → menunggu operator
    return 'PENDING';
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final waktuMulai = _waktuMulai;
    final waktuSelesai = _waktuSelesai;

    if (waktuMulai == null || waktuSelesai == null) {
      _showSnackBar(
          'Pilih tanggal dan jam mulai serta selesai terlebih dahulu',
          Colors.orange);
      return;
    }

    if (!waktuSelesai.isAfter(waktuMulai)) {
      _showSnackBar('Waktu selesai harus setelah waktu mulai', Colors.red);
      return;
    }

    // Dialog konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Peminjaman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Nama', widget.userName),
            _confirmRow('Divisi', widget.userDivision),
            _confirmRow(
              'Waktu Mulai',
              _formatDateTime(waktuMulai),
            ),
            _confirmRow(
              'Waktu Selesai',
              _formatDateTime(waktuSelesai),
            ),
            if (_noteController.text.trim().isNotEmpty)
              _confirmRow('Catatan', _noteController.text.trim()),
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

      // Simpan ke collection 'gym_bookings' di Firestore
      final bookingData = {
        'peminjam': {
          'userId': widget.userId,
          'nama': widget.userName,
          'nipp': userData['nipp'] ?? widget.userId,
          'divisi': widget.userDivision,
          'jabatan': userData['jabatan'] ?? 'Staff',
          'email': userData['email'] ?? '',
          'role': widget.role,
        },
        'waktuMulai': Timestamp.fromDate(waktuMulai),
        'waktuSelesai': Timestamp.fromDate(waktuSelesai),
        'catatan': _noteController.text.trim(),
        'status': _getInitialStatus(),
        'createdAt': now,
        'updatedAt': now,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('gym_bookings')
          .add(bookingData);

          if (bookingData['status'] == 'PENDING') {
            try {
              final bookingDataWithId = {'id': docRef.id, ...bookingData};
              await ApprovalNotificationService.sendGymApprovalNotificationToOperator(
                bookingId: docRef.id,
                bookingData: bookingDataWithId,
              );
            } catch (e) {
              debugPrint('⚠️ [Gym] Gagal kirim notif WA: $e');
              // Lanjutkan meski notif gagal
            }
          }

      if (!mounted) return;

      _showSnackBar('Peminjaman ruang gym berhasil diajukan!', Colors.green);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanGymPage(
            data: {'id': docRef.id, ...bookingData},
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error submitting gym booking: $e');
      _showSnackBar('Gagal mengajukan peminjaman: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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

  // ──────────────────────────────────────────────────────────────
  // UI Helpers
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

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _confirmRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                '$label:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  // Date-time row (sama persis seperti form ruang meeting)
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
                isTime: label1.contains('Jam'))),
        const SizedBox(width: 12),
        Expanded(
            child: _pickerBox(label2, value2, onTap2,
                isTime: label2.contains('Jam'))),
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
            Text(label,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade700)),
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

  // ──────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────
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
        title: const Text(
          'Peminjaman Ruang Gym',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Informasi Penyewa ──────────────────────────────
              _buildSectionTitle('Informasi Penyewa', Icons.person_outline),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    _infoRow(Icons.person, 'Nama', widget.userName),
                    const Divider(height: 16),
                    _infoRow(
                      Icons.badge_outlined,
                      'NIPP',
                      _userData?['nipp']?.toString() ?? widget.userId,
                    ),
                    const Divider(height: 16),
                    _infoRow(Icons.business, 'Divisi', widget.userDivision),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Waktu Peminjaman ────────────────────────────────
              _buildSectionTitle(
                  'Waktu Peminjaman', Icons.calendar_month_outlined),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    // Baris Tanggal Mulai & Jam Mulai
                    _dateTimeRow(
                      'Tanggal Mulai',
                      _formatDate(_tglMulai),
                      () => _pickDate(true),
                      'Jam Mulai',
                      _formatTime(_jamMulai),
                      () => _pickTime(true),
                    ),
                    const SizedBox(height: 16),
                    // Baris Tanggal Selesai & Jam Selesai
                    _dateTimeRow(
                      'Tanggal Selesai',
                      _formatDate(_tglSelesai),
                      () => _pickDate(false),
                      'Jam Selesai',
                      _formatTime(_jamSelesai),
                      () => _pickTime(false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Catatan (Opsional) ──────────────────────────────
              _buildSectionTitle(
                  'Catatan (Opsional)', Icons.notes_outlined),
              const SizedBox(height: 12),
              _buildCard(
                child: TextFormField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Contoh: Membawa peralatan sendiri, butuh akses loker, dll...',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13),
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
                      borderSide:
                          BorderSide(color: Colors.blue.shade400, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  // Opsional — tidak perlu validator
                ),
              ),
              const SizedBox(height: 32),

              // ── Tombol Pinjam ───────────────────────────────────
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
                      : const Text(
                          'Pinjam',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
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
