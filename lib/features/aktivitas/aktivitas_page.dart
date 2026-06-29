import 'package:flutter/material.dart';
import '../vehicle/detail_peminjaman_page.dart';
import '../ruang_meeting/detail_peminjaman_ruang_meeting_page.dart';
import '../gym/detail_peminjaman_gym_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AktivitasPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const AktivitasPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<AktivitasPage> createState() => _AktivitasPageState();
}

class _AktivitasPageState extends State<AktivitasPage>
    with SingleTickerProviderStateMixin {
  // ── Tab state ───────────────────────────────────────────────────────────────
  bool showOnGoing = true;

  // ── Filter jenis ────────────────────────────────────────────────────────────
  // 'SEMUA' | 'KENDARAAN' | 'MEETING' | 'GYM'
  String _filterJenis = 'SEMUA';

  // ── Loading ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;

  // ── Data kendaraan ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _kendaraanOnGoing = [];
  List<Map<String, dynamic>> _kendaraanHistory = [];

  // ── Data ruang meeting ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> _meetingOnGoing = [];
  List<Map<String, dynamic>> _meetingHistory = [];

  // ── Data gym ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _gymOnGoing = [];
  List<Map<String, dynamic>> _gymHistory = [];

  // ── Status aktif ────────────────────────────────────────────────────────────
  static const _kendaraanActiveStatuses = [
    'SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'ON_GOING'
  ];
  static const _meetingActiveStatuses = [
    'SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3'
  ];
  static const _gymActiveStatuses = ['PENDING', 'APPROVED'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─── Load All ───────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    await Future.wait([
      _fetchKendaraanOnGoing(),
      _fetchKendaraanHistory(),
      _fetchMeetingOnGoing(),
      _fetchMeetingHistory(),
      _fetchGymOnGoing(),
      _fetchGymHistory(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Kendaraan ──────────────────────────────────────────────────────────────

  Future<void> _fetchKendaraanOnGoing() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('peminjamId', isEqualTo: widget.userId)
          .where('status', whereIn: _kendaraanActiveStatuses)
          .get();

      final list = snapshot.docs
          .map((doc) => {'id': doc.id, 'jenis': 'KENDARAAN', ...doc.data()})
          .toList()
        ..sort((a, b) {
          final aT =
              (a['waktuPinjam'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bT =
              (b['waktuPinjam'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bT.compareTo(aT);
        });

      if (mounted) setState(() => _kendaraanOnGoing = list);
    } catch (e) {
      debugPrint('Error fetch kendaraan ongoing: $e');
      if (mounted) setState(() => _kendaraanOnGoing = []);
    }
  }

  Future<void> _fetchKendaraanHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('peminjamId', isEqualTo: widget.userId)
          .where('status', whereIn: ['DONE', 'CANCELLED'])
          .get();

      var list = snapshot.docs
          .map((doc) => {'id': doc.id, 'jenis': 'KENDARAAN', ...doc.data()})
          .toList()
        ..sort((a, b) {
          final aT =
              (a['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bT =
              (b['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bT.compareTo(aT);
        });

      if (list.length > 20) list = list.sublist(0, 20);
      if (mounted) setState(() => _kendaraanHistory = list);
    } catch (e) {
      debugPrint('Error fetch kendaraan history: $e');
      if (mounted) setState(() => _kendaraanHistory = []);
    }
  }

  // ─── Ruang Meeting ──────────────────────────────────────────────────────────

  Future<void> _fetchMeetingOnGoing() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('room_bookings')
          .where('peminjam.userId', isEqualTo: widget.userId)
          .where('status', whereIn: _meetingActiveStatuses)
          .get();

      final list = snapshot.docs
          .map((doc) => {'id': doc.id, 'jenis': 'MEETING', ...doc.data()})
          .toList()
        ..sort((a, b) {
          final aT =
              (a['waktuMulai'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bT =
              (b['waktuMulai'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bT.compareTo(aT);
        });

      if (mounted) setState(() => _meetingOnGoing = list);
    } catch (e) {
      debugPrint('Error fetch meeting ongoing: $e');
      if (mounted) setState(() => _meetingOnGoing = []);
    }
  }

  Future<void> _fetchMeetingHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('room_bookings')
          .where('peminjam.userId', isEqualTo: widget.userId)
          .where('status', whereIn: ['DONE', 'CANCELLED'])
          .get();

      var list = snapshot.docs
          .map((doc) => {'id': doc.id, 'jenis': 'MEETING', ...doc.data()})
          .toList()
        ..sort((a, b) {
          final aT =
              (a['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bT =
              (b['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bT.compareTo(aT);
        });

      if (list.length > 20) list = list.sublist(0, 20);
      if (mounted) setState(() => _meetingHistory = list);
    } catch (e) {
      debugPrint('Error fetch meeting history: $e');
      if (mounted) setState(() => _meetingHistory = []);
    }
  }

  // ─── Gym ────────────────────────────────────────────────────────────────────

  Future<void> _fetchGymOnGoing() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('gym_bookings')
          .where('peminjam.userId', isEqualTo: widget.userId)
          .where('status', whereIn: _gymActiveStatuses)
          .get();

      final list = snapshot.docs
          .map((doc) => {'id': doc.id, 'jenis': 'GYM', ...doc.data()})
          .toList()
        ..sort((a, b) {
          final aT =
              (a['waktuMulai'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bT =
              (b['waktuMulai'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bT.compareTo(aT);
        });

      if (mounted) setState(() => _gymOnGoing = list);
    } catch (e) {
      debugPrint('Error fetch gym ongoing: $e');
      if (mounted) setState(() => _gymOnGoing = []);
    }
  }

  Future<void> _fetchGymHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('gym_bookings')
          .where('peminjam.userId', isEqualTo: widget.userId)
          .where('status', whereIn: ['DONE', 'CANCELLED'])
          .get();

      var list = snapshot.docs
          .map((doc) => {'id': doc.id, 'jenis': 'GYM', ...doc.data()})
          .toList()
        ..sort((a, b) {
          final aT =
              (a['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bT =
              (b['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bT.compareTo(aT);
        });

      if (list.length > 20) list = list.sublist(0, 20);
      if (mounted) setState(() => _gymHistory = list);
    } catch (e) {
      debugPrint('Error fetch gym history: $e');
      if (mounted) setState(() => _gymHistory = []);
    }
  }

  // ─── Computed list berdasarkan filter ───────────────────────────────────────

  List<Map<String, dynamic>> get _activeList {
    final combined = <Map<String, dynamic>>[];

    if (_filterJenis == 'SEMUA' || _filterJenis == 'KENDARAAN') {
      combined.addAll(_kendaraanOnGoing);
    }
    if (_filterJenis == 'SEMUA' || _filterJenis == 'MEETING') {
      combined.addAll(_meetingOnGoing);
    }
    if (_filterJenis == 'SEMUA' || _filterJenis == 'GYM') {
      combined.addAll(_gymOnGoing);
    }

    combined.sort((a, b) {
      final aT = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bT = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bT.compareTo(aT);
    });

    return combined;
  }

  List<Map<String, dynamic>> get _historyList {
    final combined = <Map<String, dynamic>>[];

    if (_filterJenis == 'SEMUA' || _filterJenis == 'KENDARAAN') {
      combined.addAll(_kendaraanHistory);
    }
    if (_filterJenis == 'SEMUA' || _filterJenis == 'MEETING') {
      combined.addAll(_meetingHistory);
    }
    if (_filterJenis == 'SEMUA' || _filterJenis == 'GYM') {
      combined.addAll(_gymHistory);
    }

    combined.sort((a, b) {
      final aT = (a['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bT = (b['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bT.compareTo(aT);
    });

    return combined;
  }

  List<Map<String, dynamic>> get _currentList =>
      showOnGoing ? _activeList : _historyList;

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(ts.toDate());
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('HH:mm', 'id_ID').format(ts.toDate());
  }

  // ─── Status helpers ──────────────────────────────────────────────────────────

  String _getStatusText(String status) {
    switch (status) {
      case 'SUBMITTED':
        return 'Menunggu Approval';
      case 'APPROVAL_1':
        return 'Disetujui Manager Divisi';
      case 'APPROVAL_2':
        return 'Disetujui Operator';
      case 'APPROVAL_3':
        return 'Disetujui';
      case 'ON_GOING':
        return 'Sedang Digunakan';
      case 'DONE':
        return 'Selesai';
      case 'CANCELLED':
        return 'Dibatalkan';
      // ── Gym status ──
      case 'PENDING':
        return 'Menunggu Verifikasi';
      case 'APPROVED':
        return 'Disetujui Operator';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Colors.orange;
      case 'APPROVAL_1':
        return Colors.blue;
      case 'APPROVAL_2':
        return Colors.purple;
      case 'APPROVAL_3':
        return Colors.teal;
      case 'ON_GOING':
        return Colors.green.shade700;
      case 'DONE':
        return Colors.grey.shade600;
      case 'CANCELLED':
        return Colors.red;
      // ── Gym status ──
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final list = _currentList;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
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
                      Image.asset(
                        'assets/images/logo-pelindo.webp',
                        height: 28,
                        color: Colors.blue.shade800,
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade100,
                        ),
                        child: Icon(Icons.person_outline,
                            size: 24, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aktivitas',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Riwayat dan peminjaman aktif',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Tab Berlangsung / Riwayat ──────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildMainTab('Sedang Berlangsung', true),
                        _buildMainTab('Riwayat', false),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Filter Jenis ──────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildFilterChip('SEMUA', 'Semua', Icons.apps_rounded),
                      const SizedBox(width: 8),
                      _buildFilterChip('KENDARAAN', 'Kendaraan',
                          Icons.directions_car_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip('MEETING', 'Ruang Meeting',
                          Icons.meeting_room_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                          'GYM', 'Ruang Gym', Icons.fitness_center_outlined),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Summary Badge ─────────────────────────────────────
                if (!_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildSummaryBadges(),
                  ),

                const SizedBox(height: 16),

                // ── Content ───────────────────────────────────────────
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (list.isEmpty)
                  _buildEmptyState()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
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
                            const SizedBox(width: 12),
                            Text(
                              showOnGoing
                                  ? 'Peminjaman Aktif'
                                  : 'Riwayat Peminjaman',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${list.length} item',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...list.map((item) => _buildCard(item)).toList(),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Tab & Filter widgets ────────────────────────────────────────────────────

  Widget _buildMainTab(String label, bool isOnGoing) {
    final isSelected = showOnGoing == isOnGoing;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => showOnGoing = isOnGoing),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade700 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _filterJenis == value;
    return GestureDetector(
      onTap: () => setState(() => _filterJenis = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.blue.shade700
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBadges() {
    if (_filterJenis != 'SEMUA') return const SizedBox();

    final kendaraanCount =
        showOnGoing ? _kendaraanOnGoing.length : _kendaraanHistory.length;
    final meetingCount =
        showOnGoing ? _meetingOnGoing.length : _meetingHistory.length;
    final gymCount =
        showOnGoing ? _gymOnGoing.length : _gymHistory.length;

    if (kendaraanCount == 0 && meetingCount == 0 && gymCount == 0) {
      return const SizedBox();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (kendaraanCount > 0)
          _buildBadge(
            '$kendaraanCount Kendaraan',
            Icons.directions_car_outlined,
            Colors.blue.shade700,
            Colors.blue.shade50,
          ),
        if (meetingCount > 0)
          _buildBadge(
            '$meetingCount Ruang Meeting',
            Icons.meeting_room_outlined,
            Colors.teal.shade700,
            Colors.teal.shade50,
          ),
        if (gymCount > 0)
          _buildBadge(
            '$gymCount Ruang Gym',
            Icons.fitness_center_outlined,
            Colors.orange.shade700,
            Colors.orange.shade50,
          ),
      ],
    );
  }

  Widget _buildBadge(
      String label, IconData icon, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    if (_filterJenis == 'KENDARAAN') {
      message = showOnGoing
          ? 'Tidak ada peminjaman kendaraan aktif'
          : 'Belum ada riwayat peminjaman kendaraan';
    } else if (_filterJenis == 'MEETING') {
      message = showOnGoing
          ? 'Tidak ada peminjaman ruang meeting aktif'
          : 'Belum ada riwayat peminjaman ruang meeting';
    } else if (_filterJenis == 'GYM') {
      message = showOnGoing
          ? 'Tidak ada peminjaman ruang gym aktif'
          : 'Belum ada riwayat peminjaman ruang gym';
    } else {
      message = showOnGoing
          ? 'Tidak ada peminjaman yang sedang berlangsung'
          : 'Riwayat peminjaman akan muncul di sini';
    }

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.history_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Belum ada aktivitas',
            style: TextStyle(
                fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─── Card dispatcher ──────────────────────────────────────────────────────

  Widget _buildCard(Map<String, dynamic> item) {
    final jenis = item['jenis'] as String? ?? 'KENDARAAN';
    if (jenis == 'MEETING') return _buildMeetingCard(item);
    if (jenis == 'GYM') return _buildGymCard(item);
    return _buildKendaraanCard(item);
  }

  // ─── Kendaraan Card ───────────────────────────────────────────────────────

  Widget _buildKendaraanCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'UNKNOWN';
    final waktuPinjam = item['waktuPinjam'] as Timestamp?;
    final waktuKembali = item['waktuKembali'] as Timestamp?;
    final vehicle = item['vehicle'] as Map<String, dynamic>?;
    final vehicleDisplay = vehicle != null
        ? '${vehicle['nama']} (${vehicle['platNomor']})'
        : 'Kendaraan belum ditentukan';
    final keperluan = item['keperluan'] ?? '-';
    final tujuan = item['tujuan'] ?? '-';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanPage(
            data: item,
            approvalStep: 0,
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: false,
          ),
        ),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _cardIcon(Icons.directions_car_filled_outlined,
                    Colors.blue.shade700, Colors.blue.shade50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peminjaman Kendaraan',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                      Text(
                        _formatDate(waktuPinjam),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(statusText, statusColor),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 14),
            _buildDetailRow(
                Icons.directions_car_outlined, 'Kendaraan', vehicleDisplay),
            const SizedBox(height: 10),
            _buildDetailRow(
                Icons.schedule_outlined,
                'Waktu',
                '${_formatTime(waktuPinjam)} — ${_formatTime(waktuKembali)}, ${_formatDate(waktuKembali)}'),
            const SizedBox(height: 10),
            _buildDetailRow(
                Icons.assignment_outlined, 'Keperluan', keperluan),
            const SizedBox(height: 10),
            _buildDetailRow(
                Icons.location_on_outlined, 'Tujuan', tujuan),
            if (status == 'ON_GOING' ||
                ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3']
                    .contains(status)) ...[
              const SizedBox(height: 16),
              _buildLihatDetailButton(() {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailPeminjamanPage(
                      data: item,
                      approvalStep: 0,
                      role: widget.role,
                      userName: widget.userName,
                      userId: widget.userId,
                      userDivision: widget.userDivision,
                      isApprovalMode: false,
                      isReturn: status == 'ON_GOING',
                    ),
                  ),
                ).then((_) => _loadData());
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Ruang Meeting Card ───────────────────────────────────────────────────

  Widget _buildMeetingCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'UNKNOWN';
    final waktuMulai = item['waktuMulai'] as Timestamp?;
    final waktuSelesai = item['waktuSelesai'] as Timestamp?;
    final namaKegiatan = item['namaKegiatan'] ?? '-';
    final jenisRapat = item['jenisRapat'] ?? '-';
    final peserta = item['peserta'] ?? '-';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanRuangMeetingPage(
            data: item,
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: false,
          ),
        ),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _cardIcon(Icons.meeting_room_outlined,
                    Colors.teal.shade700, Colors.teal.shade50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peminjaman Ruang Meeting',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                      Text(
                        namaKegiatan,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _statusBadge(statusText, statusColor),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 14),
            _buildDetailRow(
              Icons.schedule_outlined,
              'Waktu',
              '${_formatDate(waktuMulai)}, ${_formatTime(waktuMulai)} — ${_formatTime(waktuSelesai)}',
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
                Icons.people_outline, 'Peserta', '$peserta orang'),
            const SizedBox(height: 10),
            _buildDetailRow(
                Icons.video_call_outlined, 'Jenis Rapat', jenisRapat),
            const SizedBox(height: 12),
            _buildJenisRapatBadge(jenisRapat),
            if (['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3']
                .contains(status)) ...[
              const SizedBox(height: 16),
              _buildLihatDetailButton(() {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailPeminjamanRuangMeetingPage(
                      data: item,
                      role: widget.role,
                      userName: widget.userName,
                      userId: widget.userId,
                      userDivision: widget.userDivision,
                      isApprovalMode: false,
                    ),
                  ),
                ).then((_) => _loadData());
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Gym Card ─────────────────────────────────────────────────────────────

  Widget _buildGymCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'UNKNOWN';
    final waktuMulai = item['waktuMulai'] as Timestamp?;
    final waktuSelesai = item['waktuSelesai'] as Timestamp?;
    final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
    final catatan = (item['catatan'] ?? '').toString();
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanGymPage(
            data: item,
            role: widget.role,
            userName: widget.userName,
            userId: widget.userId,
            userDivision: widget.userDivision,
            isApprovalMode: false,
          ),
        ),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────
            Row(
              children: [
                _cardIcon(Icons.fitness_center_outlined,
                    Colors.orange.shade700, Colors.orange.shade50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peminjaman Ruang Gym',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                      Text(
                        _formatDate(waktuMulai),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(statusText, statusColor),
              ],
            ),

            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 14),

            // ── Detail rows ───────────────────────────────────────
            _buildDetailRow(
              Icons.schedule_outlined,
              'Waktu',
              '${_formatDate(waktuMulai)}, ${_formatTime(waktuMulai)} — ${_formatTime(waktuSelesai)}',
            ),
            if (catatan.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDetailRow(
                  Icons.notes_outlined, 'Catatan', catatan),
            ],

            // ── Status badge gym ──────────────────────────────────
            const SizedBox(height: 12),
            _buildGymStatusBadge(status),

            // ── Lihat detail button ───────────────────────────────
            if (['PENDING', 'APPROVED'].contains(status)) ...[
              const SizedBox(height: 16),
              _buildLihatDetailButton(() {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailPeminjamanGymPage(
                      data: item,
                      role: widget.role,
                      userName: widget.userName,
                      userId: widget.userId,
                      userDivision: widget.userDivision,
                      isApprovalMode: false,
                    ),
                  ),
                ).then((_) => _loadData());
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Shared Card Helpers ──────────────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _cardIcon(IconData icon, Color iconColor, Color bgColor) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJenisRapatBadge(String jenis) {
    IconData icon;
    Color color;
    switch (jenis.toUpperCase()) {
      case 'ONLINE':
        icon = Icons.videocam_outlined;
        color = Colors.blue.shade600;
        break;
      case 'HYBRID':
        icon = Icons.devices_outlined;
        color = Colors.purple.shade600;
        break;
      default:
        icon = Icons.people_outline;
        color = Colors.teal.shade600;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                jenis.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGymStatusBadge(String status) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case 'PENDING':
        icon = Icons.hourglass_empty_rounded;
        color = Colors.orange.shade600;
        label = 'Menunggu Verifikasi Operator';
        break;
      case 'APPROVED':
        icon = Icons.check_circle_outline_rounded;
        color = Colors.green.shade700;
        label = 'Siap Digunakan';
        break;
      case 'DONE':
        icon = Icons.check_circle;
        color = Colors.grey.shade600;
        label = 'Selesai';
        break;
      case 'CANCELLED':
        icon = Icons.cancel;
        color = Colors.red;
        label = 'Dibatalkan';
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLihatDetailButton(VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.info_outline_rounded, size: 18),
        label: const Text(
          'Lihat Detail',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}