import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class RoomDisplayPage extends StatefulWidget {
  const RoomDisplayPage({super.key});

  @override
  State<RoomDisplayPage> createState() => _RoomDisplayPageState();
}

class _RoomDisplayPageState extends State<RoomDisplayPage>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  Map<String, Map<String, dynamic>> _roomMap = {};
  List<Map<String, dynamic>> _todaySchedules = [];
  Map<String, dynamic>? _activeRoom;
  String _activeDisplayStatus = '';

  List<Map<String, dynamic>> _ongoingRooms = [];
  int _ongoingIndex = 0;
  Timer? _rotationTimer;

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _scrollingDown = true;

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _patternController;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _patternAnim;

  StreamSubscription? _roomSub;
  StreamSubscription? _bookingSub;

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const _navy        = Color(0xFF0B2D5E);
  static const _navyMid     = Color(0xFF1A4A8A);
  static const _blue        = Color(0xFF2563EB);
  static const _accent      = Color(0xFF0EA5E9);
  static const _accentGold  = Color(0xFFF59E0B);
  static const _accentGreen = Color(0xFF10B981);
  static const _textDark    = Color(0xFF0B2D5E);
  static const _textMid     = Color(0xFF1E3A6E);
  static const _textSub     = Color(0xFF4A7AB5);
  static const _textLight   = Color(0xFF8BAFD8);
  static const _borderColor = Color(0xFFB8D4EE);
  static const _bgWhite     = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _patternController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _patternAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      _patternController,
    );

    _startClock();
    _listenRooms();
    _listenBookings();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _rotationTimer?.cancel();
    _scrollTimer?.cancel();
    _roomSub?.cancel();
    _bookingSub?.cancel();
    _scrollController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  void _listenRooms() {
    _roomSub = FirebaseFirestore.instance
        .collection('rooms')
        .snapshots()
        .listen((snapshot) {
      final map = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        map[doc.id] = {'id': doc.id, ...doc.data()};
      }
      if (mounted) setState(() => _roomMap = map);
    });
  }

  void _listenBookings() {
    final startOfDay = DateTime(_now.year, _now.month, _now.day, 0, 0, 0);
    final endOfDay   = DateTime(_now.year, _now.month, _now.day, 23, 59, 59);

    _bookingSub = FirebaseFirestore.instance
        .collection('room_bookings')
        .where('status', isEqualTo: 'APPROVAL_3')
        .where('waktuMulai',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('waktuMulai',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('waktuMulai')
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();

      final schedules = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((item) {
            final end = (item['waktuSelesai'] as Timestamp?)?.toDate();
            return end != null && end.isAfter(now);
          })
          .toList();

      final ongoing = schedules.where((item) {
        final start = (item['waktuMulai'] as Timestamp?)?.toDate();
        final end   = (item['waktuSelesai'] as Timestamp?)?.toDate();
        if (start == null || end == null) return false;
        return now.isAfter(start) && now.isBefore(end);
      }).toList();

      final upcoming = schedules.where((item) {
        final start = (item['waktuMulai'] as Timestamp?)?.toDate();
        return start != null && start.isAfter(now);
      }).toList();

      Map<String, dynamic>? newActive;
      String newStatus = '';

      if (ongoing.isNotEmpty) {
        final idx = _ongoingIndex % ongoing.length;
        newActive = ongoing[idx];
        newStatus = 'ONGOING';
      } else if (upcoming.isNotEmpty) {
        newActive = upcoming.first;
        newStatus = 'UPCOMING';
      }

      if (mounted) {
        setState(() {
          _todaySchedules      = schedules;
          _ongoingRooms        = ongoing;
          _activeRoom          = newActive;
          _activeDisplayStatus = newStatus;
        });
        _setupRotation(ongoing);
        _setupAutoScroll(schedules);
      }
    });
  }

  void _setupRotation(List<Map<String, dynamic>> ongoing) {
    _rotationTimer?.cancel();
    if (ongoing.length <= 1) return;
    _rotationTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      setState(() {
        _ongoingIndex        = (_ongoingIndex + 1) % ongoing.length;
        _activeRoom          = ongoing[_ongoingIndex];
        _activeDisplayStatus = 'ONGOING';
      });
      _fadeController.reset();
      _fadeController.forward();
    });
  }

  void _setupAutoScroll(List<Map<String, dynamic>> schedules) {
    _scrollTimer?.cancel();
    if (schedules.length <= 4) return;
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted || !_scrollController.hasClients) return;
        final max     = _scrollController.position.maxScrollExtent;
        final current = _scrollController.offset;
        if (_scrollingDown) {
          if (current >= max) {
            _scrollingDown = false;
          } else {
            _scrollController.jumpTo(current + 0.6);
          }
        } else {
          if (current <= 0) {
            _scrollingDown = true;
          } else {
            _scrollController.jumpTo(current - 0.6);
          }
        }
      });
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtClock(DateTime dt) => DateFormat('HH:mm:ss').format(dt);
  String _fmtDate(DateTime dt)  =>
      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt).toUpperCase();
  String _fmtTime(Timestamp? ts) =>
      ts == null ? '-' : DateFormat('HH:mm').format(ts.toDate());
  String _fmtRange(Timestamp? s, Timestamp? e) {
    if (s == null || e == null) return '-';
    return '${DateFormat('HH:mm').format(s.toDate())}  –  '
        '${DateFormat('HH:mm').format(e.toDate())}';
  }

  String _roomName(String? id) {
    if (id == null) return 'RUANG TIDAK DIKETAHUI';
    final r = _roomMap[id];
    if (r == null) return 'RUANG TIDAK DIKETAHUI';
    return '${r['namaRuang'] ?? ''}  —  ${r['lokasi'] ?? ''}'.toUpperCase();
  }

  String _roomShort(String? id) {
    if (id == null) return '-';
    return (_roomMap[id]?['namaRuang'] ?? '-').toString().toUpperCase();
  }

  bool _isOngoing(Map<String, dynamic> item) {
    final now   = DateTime.now();
    final start = (item['waktuMulai'] as Timestamp?)?.toDate();
    final end   = (item['waktuSelesai'] as Timestamp?)?.toDate();
    if (start == null || end == null) return false;
    return now.isAfter(start) && now.isBefore(end);
  }

  String _initial(String? name) {
    if (name == null || name.isEmpty) return '?';
    final p = name.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : name[0].toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _patternAnim,
              builder: (_, __) => CustomPaint(
                painter: _ElegantBgPainter(_patternAnim.value),
              ),
            ),
          ),
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 58, child: _buildLeftPanel()),
                    _buildVerticalDivider(),
                    Expanded(flex: 42, child: _buildRightPanel()),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071D42), Color(0xFF0B2D5E), Color(0xFF1A4A8A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          // Pelindo logo
          Image.asset(
            'assets/images/logo-pelindo.webp',
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.anchor, color: _accent, size: 22),
            ),
          ),
          const SizedBox(width: 18),
          Container(
            width: 1,
            height: 30,
            color: _accentGold.withOpacity(0.45),
          ),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'PT PELABUHAN INDONESIA SUB REGIONAL JAWA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Developed by Pintra',
                style: TextStyle(
                  color: _accent.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const Spacer(),
          // Live indicator
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _accentGreen
                        .withOpacity(0.5 + _pulseAnim.value * 0.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accentGreen.withOpacity(0.5),
                        blurRadius: 8 * _pulseAnim.value,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Left Panel ─────────────────────────────────────────────────────────────
  Widget _buildLeftPanel() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(52, 44, 44, 44),
        child: _activeRoom == null ? _buildEmpty() : _buildActiveRoom(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _bgWhite.withOpacity(0.55),
              shape: BoxShape.circle,
              border: Border.all(color: _borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(0.08),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.meeting_room_outlined,
              color: _textLight,
              size: 42,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'TIDAK ADA JADWAL AKTIF',
            style: TextStyle(
              color: _textMid,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Semua ruang meeting tersedia',
            style: TextStyle(
              color: _textSub,
              fontSize: 14,
              letterSpacing: 1,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRoom() {
    final room      = _activeRoom!;
    final roomId    = room['ruang']?['roomId'] as String?;
    final isOngoing = _activeDisplayStatus == 'ONGOING';
    final statusClr = isOngoing ? const Color(0xFFDC2626) : _blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Status pill
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: statusClr.withOpacity(0.09),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: statusClr.withOpacity(
                    isOngoing ? 0.35 + _pulseAnim.value * 0.3 : 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusClr.withOpacity(
                        isOngoing ? 0.5 + _pulseAnim.value * 0.5 : 1),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isOngoing ? 'SEDANG BERLANGSUNG' : 'AKAN DATANG',
                  style: TextStyle(
                    color: statusClr,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 36),

        // Time range
        Text(
          _fmtRange(
            room['waktuMulai'] as Timestamp?,
            room['waktuSelesai'] as Timestamp?,
          ),
          style: const TextStyle(
            color: _navy,
            fontSize: 58,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            height: 1,
            fontFamily: 'Poppins',
          ),
        ),

        const SizedBox(height: 22),

        // Gold accent bar
        Row(
          children: [
            Container(width: 44, height: 3, color: _accentGold),
            const SizedBox(width: 6),
            Container(
                width: 10,
                height: 3,
                color: _accentGold.withOpacity(0.4)),
            const SizedBox(width: 4),
            Container(
                width: 5,
                height: 3,
                color: _accentGold.withOpacity(0.15)),
          ],
        ),

        const SizedBox(height: 26),

        // Nama kegiatan
        Text(
          (room['namaKegiatan'] ?? '-').toString().toUpperCase(),
          style: const TextStyle(
            color: _textDark,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            height: 1.25,
            fontFamily: 'Poppins',
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 16),

        // Nama ruang + lokasi
        Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: _textSub, size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                _roomName(roomId),
                style: const TextStyle(
                  color: _textSub,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                  fontFamily: 'Poppins',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 36),

        // Horizontal separator
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_borderColor, _borderColor.withOpacity(0.05)],
            ),
          ),
        ),

        const SizedBox(height: 28),


        // Rotation dots
        if (_ongoingRooms.length > 1) ...[
          const SizedBox(height: 26),
          Row(
            children: List.generate(_ongoingRooms.length, (i) {
              final active = i == _ongoingIndex % _ongoingRooms.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: active ? 28 : 7,
                height: 4,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: active ? _navy : _borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  // ── Vertical Divider ───────────────────────────────────────────────────────
  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _borderColor.withOpacity(0.15),
            _borderColor.withOpacity(0.7),
            _borderColor.withOpacity(0.15),
          ],
        ),
      ),
    );
  }

  // ── Right Panel ────────────────────────────────────────────────────────────
  Widget _buildRightPanel() {
    return Column(
      children: [
        _buildClock(),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _borderColor.withOpacity(0.2),
                _borderColor.withOpacity(0.7),
                _borderColor.withOpacity(0.2),
              ],
            ),
          ),
        ),
        Expanded(child: _buildScheduleList()),
      ],
    );
  }

  Widget _buildClock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
      color: _bgWhite.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fmtClock(_now),
            style: const TextStyle(
              color: _navy,
              fontSize: 50,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
              fontFamily: 'Poppins',
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _fmtDate(_now),
            style: const TextStyle(
              color: _textSub,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 22, 32, 14),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'JADWAL HARI INI',
                style: TextStyle(
                  color: _textMid,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  fontFamily: 'Poppins',
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navy.withOpacity(0.12)),
                ),
                child: Text(
                  '${_todaySchedules.length} JADWAL',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _todaySchedules.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada jadwal hari ini',
                    style: TextStyle(
                      color: _textLight,
                      fontSize: 13,
                      fontFamily: 'Poppins',
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: _todaySchedules.length,
                  itemBuilder: (_, i) =>
                      _buildScheduleItem(_todaySchedules[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> item) {
    final active = _isOngoing(item);
    final roomId = item['ruang']?['roomId'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: active ? _navy.withOpacity(0.06) : _bgWhite.withOpacity(0.48),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? _navy.withOpacity(0.22)
              : _borderColor.withOpacity(0.5),
          width: active ? 1.5 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _navy.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Active left accent bar
            if (active)
              Container(
                width: 3,
                height: 34,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // Time
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmtTime(item['waktuMulai'] as Timestamp?),
                    style: TextStyle(
                      color: active ? _navy : _textMid,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    _fmtTime(item['waktuSelesai'] as Timestamp?),
                    style: const TextStyle(
                      color: _textLight,
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: _borderColor.withOpacity(0.6),
            ),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roomShort(roomId),
                    style: const TextStyle(
                      color: _textSub,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (item['namaKegiatan'] ?? '-').toString(),
                    style: TextStyle(
                      color: active ? _navy : _textDark,
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Pulse dot for active
            if (active)
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: _navy.withOpacity(_pulseAnim.value),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071D42), Color(0xFF0B2D5E)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(
              color: _accentGold,
            ),
            height: double.infinity,
            child: const Center(
              child: Text(
                'INFO',
                style: TextStyle(
                  color: _navy,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: _MarqueeText(
                text: 'HARAP MENJAGA KEBERSIHAN DAN KETERTIBAN RUANG MEETING   '
                    '•   PEMINJAMAN RUANG DAPAT DILAKUKAN MELALUI APLIKASI PINTRA   '
                    '•   MELALUI PINTRA, PELINDO MENGINTEGRASIKAN KINERJA, SISTEM, DAN LAYANAN DIGITAL SECARA REALTIME   '
                    '•   TERIMA KASIH ATAS KERJA SAMA DAN KEDISIPLINAN ANDA',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background Painter ─────────────────────────────────────────────────────────
class _ElegantBgPainter extends CustomPainter {
  final double progress;
  _ElegantBgPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFD4E8F6),
          Color(0xFFDCEFF9),
          Color(0xFFE6F3FB),
          Color(0xFFCEE4F3),
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Subtle diagonal grid lines
    final linePaint = Paint()
      ..color = const Color(0xFF1A4A8A).withOpacity(0.035)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 52.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height),
          linePaint);
    }

    // Large soft radial blobs
    void drawBlob(Offset center, double radius, Color color, double opacity) {
      final blobPaint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0.0)],
        ).createShader(
            Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, blobPaint);
    }

    drawBlob(
      Offset(size.width * 0.07, size.height * 0.14),
      size.width * 0.26,
      const Color(0xFF2563EB),
      0.07,
    );
    drawBlob(
      Offset(size.width * 0.87, size.height * 0.78),
      size.width * 0.30,
      const Color(0xFF0EA5E9),
      0.06,
    );
    drawBlob(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.22,
      const Color(0xFF1A4A8A),
      0.03,
    );

    // Animated floating circles
    final dotPaint = Paint()
      ..style = PaintingStyle.fill;

    final dots = [
      (Offset(size.width * 0.75, size.height * 0.10), 36.0),
      (Offset(size.width * 0.14, size.height * 0.78), 26.0),
      (Offset(size.width * 0.58, size.height * 0.90), 32.0),
      (Offset(size.width * 0.93, size.height * 0.42), 20.0),
    ];

    for (int i = 0; i < dots.length; i++) {
      final offset = math.sin((progress + i * 0.25) * 2 * math.pi) * 12;
      dotPaint.color =
          const Color(0xFF1A4A8A).withOpacity(0.05 + i * 0.01);
      canvas.drawCircle(
        Offset(dots[i].$1.dx, dots[i].$1.dy + offset),
        dots[i].$2,
        dotPaint,
      );
    }

    // Gold corner accents
    final cornerPaint = Paint()
      ..color = const Color(0xFFF59E0B).withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Top-right
    canvas.drawLine(
        Offset(size.width - 56, 18), Offset(size.width - 18, 18), cornerPaint);
    canvas.drawLine(
        Offset(size.width - 18, 18), Offset(size.width - 18, 56), cornerPaint);

    // Bottom-left
    canvas.drawLine(
        Offset(18, size.height - 18), Offset(56, size.height - 18), cornerPaint);
    canvas.drawLine(
        Offset(18, size.height - 56), Offset(18, size.height - 18), cornerPaint);
  }

  @override
  bool shouldRepaint(_ElegantBgPainter old) => old.progress != progress;
}

// ── Marquee ────────────────────────────────────────────────────────────────────
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _ctrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), _start);
    });
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!_ctrl.hasClients) return;
      final max = _ctrl.position.maxScrollExtent;
      final cur = _ctrl.offset;
      if (cur >= max) {
        _ctrl.jumpTo(0);
      } else {
        _ctrl.jumpTo(cur + 1.0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repeated =
        '${widget.text}          ${widget.text}          ${widget.text}';
    return SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(child: Text(repeated, style: widget.style)),
      ),
    );
  }
}