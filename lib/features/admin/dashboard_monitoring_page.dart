import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../ruang_meeting/detail_peminjaman_ruang_meeting_page.dart';
import '../vehicle/detail_peminjaman_page.dart';
import '../vehicle/vehicle_tracking_map_page.dart';
import '../gym/detail_peminjaman_gym_page.dart';

class _CalendarEvent {
  final String bookingId;
  final String namaKegiatan;
  final String jenisRapat;
  final String peminjamNama;
  final String peminjamDivisi;
  final String namaRuang;
  final String lokasiRuang;
  final DateTime waktuMulai;
  final DateTime waktuSelesai;
  final String status;
  final Map<String, dynamic> rawData;

  const _CalendarEvent({
    required this.bookingId,
    required this.namaKegiatan,
    required this.jenisRapat,
    required this.peminjamNama,
    required this.peminjamDivisi,
    required this.namaRuang,
    required this.lokasiRuang,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.status,
    required this.rawData,
  });
}

class _VehicleBooking {
  final String bookingId;
  final String namaPeminjam;
  final String divisi;
  final String tujuan;
  final String vehicleNama;
  final String vehiclePlat;
  final String vehicleId;
  final DateTime waktuPinjam;
  final DateTime waktuKembali;
  final String status;
  final Map<String, dynamic> rawData;

  const _VehicleBooking({
    required this.bookingId,
    required this.namaPeminjam,
    required this.divisi,
    required this.tujuan,
    required this.vehicleNama,
    required this.vehiclePlat,
    required this.vehicleId,
    required this.waktuPinjam,
    required this.waktuKembali,
    required this.status,
    required this.rawData,
  });
}

class _GymBooking {
  final String bookingId;
  final String namaPeminjam;
  final String divisi;
  final String jabatan;
  final DateTime waktuMulai;
  final DateTime waktuSelesai;
  final String status;
  final String catatan;
  final Map<String, dynamic> rawData;

  const _GymBooking({
    required this.bookingId,
    required this.namaPeminjam,
    required this.divisi,
    required this.jabatan,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.status,
    required this.catatan,
    required this.rawData,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN PAGE
// ══════════════════════════════════════════════════════════════════════════════

class DashboardMonitoringPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;
  final String? operatorType;

  const DashboardMonitoringPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
    this.operatorType,
  });

  @override
  State<DashboardMonitoringPage> createState() =>
      _DashboardMonitoringPageState();
}

class _DashboardMonitoringPageState extends State<DashboardMonitoringPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Calendar state ──────────────────────────────────────────────────────
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  /// 'month' | 'week' | 'day'
  String _calendarView = 'month';

  List<_CalendarEvent> _allEvents = [];
  bool _isLoadingEvents = true;

  // Cache: roomId → namaRuang + lokasi
  final Map<String, Map<String, String>> _roomCache = {};

  // ── Vehicle monitoring state ────────────────────────────────────────────
  List<_VehicleBooking> _ongoingVehicles = [];
  bool _isLoadingVehicles = true;

  // ── Gym monitoring state ────────────────────────────────────────────────
  List<_GymBooking> _gymBookings = [];
  bool _isLoadingGym = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _tabController = TabController(length: 3, vsync: this); // ← ubah jadi 3
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadCalendarEvents();
    _loadOngoingVehicles();
    _loadGymBookings(); // ← tambah
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadCalendarEvents() async {
    if (!mounted) return;
    setState(() => _isLoadingEvents = true);
    try {
      // Load bookings that are approved or ongoing (not cancelled/submitted)
      final snapshot = await FirebaseFirestore.instance
          .collection('room_bookings')
          .where('status', whereIn: [
            'APPROVAL_1',
            'APPROVAL_2',
            'APPROVAL_3',
            'DONE',
          ])
          .get();

      final List<_CalendarEvent> events = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final waktuMulai =
            (data['waktuMulai'] as Timestamp?)?.toDate();
        final waktuSelesai =
            (data['waktuSelesai'] as Timestamp?)?.toDate();
        if (waktuMulai == null || waktuSelesai == null) continue;

        final peminjam =
            data['peminjam'] as Map<String, dynamic>? ?? {};
        final roomId = data['ruang']?['roomId'] as String?;

        // Fetch room info (with cache)
        Map<String, String> roomInfo = {'namaRuang': 'Ruang Meeting', 'lokasi': '-'};
        if (roomId != null) {
          if (_roomCache.containsKey(roomId)) {
            roomInfo = _roomCache[roomId]!;
          } else {
            try {
              final roomDoc = await FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(roomId)
                  .get();
              if (roomDoc.exists) {
                roomInfo = {
                  'namaRuang': roomDoc.data()?['namaRuang'] ?? 'Ruang Meeting',
                  'lokasi': roomDoc.data()?['lokasi'] ?? '-',
                };
                _roomCache[roomId] = roomInfo;
              }
            } catch (_) {}
          }
        }

        events.add(_CalendarEvent(
          bookingId: doc.id,
          namaKegiatan: data['namaKegiatan'] ?? '-',
          jenisRapat: data['jenisRapat'] ?? 'OFFLINE',
          peminjamNama: peminjam['nama'] ?? '-',
          peminjamDivisi: peminjam['divisi'] ?? '-',
          namaRuang: roomInfo['namaRuang']!,
          lokasiRuang: roomInfo['lokasi']!,
          waktuMulai: waktuMulai,
          waktuSelesai: waktuSelesai,
          status: data['status'] ?? 'APPROVAL_1',
          rawData: {'id': doc.id, ...data},
        ));
      }

      if (mounted) {
        setState(() {
          _allEvents = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading calendar events: $e');
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _loadOngoingVehicles() async {
    if (!mounted) return;
    setState(() => _isLoadingVehicles = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', isEqualTo: 'ON_GOING')
          .orderBy('waktuPinjam', descending: false)
          .get();

      final List<_VehicleBooking> bookings = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final waktuPinjam =
            (data['waktuPinjam'] as Timestamp?)?.toDate();
        final waktuKembali =
            (data['waktuKembali'] as Timestamp?)?.toDate();
        if (waktuPinjam == null || waktuKembali == null) continue;

        final vehicle =
            data['vehicle'] as Map<String, dynamic>? ?? {};

        bookings.add(_VehicleBooking(
          bookingId: doc.id,
          namaPeminjam: data['namaPeminjam'] ?? '-',
          divisi: data['divisi'] ?? '-',
          tujuan: data['tujuan'] ?? '-',
          vehicleNama: vehicle['nama'] ?? data['vehicleNama'] ?? 'Kendaraan',
          vehiclePlat: vehicle['platNomor'] ?? '-',
          vehicleId: data['vehicleId'] ?? '',
          waktuPinjam: waktuPinjam,
          waktuKembali: waktuKembali,
          status: 'ON_GOING',
          rawData: {'id': doc.id, ...data},
        ));
      }

      if (mounted) {
        setState(() {
          _ongoingVehicles = bookings;
          _isLoadingVehicles = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading ongoing vehicles: $e');
      if (mounted) setState(() => _isLoadingVehicles = false);
    }
  }

  Future<void> _loadGymBookings() async {
    if (!mounted) return;
    setState(() => _isLoadingGym = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('gym_bookings')
          .where('status', whereIn: ['PENDING', 'APPROVED'])
          .orderBy('waktuMulai', descending: false)
          .get();

      final List<_GymBooking> bookings = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final waktuMulai = (data['waktuMulai'] as Timestamp?)?.toDate();
        final waktuSelesai = (data['waktuSelesai'] as Timestamp?)?.toDate();
        if (waktuMulai == null || waktuSelesai == null) continue;

        final peminjam = data['peminjam'] as Map<String, dynamic>? ?? {};

        bookings.add(_GymBooking(
          bookingId: doc.id,
          namaPeminjam: peminjam['nama'] ?? '-',
          divisi: peminjam['divisi'] ?? '-',
          jabatan: peminjam['jabatan'] ?? '-',
          waktuMulai: waktuMulai,
          waktuSelesai: waktuSelesai,
          status: data['status'] ?? 'PENDING',
          catatan: data['catatan']?.toString() ?? '',
          rawData: {'id': doc.id, ...data},
        ));
      }

      if (mounted) {
        setState(() {
          _gymBookings = bookings;
          _isLoadingGym = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading gym bookings: $e');
      if (mounted) setState(() => _isLoadingGym = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Events on a specific day (multi-day events are included if they span the day)
  List<_CalendarEvent> _eventsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _allEvents.where((e) {
      final start = DateTime(
          e.waktuMulai.year, e.waktuMulai.month, e.waktuMulai.day);
      final end = DateTime(
          e.waktuSelesai.year, e.waktuSelesai.month, e.waktuSelesai.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  String _fmt(DateTime dt) =>
      DateFormat('dd MMM yyyy', 'id_ID').format(dt);
  String _fmtTime(DateTime dt) => DateFormat('HH:mm').format(dt);
  String _fmtMonth(DateTime dt) =>
      DateFormat('MMMM yyyy', 'id_ID').format(dt);
  String _fmtDay(DateTime dt) =>
      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);

  Color _eventColor(_CalendarEvent e) {
    switch (e.status) {
      case 'APPROVAL_3':
        return Colors.teal;
      case 'DONE':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _jenisColor(String jenis) {
    switch (jenis.toUpperCase()) {
      case 'ONLINE':
        return Colors.blue.shade600;
      case 'HYBRID':
        return Colors.purple.shade600;
      default:
        return Colors.teal.shade600;
    }
  }

  IconData _jenisIcon(String jenis) {
    switch (jenis.toUpperCase()) {
      case 'ONLINE':
        return Icons.videocam_outlined;
      case 'HYBRID':
        return Icons.devices_outlined;
      default:
        return Icons.people_outline;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Duration string for vehicle
  String _durationLabel(DateTime from, DateTime to) {
    final diff = to.difference(from);
    if (diff.inHours < 24) {
      return '${diff.inHours}j ${diff.inMinutes % 60}m';
    }
    return '${diff.inDays} hari';
  }

  // Overtime indicator
  bool _isOverdue(_VehicleBooking v) =>
      DateTime.now().isAfter(v.waktuKembali);

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: Colors.grey.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Dashboard & Monitoring',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // ← biar 3 tab tidak sempit
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.meeting_room_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('Ruang Meeting'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('Kendaraan'),
                ],
              ),
            ),
            Tab(  // ← tab gym
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center, size: 16),
                  const SizedBox(width: 6),
                  const Text('Gym'),
                ],
              ),
            ),
          ],
          labelColor: Colors.teal.shade700,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: Colors.teal.shade700,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMeetingCalendarTab(),
          _buildVehicleMonitoringTab(),
          _buildGymMonitoringTab(), // ← tambah gym
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 – MEETING ROOM CALENDAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMeetingCalendarTab() {
    return _isLoadingEvents
        ? Center(
            child:
                CircularProgressIndicator(color: Colors.teal.shade600))
        : RefreshIndicator(
            onRefresh: _loadCalendarEvents,
            color: Colors.teal.shade600,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Summary cards ──────────────────────────────────────
                  _buildMeetingSummaryCards(),
                  const SizedBox(height: 16),

                  // ── Calendar card ──────────────────────────────────────
                  _buildCalendarCard(),
                  const SizedBox(height: 16),

                  // ── Events for selected day ────────────────────────────
                  _buildSelectedDayEvents(),
                ],
              ),
            ),
          );
  }

  Widget _buildMeetingSummaryCards() {
    final now = DateTime.now();
    final todayEvents = _eventsForDay(now);
    final upcoming = _allEvents
        .where((e) =>
            e.waktuMulai.isAfter(now) &&
            e.waktuMulai
                .isBefore(now.add(const Duration(days: 7))))
        .length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.today_outlined,
            label: 'Rapat Hari Ini',
            value: todayEvents.length.toString(),
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.upcoming_outlined,
            label: '7 Hari ke Depan',
            value: upcoming.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.event_available_outlined,
            label: 'Total Terjadwal',
            value: _allEvents.length.toString(),
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header: navigation + view switcher ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _prevPeriod,
                  icon: Icon(Icons.chevron_left_rounded,
                      color: Colors.grey.shade700),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _headerTitle(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _nextPeriod,
                  icon: Icon(Icons.chevron_right_rounded,
                      color: Colors.grey.shade700),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // View toggle chips
                _viewChip('M', 'month'),
                const SizedBox(width: 4),
                _viewChip('W', 'week'),
                const SizedBox(width: 4),
                _viewChip('D', 'day'),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Calendar body ────────────────────────────────────────────
          _buildCalendarBody(),
        ],
      ),
    );
  }

  Widget _viewChip(String label, String view) {
    final isActive = _calendarView == view;
    return GestureDetector(
      onTap: () => setState(() {
        _calendarView = view;
        _selectedDay = _focusedDay;
      }),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isActive ? Colors.teal.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  String _headerTitle() {
    if (_calendarView == 'month') return _fmtMonth(_focusedDay);
    if (_calendarView == 'week') {
      final start = _weekStart(_focusedDay);
      final end = start.add(const Duration(days: 6));
      return '${_fmt(start)} – ${_fmt(end)}';
    }
    return _fmtDay(_focusedDay);
  }

  void _prevPeriod() {
    setState(() {
      if (_calendarView == 'month') {
        _focusedDay =
            DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
      } else if (_calendarView == 'week') {
        _focusedDay =
            _focusedDay.subtract(const Duration(days: 7));
      } else {
        _focusedDay =
            _focusedDay.subtract(const Duration(days: 1));
      }
      _selectedDay = _focusedDay;
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_calendarView == 'month') {
        _focusedDay =
            DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
      } else if (_calendarView == 'week') {
        _focusedDay = _focusedDay.add(const Duration(days: 7));
      } else {
        _focusedDay = _focusedDay.add(const Duration(days: 1));
      }
      _selectedDay = _focusedDay;
    });
  }

  DateTime _weekStart(DateTime day) {
    // Week starts on Monday
    final wd = day.weekday; // 1=Mon, 7=Sun
    return day.subtract(Duration(days: wd - 1));
  }

  Widget _buildCalendarBody() {
    if (_calendarView == 'month') return _buildMonthView();
    if (_calendarView == 'week') return _buildWeekView();
    return _buildDayView(_focusedDay);
  }

  // ── Month View ──────────────────────────────────────────────────────────

  Widget _buildMonthView() {
    final year = _focusedDay.year;
    final month = _focusedDay.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    // Offset: Monday = 0
    int startOffset = firstDay.weekday - 1;

    final dayHeaders = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          // Day headers
          Row(
            children: dayHeaders.map((h) {
              return Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 2,
              childAspectRatio: 0.72,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (_, index) {
              if (index < startOffset) return const SizedBox();
              final day = DateTime(
                  year, month, index - startOffset + 1);
              return _buildMonthDayCell(day);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthDayCell(DateTime day) {
    final events = _eventsForDay(day);
    final isToday = _isSameDay(day, DateTime.now());
    final isSelected = _isSameDay(day, _selectedDay);
    final hasEvents = events.isNotEmpty;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedDay = day;
        _focusedDay = day;
      }),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.teal.shade600
              : isToday
                  ? Colors.teal.shade50
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: Colors.teal.shade300, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : isToday
                        ? Colors.teal.shade700
                        : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 2),
            // Event dots – up to 3
            if (hasEvents)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  alignment: WrapAlignment.center,
                  children: events.take(3).map((e) {
                    return Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.85)
                            : _eventColor(e),
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              ),
            // "+N" if more than 3
            if (events.length > 3)
              Text(
                '+${events.length - 3}',
                style: TextStyle(
                  fontSize: 8,
                  color: isSelected
                      ? Colors.white70
                      : Colors.teal.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Week View ───────────────────────────────────────────────────────────

  Widget _buildWeekView() {
    final start = _weekStart(_focusedDay);
    final days =
        List.generate(7, (i) => start.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          // Day headers
          Row(
            children: days.map((day) {
              final isToday = _isSameDay(day, DateTime.now());
              final isSelected = _isSameDay(day, _selectedDay);
              final events = _eventsForDay(day);

              return Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedDay = day),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.teal.shade600
                          : isToday
                              ? Colors.teal.shade50
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: Colors.teal.shade300,
                              width: 1.5)
                          : Border.all(
                              color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE', 'id_ID').format(day),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white70
                                : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? Colors.teal.shade700
                                    : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (events.isNotEmpty)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.teal.shade400,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Events for selected day in week
          ..._eventsForDay(_selectedDay).map(_buildCompactEventTile),
          if (_eventsForDay(_selectedDay).isEmpty)
            _buildNoEventPlaceholder(),
        ],
      ),
    );
  }

  // ── Day View ────────────────────────────────────────────────────────────

  Widget _buildDayView(DateTime day) {
    final events = _eventsForDay(day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fmtDay(day),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade700,
            ),
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            _buildNoEventPlaceholder()
          else
            ...events.map(_buildCompactEventTile),
        ],
      ),
    );
  }

  Widget _buildCompactEventTile(_CalendarEvent e) {
    final color = _eventColor(e);
    return GestureDetector(
      onTap: () => _showEventDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.namaKegiatan,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.meeting_room_outlined,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        e.namaRuang,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.schedule_outlined,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        '${_fmtTime(e.waktuMulai)}–${_fmtTime(e.waktuSelesai)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              _jenisIcon(e.jenisRapat),
              size: 16,
              color: _jenisColor(e.jenisRapat),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEventPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined,
              size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            'Tidak ada jadwal rapat',
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ── Selected day event list (below calendar) ────────────────────────────

  Widget _buildSelectedDayEvents() {
    final events = _eventsForDay(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Jadwal ${_fmtDay(_selectedDay)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(
                '${events.length} rapat',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 42, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text(
                  'Tidak ada rapat pada hari ini',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          ...events.map(_buildFullEventCard),
      ],
    );
  }

  Widget _buildFullEventCard(_CalendarEvent e) {
    final color = _eventColor(e);
    final jenisColor = _jenisColor(e.jenisRapat);

    return GestureDetector(
      onTap: () => _showEventDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              // Left color bar
              Container(
                width: 6,
                height: 110,
                color: color,
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama kegiatan + jenis badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.namaKegiatan,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: jenisColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: jenisColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_jenisIcon(e.jenisRapat),
                                    size: 11, color: jenisColor),
                                const SizedBox(width: 4),
                                Text(
                                  e.jenisRapat,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: jenisColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Ruang & lokasi
                      Row(
                        children: [
                          Icon(Icons.meeting_room_outlined,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${e.namaRuang}  •  ${e.lokasiRuang}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Waktu
                      Row(
                        children: [
                          Icon(Icons.schedule_outlined,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 5),
                          Text(
                            '${_fmtTime(e.waktuMulai)} – ${_fmtTime(e.waktuSelesai)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Spacer(),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _statusLabel(e.status),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Peminjam
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 5),
                          Text(
                            '${e.peminjamNama}  •  ${e.peminjamDivisi}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              size: 16, color: Colors.grey.shade400),
                        ],
                      ),
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

  String _statusLabel(String status) {
    switch (status) {
      case 'APPROVAL_1':
        return 'Menunggu Operator';
      case 'APPROVAL_2':
        return 'Menunggu Mgr Umum';
      case 'APPROVAL_3':
        return 'Disetujui';
      case 'DONE':
        return 'Selesai';
      default:
        return status;
    }
  }

  // ── Event detail bottom sheet ────────────────────────────────────────────

  void _showEventDetail(_CalendarEvent e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventDetailSheet(
        event: e,
        onViewDetail: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailPeminjamanRuangMeetingPage(
                data: e.rawData,
                role: widget.role,
                userName: widget.userName,
                userId: widget.userId,
                userDivision: widget.userDivision,
                isApprovalMode: false,
              ),
            ),
          ).then((_) => _loadCalendarEvents());
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 – VEHICLE MONITORING
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildVehicleMonitoringTab() {
    return _isLoadingVehicles
        ? Center(
            child: CircularProgressIndicator(
                color: Colors.blue.shade600))
        : RefreshIndicator(
            onRefresh: _loadOngoingVehicles,
            color: Colors.blue.shade600,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Vehicle summary cards ──────────────────────────────
                  _buildVehicleSummaryCards(),
                  const SizedBox(height: 16),

                  // ── GPS placeholder banner ─────────────────────────────
                  _buildGpsBanner(),
                  const SizedBox(height: 16),

                  // ── Ongoing bookings list ──────────────────────────────
                  _buildOngoingVehicleList(),
                ],
              ),
            ),
          );
  }

  Widget _buildVehicleSummaryCards() {
    final overdue =
        _ongoingVehicles.where(_isOverdue).length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.directions_car_outlined,
            label: 'Sedang Dipinjam',
            value: _ongoingVehicles.length.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.warning_amber_outlined,
            label: 'Terlambat Kembali',
            value: overdue.toString(),
            color: overdue > 0 ? Colors.red : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildGpsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Map placeholder icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.map_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live GPS Tracking',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap card kendaraan di bawah untuk melihat lokasi kendaraan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.4)),
            ),
            child: const Text(
              'Live\nNow',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOngoingVehicleList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
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
            Text(
              'Kendaraan Sedang Digunakan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '${_ongoingVehicles.length} unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_ongoingVehicles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.directions_car_outlined,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'Tidak ada kendaraan yang sedang digunakan',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          ..._ongoingVehicles
              .map((v) => _buildVehicleCard(v)),
      ],
    );
  }

  Widget _buildVehicleCard(_VehicleBooking v) {
    final isOverdue = _isOverdue(v);
    final now = DateTime.now();

    // Calculate how much time left or overdue
    final diff = v.waktuKembali.difference(now);
    String timeLabel;
    Color timeColor;

    if (isOverdue) {
      final od = now.difference(v.waktuKembali);
      timeLabel = 'Terlambat ${_durationLabel(v.waktuKembali, now)}';
      timeColor = Colors.red.shade700;
    } else if (diff.inHours < 2) {
      timeLabel = 'Sisa ${_durationLabel(now, v.waktuKembali)}';
      timeColor = Colors.orange.shade700;
    } else {
      timeLabel = 'Sisa ${_durationLabel(now, v.waktuKembali)}';
      timeColor = Colors.green.shade700;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleTrackingMapPage(
            bookingId: v.bookingId,
            vehicleNama: v.vehicleNama,
            vehiclePlat: v.vehiclePlat,
            namaPeminjam: v.namaPeminjam,
            divisi: v.divisi,
            tujuan: v.tujuan,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOverdue
                ? Colors.red.shade200
                : Colors.grey.shade100,
            width: isOverdue ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isOverdue
                  ? Colors.red.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: vehicle info + overdue badge ─────────────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_car_filled,
                      color: isOverdue
                          ? Colors.red.shade600
                          : Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.vehicleNama,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          v.vehiclePlat,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // GPS coming soon chip per kendaraan
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11,
                            color: Colors.green.shade700),
                        const SizedBox(width: 3),
                        Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade100, height: 1),
              const SizedBox(height: 10),

              // ── Row 2: peminjam info ─────────────────────────────
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${v.namaPeminjam}  •  ${v.divisi}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),

              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      v.tujuan,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Row 3: time info ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? Colors.red.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOverdue
                        ? Colors.red.shade200
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ambil',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500),
                          ),
                          Text(
                            '${_fmt(v.waktuPinjam)} ${_fmtTime(v.waktuPinjam)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Colors.grey.shade400),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Kembali',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500),
                          ),
                          Text(
                            '${_fmt(v.waktuKembali)} ${_fmtTime(v.waktuKembali)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOverdue
                                  ? Colors.red.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Time remaining / overdue chip ────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: timeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: timeColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.timer_outlined,
                          size: 12,
                          color: timeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: timeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                                    GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailPeminjamanPage(
                          data: v.rawData,
                          approvalStep: 0,
                          role: widget.role,
                          userName: widget.userName,
                          userId: widget.userId,
                          userDivision: widget.userDivision,
                          isApprovalMode: false,
                          operatorType: widget.operatorType,
                        ),
                      ),
                    ).then((_) => _loadOngoingVehicles()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_outlined,
                              size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Detail',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 – GYM MONITORING
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGymMonitoringTab() {
    return _isLoadingGym
        ? Center(child: CircularProgressIndicator(color: Colors.green.shade600))
        : RefreshIndicator(
            onRefresh: _loadGymBookings,
            color: Colors.green.shade600,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGymSummaryCards(),
                  const SizedBox(height: 16),
                  _buildGymBookingList(),
                ],
              ),
            ),
          );
  }

  Widget _buildGymSummaryCards() {
    final pending = _gymBookings.where((g) => g.status == 'PENDING').length;
    final approved = _gymBookings.where((g) => g.status == 'APPROVED').length;
    final now = DateTime.now();
    final ongoing = _gymBookings.where((g) =>
        g.status == 'APPROVED' &&
        now.isAfter(g.waktuMulai) &&
        now.isBefore(g.waktuSelesai)).length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.hourglass_empty_rounded,
            label: 'Menunggu\nApproval',
            value: pending.toString(),
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.check_circle_outline,
            label: 'Sudah\nDisetujui',
            value: approved.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.fitness_center,
            label: 'Sedang\nBerlangsung',
            value: ongoing.toString(),
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildGymBookingList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Peminjaman Gym Aktif',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '${_gymBookings.length} booking',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_gymBookings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'Tidak ada peminjaman gym aktif',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          ..._gymBookings.map((g) => _buildGymCard(g)),
      ],
    );
  }

  Widget _buildGymCard(_GymBooking g) {
    final now = DateTime.now();
    final isOngoing = g.status == 'APPROVED' &&
        now.isAfter(g.waktuMulai) && now.isBefore(g.waktuSelesai);
    final isPending = g.status == 'PENDING';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isPending) {
      statusColor = Colors.orange.shade700;
      statusLabel = 'Menunggu Approval';
      statusIcon = Icons.hourglass_empty_rounded;
    } else if (isOngoing) {
      statusColor = Colors.blue.shade700;
      statusLabel = 'Sedang Berlangsung';
      statusIcon = Icons.fitness_center;
    } else {
      statusColor = Colors.green.shade700;
      statusLabel = 'Disetujui';
      statusIcon = Icons.check_circle_outline;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanGymPage(
            data: g.rawData,
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: false,
            operatorType: widget.operatorType,
          ),
        ),
      ).then((_) => _loadGymBookings()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOngoing ? Colors.blue.shade200 : Colors.grey.shade100,
            width: isOngoing ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: icon + nama + status badge
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.namaPeminjam,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          '${g.divisi}  •  ${g.jabatan}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade100, height: 1),
              const SizedBox(height: 10),

              // Row 2: waktu
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mulai',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          Text(
                            '${_fmt(g.waktuMulai)} ${_fmtTime(g.waktuMulai)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Colors.grey.shade400),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Selesai',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          Text(
                            '${_fmt(g.waktuSelesai)} ${_fmtTime(g.waktuSelesai)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (g.catatan.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notes_outlined, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        g.catatan,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EVENT DETAIL BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _EventDetailSheet extends StatelessWidget {
  final _CalendarEvent event;
  final VoidCallback onViewDetail;

  const _EventDetailSheet({
    required this.event,
    required this.onViewDetail,
  });

  String _fmtDT(DateTime dt) =>
      DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);

  Color _statusColor(String s) {
    switch (s) {
      case 'APPROVAL_3':
        return Colors.teal;
      case 'DONE':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'APPROVAL_1':
        return 'Menunggu Operator';
      case 'APPROVAL_2':
        return 'Menunggu Manager Umum';
      case 'APPROVAL_3':
        return 'Disetujui';
      case 'DONE':
        return 'Selesai';
      default:
        return s;
    }
  }

  Color _jenisColor(String jenis) {
    switch (jenis.toUpperCase()) {
      case 'ONLINE':
        return Colors.blue.shade600;
      case 'HYBRID':
        return Colors.purple.shade600;
      default:
        return Colors.teal.shade600;
    }
  }

  IconData _jenisIcon(String jenis) {
    switch (jenis.toUpperCase()) {
      case 'ONLINE':
        return Icons.videocam_outlined;
      case 'HYBRID':
        return Icons.devices_outlined;
      default:
        return Icons.people_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(event.status);
    final jenisColor = _jenisColor(event.jenisRapat);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  event.namaKegiatan,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  _statusLabel(event.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info rows
          _infoRow(
            Icons.meeting_room_outlined,
            'Ruang',
            '${event.namaRuang}  •  ${event.lokasiRuang}',
            Colors.teal.shade600,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.schedule_outlined,
            'Waktu Mulai',
            _fmtDT(event.waktuMulai),
            Colors.blue.shade600,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.schedule_rounded,
            'Waktu Selesai',
            _fmtDT(event.waktuSelesai),
            Colors.blue.shade600,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.person_outline,
            'Peminjam',
            event.peminjamNama,
            Colors.orange.shade600,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.business_outlined,
            'Divisi',
            event.peminjamDivisi,
            Colors.purple.shade600,
          ),
          const SizedBox(height: 10),
          // Jenis rapat
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: jenisColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_jenisIcon(event.jenisRapat),
                    color: jenisColor, size: 17),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jenis Rapat',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500)),
                  Text(event.jenisRapat,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: jenisColor,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onViewDetail,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Lihat Detail Peminjaman',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 1),
              Text(value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}