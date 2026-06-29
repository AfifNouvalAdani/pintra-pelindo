import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';

import '../ruang_meeting/detail_peminjaman_ruang_meeting_page.dart';

class LaporanPeminjamanRuangMeetingPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const LaporanPeminjamanRuangMeetingPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<LaporanPeminjamanRuangMeetingPage> createState() =>
      _LaporanPeminjamanRuangMeetingPageState();
}

class _LaporanPeminjamanRuangMeetingPageState
    extends State<LaporanPeminjamanRuangMeetingPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _laporanList = [];
  String _searchQuery = '';

  // ─── Filter State ───
  String _selectedPeriode = 'SEMUA';
  DateTimeRange? _customDateRange;
  String _selectedRuang = 'SEMUA';
  String _selectedJenisRapat = 'SEMUA';
  String _selectedDivisi = 'SEMUA';
  String _sortOrder = 'TERBARU';
  bool _isExporting = false;

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _periodeOptions = [
    {'key': 'SEMUA', 'label': 'Semua Waktu'},
    {'key': '1_MINGGU', 'label': '1 Minggu'},
    {'key': '1_BULAN', 'label': '1 Bulan'},
    {'key': '3_BULAN', 'label': '3 Bulan'},
    {'key': '6_BULAN', 'label': '6 Bulan'},
    {'key': '1_TAHUN', 'label': '1 Tahun'},
    {'key': 'CUSTOM', 'label': 'Kustom'},
  ];

  // ✅ FIX 1: Jenis rapat disesuaikan dengan nilai aktual di Firestore
  // Form menyimpan: 'OFFLINE', 'ONLINE', 'HYBRID'
  final List<Map<String, String>> _jenisRapatOptions = [
    {'key': 'SEMUA', 'label': 'Semua Jenis'},
    {'key': 'OFFLINE', 'label': 'Offline'},
    {'key': 'ONLINE', 'label': 'Online'},
    {'key': 'HYBRID', 'label': 'Hybrid'},
  ];

  List<String> _ruangOptions = ['SEMUA'];
  List<String> _divisiOptions = ['SEMUA'];
  // ✅ FIX 2: Cache nilai jenisRapat unik dari data aktual
  Set<String> _jenisRapatDiData = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _loadLaporan();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Helper: Ambil namaRuang dengan fallback berlapis ───
  // ✅ FIX 3: Data lama mungkin simpan namaRuang di root, bukan di ruang.namaRuang
  String _getNamaRuang(Map<String, dynamic> item) {
    // Prioritas 1: ruang.namaRuang (struktur baru)
    final ruangMap = item['ruang'] as Map<String, dynamic>?;
    final namaRuangNested = ruangMap?['namaRuang']?.toString() ?? '';
    if (namaRuangNested.isNotEmpty) return namaRuangNested;

    // Prioritas 2: namaRuang di root level (field tambahan dari form)
    final namaRuangRoot = item['namaRuang']?.toString() ?? '';
    if (namaRuangRoot.isNotEmpty) return namaRuangRoot;

    // Prioritas 3: coba ambil dari roomId via nama room yang tersimpan
    return 'Ruang Tidak Diketahui';
  }

  String _getLokasi(Map<String, dynamic> item) {
    final ruangMap = item['ruang'] as Map<String, dynamic>?;
    final lokasiNested = ruangMap?['lokasi']?.toString() ?? '';
    if (lokasiNested.isNotEmpty) return lokasiNested;
    return item['lokasiRuang']?.toString() ?? '';
  }

  // ─── Load Data ───
  // ✅ FIX 4: Ambil status DONE dan ON_GOING (yang mungkin sudah selesai tapi belum di-update)
  Future<void> _loadLaporan() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Query DONE — status utama laporan yang selesai
      QuerySnapshot snapshotDone;
      QuerySnapshot snapshotOnGoing;

      if (widget.role == 'user') {
        snapshotDone = await FirebaseFirestore.instance
            .collection('room_bookings')
            .where('status', isEqualTo: 'DONE')
            .where('peminjam.userId', isEqualTo: widget.userId)
            .get();
        snapshotOnGoing = await FirebaseFirestore.instance
            .collection('room_bookings')
            .where('status', isEqualTo: 'ON_GOING')
            .where('peminjam.userId', isEqualTo: widget.userId)
            .get();
      } else {
        snapshotDone = await FirebaseFirestore.instance
            .collection('room_bookings')
            .where('status', isEqualTo: 'DONE')
            .get();
        snapshotOnGoing = await FirebaseFirestore.instance
            .collection('room_bookings')
            .where('status', isEqualTo: 'ON_GOING')
            .get();
      }

      // Gabung DONE + ON_GOING yang waktuSelesai sudah lewat
      final now = DateTime.now();
      final List<Map<String, dynamic>> allDocs = [];

      for (final doc in snapshotDone.docs) {
        allDocs.add({'id': doc.id, ...doc.data() as Map<String, dynamic>});
      }

      for (final doc in snapshotOnGoing.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final waktuSelesai = (data['waktuSelesai'] as Timestamp?)?.toDate();
        // Masukkan ke laporan jika waktu selesai sudah lewat
        if (waktuSelesai != null && waktuSelesai.isBefore(now)) {
          allDocs.add({'id': doc.id, '_displayAsDone': true, ...data});
        }
      }

      // ✅ FIX 5: Enrich data — pastikan namaRuang selalu ada
      // Kumpulkan roomId yang namaRuang-nya kosong untuk di-fetch
      final roomIdsToFetch = <String>{};
      for (final item in allDocs) {
        final namaRuang = _getNamaRuang(item);
        if (namaRuang == 'Ruang Tidak Diketahui') {
          final ruangMap = item['ruang'] as Map<String, dynamic>?;
          final roomId = ruangMap?['roomId']?.toString() ?? '';
          if (roomId.isNotEmpty) roomIdsToFetch.add(roomId);
        }
      }

      // Fetch room data yang belum ada namanya
      final Map<String, String> roomNameCache = {};
      final Map<String, String> roomLokasiCache = {};
      for (final roomId in roomIdsToFetch) {
        try {
          final roomDoc = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomId)
              .get();
          if (roomDoc.exists) {
            final roomData = roomDoc.data()!;
            roomNameCache[roomId] = roomData['namaRuang']?.toString() ?? '-';
            roomLokasiCache[roomId] = roomData['lokasi']?.toString() ?? '-';
          }
        } catch (_) {}
      }

      // Terapkan cache ke data
      final List<Map<String, dynamic>> enrichedDocs = allDocs.map((item) {
        final ruangMap = item['ruang'] as Map<String, dynamic>?;
        final roomId = ruangMap?['roomId']?.toString() ?? '';
        if (roomNameCache.containsKey(roomId)) {
          final enriched = Map<String, dynamic>.from(item);
          enriched['ruang'] = {
            ...(ruangMap ?? {}),
            'namaRuang': roomNameCache[roomId]!,
            'lokasi': roomLokasiCache[roomId] ?? '-',
          };
          return enriched;
        }
        return item;
      }).toList();

      // Kumpulkan opsi filter dari data yang sudah di-enrich
      final ruangSet = <String>{};
      final divisiSet = <String>{};
      final jenisRapatSet = <String>{};

      for (final item in enrichedDocs) {
        final namaRuang = _getNamaRuang(item);
        if (namaRuang != 'Ruang Tidak Diketahui') ruangSet.add(namaRuang);

        final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
        final divisi = peminjam['divisi']?.toString() ?? '';
        if (divisi.isNotEmpty) divisiSet.add(divisi);

        final jenisRapat = (item['jenisRapat'] ?? '').toString().toUpperCase().trim();
        if (jenisRapat.isNotEmpty) jenisRapatSet.add(jenisRapat);
      }

      if (mounted) {
        setState(() {
          _laporanList = enrichedDocs;
          _ruangOptions = ['SEMUA', ...ruangSet.toList()..sort()];
          _divisiOptions = ['SEMUA', ...divisiSet.toList()..sort()];
          _jenisRapatDiData = jenisRapatSet;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading laporan ruang meeting: $e');
      if (mounted) {
        _showSnackbar('Error memuat data laporan: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Filter Logic ───
  List<Map<String, dynamic>> get _filteredLaporan {
    List<Map<String, dynamic>> result = List.from(_laporanList);

    // Filter periode — gunakan waktuMulai sebagai acuan, bukan createdAt
    if (_selectedPeriode != 'SEMUA') {
      DateTime? fromDate;
      DateTime? toDate;
      final now = DateTime.now();

      if (_selectedPeriode == 'CUSTOM' && _customDateRange != null) {
        // Custom: inklusif di kedua ujung, bandingkan dengan waktuMulai
        final startOfDay = DateTime(
            _customDateRange!.start.year,
            _customDateRange!.start.month,
            _customDateRange!.start.day);
        final endOfDay = DateTime(
            _customDateRange!.end.year,
            _customDateRange!.end.month,
            _customDateRange!.end.day,
            23, 59, 59);
        result = result.where((item) {
          final ts = (item['waktuMulai'] as Timestamp?) ??
              (item['createdAt'] as Timestamp?);
          if (ts == null) return false;
          final date = ts.toDate();
          return date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
              date.isBefore(endOfDay.add(const Duration(seconds: 1)));
        }).toList();
        return _sortList(result); // langsung return setelah custom filter
      }

      switch (_selectedPeriode) {
        case '1_MINGGU':
          fromDate = now.subtract(const Duration(days: 7));
          break;
        case '1_BULAN':
          fromDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case '3_BULAN':
          fromDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case '6_BULAN':
          fromDate = DateTime(now.year, now.month - 6, now.day);
          break;
        case '1_TAHUN':
          fromDate = DateTime(now.year - 1, now.month, now.day);
          break;
      }

      if (fromDate != null) {
        result = result.where((item) {
          final ts = (item['waktuMulai'] as Timestamp?) ??
              (item['createdAt'] as Timestamp?);
          if (ts == null) return false;
          return ts.toDate().isAfter(fromDate!.subtract(const Duration(seconds: 1)));
        }).toList();
      }
    }

    // ✅ FIX 6: Filter ruang — gunakan _getNamaRuang() agar konsisten
    if (_selectedRuang != 'SEMUA') {
      result = result.where((item) {
        return _getNamaRuang(item) == _selectedRuang;
      }).toList();
    }

    // ✅ FIX 7: Filter jenis rapat — exact match case-insensitive, bukan contains
    if (_selectedJenisRapat != 'SEMUA') {
      result = result.where((item) {
        final jenisRapat =
            (item['jenisRapat'] ?? '').toString().toUpperCase().trim();
        return jenisRapat == _selectedJenisRapat.toUpperCase();
      }).toList();
    }

    // Filter divisi
    if (_selectedDivisi != 'SEMUA' && widget.role != 'user') {
      result = result.where((item) {
        final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
        return (peminjam['divisi']?.toString() ?? '') == _selectedDivisi;
      }).toList();
    }

    // Search bar — inklusif semua field penting
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      result = result.where((item) {
        final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
        final namaRuang = _getNamaRuang(item).toLowerCase();
        final lokasi = _getLokasi(item).toLowerCase();
        final nama = (peminjam['nama'] ?? '').toString().toLowerCase();
        final divisi = (peminjam['divisi'] ?? '').toString().toLowerCase();
        final namaKegiatan =
            (item['namaKegiatan'] ?? '').toString().toLowerCase();
        final jenisRapat =
            (item['jenisRapat'] ?? '').toString().toLowerCase();
        final peserta = (item['peserta'] ?? '').toString().toLowerCase();
        return nama.contains(q) ||
            divisi.contains(q) ||
            namaRuang.contains(q) ||
            lokasi.contains(q) ||
            namaKegiatan.contains(q) ||
            jenisRapat.contains(q) ||
            peserta.contains(q);
      }).toList();
    }

    return _sortList(result);
  }

  List<Map<String, dynamic>> _sortList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      // Gunakan waktuMulai sebagai primary sort, createdAt sebagai fallback
      final tsA = ((a['waktuMulai'] as Timestamp?) ??
              (a['createdAt'] as Timestamp?))
          ?.toDate() ??
          DateTime(2000);
      final tsB = ((b['waktuMulai'] as Timestamp?) ??
              (b['createdAt'] as Timestamp?))
          ?.toDate() ??
          DateTime(2000);
      return _sortOrder == 'TERBARU' ? tsB.compareTo(tsA) : tsA.compareTo(tsB);
    });
    return list;
  }

  // ─── Active Filter Count ───
  int get _activeFilterCount {
    int count = 0;
    if (_selectedPeriode != 'SEMUA') count++;
    if (_selectedRuang != 'SEMUA') count++;
    if (_selectedJenisRapat != 'SEMUA') count++;
    if (_selectedDivisi != 'SEMUA') count++;
    if (_sortOrder != 'TERBARU') count++;
    return count;
  }

  // ─── Helpers ───
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(ts.toDate());
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(ts.toDate());
  }

  String _formatTimeOnly(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('HH:mm').format(ts.toDate());
  }

  String _formatDateRange(DateTimeRange range) {
    final fmt = DateFormat('dd/MM/yy');
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }

  int _hitungDurasi(Timestamp? mulai, Timestamp? selesai) {
    if (mulai == null || selesai == null) return 0;
    return selesai
        .toDate()
        .difference(mulai.toDate())
        .inMinutes
        .clamp(0, 99999);
  }

  String _durasiLabel(int menit) {
    if (menit <= 0) return '-';
    final jam = menit ~/ 60;
    final sisa = menit % 60;
    if (jam == 0) return '${sisa}m';
    if (sisa == 0) return '${jam}j';
    return '${jam}j ${sisa}m';
  }

  // ✅ FIX 8: Warna sesuai nilai aktual Firestore (OFFLINE/ONLINE/HYBRID)
  Color _jenisRapatColor(String jenisRapat) {
    switch (jenisRapat.toUpperCase().trim()) {
      case 'OFFLINE':
        return Colors.blue.shade600;
      case 'ONLINE':
        return Colors.green.shade600;
      case 'HYBRID':
        return Colors.teal.shade600;
      default:
        return Colors.orange.shade600;
    }
  }

  String _jenisRapatLabel(String jenisRapat) {
    switch (jenisRapat.toUpperCase().trim()) {
      case 'OFFLINE':
        return 'Offline';
      case 'ONLINE':
        return 'Online';
      case 'HYBRID':
        return 'Hybrid';
      default:
        return jenisRapat;
    }
  }

  // ─── Export Dialog ───
  void _showExportDialog() {
    final filtered = _filteredLaporan;
    if (filtered.isEmpty) {
      _showSnackbar('Tidak ada data untuk diekspor', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              'Ekspor Laporan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${filtered.length} data akan diekspor${_activeFilterCount > 0 ? ' (filter aktif)' : ''}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            _buildExportOption(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Ekspor sebagai PDF',
              subtitle: 'Format laporan siap cetak',
              color: Colors.red.shade600,
              onTap: () {
                Navigator.pop(context);
                _exportToPdf(filtered);
              },
            ),
            const SizedBox(height: 12),
            _buildExportOption(
              icon: Icons.table_chart_rounded,
              label: 'Ekspor sebagai Excel',
              subtitle: 'Format spreadsheet (.xlsx)',
              color: Colors.green.shade700,
              onTap: () {
                Navigator.pop(context);
                _exportToExcel(filtered);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  String _getFilterDesc() {
    if (_activeFilterCount == 0) return 'Semua Data';
    final parts = <String>[];
    if (_selectedPeriode != 'SEMUA') {
      parts.add(_selectedPeriode == 'CUSTOM' && _customDateRange != null
          ? _formatDateRange(_customDateRange!)
          : _periodeOptions.firstWhere((e) => e['key'] == _selectedPeriode,
                  orElse: () => {'label': _selectedPeriode})['label'] ??
              _selectedPeriode);
    }
    if (_selectedRuang != 'SEMUA') parts.add(_selectedRuang);
    if (_selectedJenisRapat != 'SEMUA') {
      parts.add(_jenisRapatLabel(_selectedJenisRapat));
    }
    if (_selectedDivisi != 'SEMUA') parts.add(_selectedDivisi);
    return parts.join(' | ');
  }

  // ─── Export PDF ───
  Future<void> _exportToPdf(List<Map<String, dynamic>> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      _showSnackbar('Membuat PDF...');
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      final rows = data.map((item) {
        final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
        final namaRuang = _getNamaRuang(item);
        final lokasi = _getLokasi(item);
        final nama = peminjam['nama']?.toString() ?? '-';
        final divisi = peminjam['divisi']?.toString() ?? '-';
        final namaKegiatan = item['namaKegiatan']?.toString() ?? '-';
        final jenisRapat = item['jenisRapat']?.toString() ?? '-';
        final peserta = item['peserta']?.toString() ?? '-';
        final waktuMulai = item['waktuMulai'] as Timestamp?;
        final waktuSelesai = item['waktuSelesai'] as Timestamp?;
        final durasi = _hitungDurasi(waktuMulai, waktuSelesai);

        final tglMulai = waktuMulai != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(waktuMulai.toDate())
            : '-';
        final tglSelesai = waktuSelesai != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(waktuSelesai.toDate())
            : '-';

        return [
          nama,
          divisi,
          lokasi.isNotEmpty ? '$namaRuang\n$lokasi' : namaRuang,
          namaKegiatan,
          jenisRapat,
          '$tglMulai\ns/d\n$tglSelesai',
          '$peserta org',
          _durasiLabel(durasi),
        ];
      }).toList();

      const int rowsPerPage = 15;
      final chunks = <List<List<String>>>[];
      for (int i = 0; i < rows.length; i += rowsPerPage) {
        chunks.add(rows.sublist(
            i, i + rowsPerPage > rows.length ? rows.length : i + rowsPerPage));
      }

      for (int pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
        final chunk = chunks[pageIdx];
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'LAPORAN PEMINJAMAN RUANG MEETING',
                            style: pw.TextStyle(font: fontBold, fontSize: 14),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Filter: ${_getFilterDesc()}',
                            style: pw.TextStyle(
                                font: font,
                                fontSize: 9,
                                color: PdfColors.grey700),
                          ),
                          pw.Text(
                            'Dicetak: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                            style: pw.TextStyle(
                                font: font,
                                fontSize: 9,
                                color: PdfColors.grey700),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Halaman ${pageIdx + 1}/${chunks.length}',
                        style: pw.TextStyle(
                            font: font, fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(thickness: 1.5, color: PdfColors.teal800),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.0),
                      1: const pw.FlexColumnWidth(1.8),
                      2: const pw.FlexColumnWidth(2.0),
                      3: const pw.FlexColumnWidth(2.2),
                      4: const pw.FlexColumnWidth(1.2),
                      5: const pw.FlexColumnWidth(2.0),
                      6: const pw.FlexColumnWidth(0.9),
                      7: const pw.FlexColumnWidth(0.9),
                    },
                    children: [
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.teal800),
                        children: [
                          'Peminjam',
                          'Divisi',
                          'Ruang',
                          'Nama Kegiatan',
                          'Jenis',
                          'Waktu',
                          'Peserta',
                          'Durasi',
                        ]
                            .map((h) => pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 6),
                                  child: pw.Text(h,
                                      style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: 9,
                                        color: PdfColors.white,
                                      )),
                                ))
                            .toList(),
                      ),
                      ...chunk.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final row = entry.value;
                        final bgColor =
                            idx.isEven ? PdfColors.grey50 : PdfColors.white;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: bgColor),
                          children: row
                              .map((cell) => pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 5),
                                    child: pw.Text(cell,
                                        style: pw.TextStyle(
                                            font: font, fontSize: 8)),
                                  ))
                              .toList(),
                        );
                      }).toList(),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  if (pageIdx == chunks.length - 1) ...[
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    pw.Text(
                      'Total: ${data.length} peminjaman',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }

      final pdfBytes = await pdf.save();
      final fileName =
          'laporan_ruang_meeting_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      debugPrint('❌ Error export PDF: $e');
      if (mounted) _showSnackbar('Gagal membuat PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── Export Excel ───
  Future<void> _exportToExcel(List<Map<String, dynamic>> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      _showSnackbar('Membuat Excel...');
      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Laporan Ruang Meeting');
      final sheet = excel['Laporan Ruang Meeting'];

      CellStyle headerStyle() => CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#00796B'),
            fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
            horizontalAlign: HorizontalAlign.Center,
            verticalAlign: VerticalAlign.Center,
            textWrapping: TextWrapping.WrapText,
          );

      CellStyle dataStyle(bool isEven) => CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(
                isEven ? '#F5F5F5' : '#FFFFFF'),
            verticalAlign: VerticalAlign.Center,
            textWrapping: TextWrapping.WrapText,
          );

      CellStyle boldDataStyle(bool isEven) => CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString(
                isEven ? '#F5F5F5' : '#FFFFFF'),
            verticalAlign: VerticalAlign.Center,
          );

      // Judul
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('L1'));
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('LAPORAN PEMINJAMAN RUANG MEETING');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      sheet.setRowHeight(0, 30);

      // Filter
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('L2'));
      sheet.cell(CellIndex.indexByString('A2')).value =
          TextCellValue('Filter: ${_getFilterDesc()}');
      sheet.setRowHeight(1, 20);

      // Tanggal cetak
      sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('L3'));
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
          'Dicetak: ${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now())}');
      sheet.setRowHeight(2, 18);

      // Kosong
      sheet.setRowHeight(3, 10);

      // Header tabel
      final headers = [
        'No',
        'Nama Peminjam',
        'Divisi',
        'Jabatan',
        'Ruang Meeting',
        'Lokasi Ruang',
        'Nama Kegiatan',
        'Jenis Rapat',
        'Tgl & Jam Mulai',
        'Tgl & Jam Selesai',
        'Peserta (org)',
        'Durasi',
      ];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle();
      }
      sheet.setRowHeight(4, 28);

      // Data rows
      for (int rowIdx = 0; rowIdx < data.length; rowIdx++) {
        final item = data[rowIdx];
        final isEven = rowIdx.isEven;
        final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
        final namaRuang = _getNamaRuang(item);
        final lokasi = _getLokasi(item);
        final nama = peminjam['nama']?.toString() ?? '-';
        final divisi = peminjam['divisi']?.toString() ?? '-';
        final jabatan = peminjam['jabatan']?.toString() ?? '-';
        final namaKegiatan = item['namaKegiatan']?.toString() ?? '-';
        final jenisRapat = item['jenisRapat']?.toString() ?? '-';
        final waktuMulai = item['waktuMulai'] as Timestamp?;
        final waktuSelesai = item['waktuSelesai'] as Timestamp?;
        final peserta = item['peserta']?.toString() ?? '-';
        final durasi = _hitungDurasi(waktuMulai, waktuSelesai);

        final rowData = [
          (rowIdx + 1).toString(),
          nama,
          divisi,
          jabatan,
          namaRuang,
          lokasi.isNotEmpty ? lokasi : '-',
          namaKegiatan,
          jenisRapat,
          waktuMulai != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(waktuMulai.toDate())
              : '-',
          waktuSelesai != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(waktuSelesai.toDate())
              : '-',
          peserta,
          _durasiLabel(durasi),
        ];

        for (int colIdx = 0; colIdx < rowData.length; colIdx++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: colIdx,
            rowIndex: rowIdx + 5,
          ));
          cell.value = TextCellValue(rowData[colIdx]);
          cell.cellStyle =
              colIdx == 0 ? boldDataStyle(isEven) : dataStyle(isEven);
        }
        sheet.setRowHeight(rowIdx + 5, 22);
      }

      // Baris total
      final totalRowIdx = data.length + 5;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRowIdx),
        CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: totalRowIdx),
      );
      final totalCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRowIdx));
      totalCell.value = TextCellValue('Total: ${data.length} peminjaman');
      totalCell.cellStyle = CellStyle(bold: true);

      final colWidths = [
        5.0, 22.0, 18.0, 18.0, 20.0, 16.0, 24.0, 12.0, 18.0, 18.0, 12.0, 10.0
      ];
      for (int i = 0; i < colWidths.length; i++) {
        sheet.setColumnWidth(i, colWidths[i]);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Gagal menyimpan excel');

      final fileName =
          'laporan_ruang_meeting_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(fileBytes),
            name: fileName,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Laporan Peminjaman Ruang Meeting',
      );
    } catch (e) {
      debugPrint('❌ Error export Excel: $e');
      if (mounted) _showSnackbar('Gagal membuat Excel: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── Filter Sheet ───
  void _showFilterSheet() {
    // ✅ FIX 9: Kirim _jenisRapatDiData ke filter sheet agar
    // opsi jenis rapat dinamis sesuai data aktual
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterBottomSheetMeeting(
        selectedPeriode: _selectedPeriode,
        customDateRange: _customDateRange,
        selectedRuang: _selectedRuang,
        selectedJenisRapat: _selectedJenisRapat,
        selectedDivisi: _selectedDivisi,
        sortOrder: _sortOrder,
        periodeOptions: _periodeOptions,
        // Hanya tampilkan opsi jenis rapat yang benar-benar ada di data
        jenisRapatOptions: _jenisRapatOptions
            .where((opt) =>
                opt['key'] == 'SEMUA' ||
                _jenisRapatDiData.contains(opt['key']))
            .toList(),
        ruangOptions: _ruangOptions,
        divisiOptions: _divisiOptions,
        showDivisi: widget.role != 'user',
        onApply: (periode, customRange, ruang, jenisRapat, divisi, sort) {
          if (mounted) {
            setState(() {
              _selectedPeriode = periode;
              _customDateRange = customRange;
              _selectedRuang = ruang;
              _selectedJenisRapat = jenisRapat;
              _selectedDivisi = divisi;
              _sortOrder = sort;
            });
          }
        },
        onPickDateRange: () async {
          Navigator.of(context).pop();
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          await _pickCustomDateRange();
        },
      ),
    );
  }

  Future<void> _pickCustomDateRange() async {
    if (!mounted) return;
    final pickedStart = await showDatePicker(
      context: context,
      initialDate: _customDateRange?.start ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
    );
    if (pickedStart == null || !mounted) return;

    final pickedEnd = await showDatePicker(
      context: context,
      initialDate:
          _customDateRange?.end ?? pickedStart.add(const Duration(days: 1)),
      firstDate: pickedStart,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
    );
    if (pickedEnd == null || !mounted) return;

    setState(() {
      _customDateRange = DateTimeRange(start: pickedStart, end: pickedEnd);
      _selectedPeriode = 'CUSTOM';
    });
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLaporan;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLaporan,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.grey.shade700, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/images/logo-pelindo.webp',
                        height: 28,
                        color: Colors.teal.shade800,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showExportDialog,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Icon(Icons.download_rounded,
                              size: 20, color: Colors.green.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal.shade100,
                        ),
                        child: Icon(Icons.meeting_room_outlined,
                            size: 22, color: Colors.teal.shade800),
                      ),
                    ],
                  ),
                ),

                // ── Title ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laporan Ruang Meeting',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Riwayat peminjaman ruang meeting yang telah selesai',
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Search + Filter ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            if (mounted) setState(() => _searchQuery = val);
                          },
                          decoration: InputDecoration(
                            hintText: 'Cari nama, ruang, kegiatan...',
                            prefixIcon:
                                Icon(Icons.search, color: Colors.grey.shade600),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close,
                                        color: Colors.grey.shade500, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      if (mounted)
                                        setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            hintStyle: TextStyle(
                                fontSize: 14, color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _activeFilterCount > 0
                                ? Colors.teal.shade700
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _activeFilterCount > 0
                                  ? Colors.teal.shade700
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: _activeFilterCount > 0
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                size: 22,
                              ),
                              if (_activeFilterCount > 0)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$_activeFilterCount',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
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

                // ── Active Filter Chips ──
                if (_activeFilterCount > 0) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        if (_selectedPeriode != 'SEMUA')
                          _buildActiveChip(
                            label: _selectedPeriode == 'CUSTOM' &&
                                    _customDateRange != null
                                ? _formatDateRange(_customDateRange!)
                                : _periodeOptions.firstWhere(
                                    (e) => e['key'] == _selectedPeriode,
                                    orElse: () =>
                                        {'label': _selectedPeriode})['label']!,
                            onRemove: () {
                              if (mounted)
                                setState(() {
                                  _selectedPeriode = 'SEMUA';
                                  _customDateRange = null;
                                });
                            },
                          ),
                        if (_selectedRuang != 'SEMUA')
                          _buildActiveChip(
                            label: _selectedRuang,
                            onRemove: () {
                              if (mounted)
                                setState(() => _selectedRuang = 'SEMUA');
                            },
                          ),
                        if (_selectedJenisRapat != 'SEMUA')
                          _buildActiveChip(
                            label: _jenisRapatLabel(_selectedJenisRapat),
                            onRemove: () {
                              if (mounted)
                                setState(() => _selectedJenisRapat = 'SEMUA');
                            },
                          ),
                        if (_selectedDivisi != 'SEMUA')
                          _buildActiveChip(
                            label: _selectedDivisi,
                            onRemove: () {
                              if (mounted)
                                setState(() => _selectedDivisi = 'SEMUA');
                            },
                          ),
                        if (_sortOrder != 'TERBARU')
                          _buildActiveChip(
                            label: 'Terlama',
                            onRemove: () {
                              if (mounted)
                                setState(() => _sortOrder = 'TERBARU');
                            },
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Summary Cards ──
                if (!_isLoading && _laporanList.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildSummaryRow(filtered),
                  ),

                const SizedBox(height: 24),

                // ── List Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade700,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Daftar Laporan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${filtered.length} data',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Content ──
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty || _activeFilterCount > 0
                              ? Icons.search_off_rounded
                              : Icons.meeting_room_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _activeFilterCount > 0
                              ? 'Data tidak ditemukan'
                              : 'Belum ada laporan peminjaman',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _activeFilterCount > 0
                              ? 'Coba ubah kata kunci atau filter'
                              : 'Peminjaman yang sudah selesai akan muncul di sini',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        ...filtered
                            .map((item) => _buildLaporanCard(item))
                            .toList(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Summary Row ───
  Widget _buildSummaryRow(List<Map<String, dynamic>> data) {
    int totalMenit = 0;
    for (final item in data) {
      totalMenit += _hitungDurasi(
        item['waktuMulai'] as Timestamp?,
        item['waktuSelesai'] as Timestamp?,
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.receipt_long_outlined,
            label: 'Total Laporan',
            value: data.length.toString(),
            color: Colors.teal.shade700,
            bgColor: Colors.teal.shade50,
            borderColor: Colors.teal.shade100,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.timer_outlined,
            label: 'Total Durasi',
            value: totalMenit > 0 ? _durasiLabel(totalMenit) : '-',
            color: Colors.purple.shade700,
            bgColor: Colors.purple.shade50,
            borderColor: Colors.purple.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: color.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChip(
      {required String label, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: Colors.teal.shade700),
          ),
        ],
      ),
    );
  }

  // ─── Laporan Card ───
  Widget _buildLaporanCard(Map<String, dynamic> item) {
    final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
    // ✅ Gunakan helper method untuk namaRuang & lokasi
    final namaRuang = _getNamaRuang(item);
    final lokasi = _getLokasi(item);
    final namaPeminjam = peminjam['nama']?.toString() ?? '-';
    final divisi = peminjam['divisi']?.toString() ?? '-';
    final namaKegiatan = item['namaKegiatan']?.toString() ?? '-';
    final jenisRapat = (item['jenisRapat'] ?? '').toString().trim();
    final peserta = item['peserta']?.toString() ?? '-';
    final waktuMulai = item['waktuMulai'] as Timestamp?;
    final waktuSelesai = item['waktuSelesai'] as Timestamp?;
    final durasi = _hitungDurasi(waktuMulai, waktuSelesai);
    final jenisColor =
        jenisRapat.isNotEmpty ? _jenisRapatColor(jenisRapat) : Colors.grey;
    final displayAsDone = item['_displayAsDone'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
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
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
              // ── Card Header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.meeting_room_rounded,
                        color: Colors.teal.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                namaRuang,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (lokasi.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  lokasi,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Badge status
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: displayAsDone
                                    ? Colors.orange.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: displayAsDone
                                        ? Colors.orange.shade300
                                        : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    displayAsDone
                                        ? Icons.timelapse_rounded
                                        : Icons.check_circle_rounded,
                                    size: 12,
                                    color: displayAsDone
                                        ? Colors.orange.shade700
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    displayAsDone
                                        ? 'Selesai*'
                                        : 'Selesai',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: displayAsDone
                                            ? Colors.orange.shade700
                                            : Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Badge jenis rapat
                            if (jenisRapat.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: jenisColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: jenisColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _jenisRapatLabel(jenisRapat),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: jenisColor),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildDetailRow(
                icon: Icons.event_note_outlined,
                label: 'Kegiatan',
                value: namaKegiatan,
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Peminjam',
                value: namaPeminjam,
              ),
              const SizedBox(height: 10),
              if (widget.role != 'user') ...[
                _buildDetailRow(
                  icon: Icons.business_outlined,
                  label: 'Divisi',
                  value: divisi,
                ),
                const SizedBox(height: 10),
              ],
              _buildDetailRow(
                icon: Icons.people_outline_rounded,
                label: 'Peserta',
                value: '$peserta orang',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Waktu',
                value:
                    '${_formatDate(waktuMulai)} ${_formatTimeOnly(waktuMulai)} – ${_formatTimeOnly(waktuSelesai)}',
              ),
              if (durasi > 0) ...[
                const SizedBox(height: 10),
                _buildDetailRow(
                  icon: Icons.timer_outlined,
                  label: 'Durasi',
                  value: _durasiLabel(durasi),
                  valueColor: Colors.teal.shade700,
                ),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  Icon(Icons.access_time_outlined,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(
                    'Diajukan: ${_formatTimestamp(item['createdAt'] as Timestamp?)}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
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
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? Colors.grey.shade900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Filter Bottom Sheet
// ─────────────────────────────────────────
class _FilterBottomSheetMeeting extends StatefulWidget {
  final String selectedPeriode;
  final DateTimeRange? customDateRange;
  final String selectedRuang;
  final String selectedJenisRapat;
  final String selectedDivisi;
  final String sortOrder;
  final List<Map<String, String>> periodeOptions;
  final List<Map<String, String>> jenisRapatOptions;
  final List<String> ruangOptions;
  final List<String> divisiOptions;
  final bool showDivisi;
  final Function(String, DateTimeRange?, String, String, String, String)
      onApply;
  final VoidCallback onPickDateRange;

  const _FilterBottomSheetMeeting({
    required this.selectedPeriode,
    required this.customDateRange,
    required this.selectedRuang,
    required this.selectedJenisRapat,
    required this.selectedDivisi,
    required this.sortOrder,
    required this.periodeOptions,
    required this.jenisRapatOptions,
    required this.ruangOptions,
    required this.divisiOptions,
    required this.showDivisi,
    required this.onApply,
    required this.onPickDateRange,
  });

  @override
  State<_FilterBottomSheetMeeting> createState() =>
      _FilterBottomSheetMeetingState();
}

class _FilterBottomSheetMeetingState
    extends State<_FilterBottomSheetMeeting> {
  late String _periode;
  late DateTimeRange? _customRange;
  late String _ruang;
  late String _jenisRapat;
  late String _divisi;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _periode = widget.selectedPeriode;
    _customRange = widget.customDateRange;
    _ruang = widget.selectedRuang;
    // ✅ Validasi: jika nilai tersimpan tidak ada di options, reset ke SEMUA
    _jenisRapat = widget.jenisRapatOptions
            .any((o) => o['key'] == widget.selectedJenisRapat)
        ? widget.selectedJenisRapat
        : 'SEMUA';
    _divisi = widget.selectedDivisi;
    _sort = widget.sortOrder;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text('Filter & Urutkan',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _periode = 'SEMUA';
                      _customRange = null;
                      _ruang = 'SEMUA';
                      _jenisRapat = 'SEMUA';
                      _divisi = 'SEMUA';
                      _sort = 'TERBARU';
                    });
                  },
                  child:
                      Text('Reset', style: TextStyle(color: Colors.red.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Urutan
            _buildSectionLabel('Urutan'),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSelectChip(
                    label: 'Terbaru',
                    isSelected: _sort == 'TERBARU',
                    onTap: () => setState(() => _sort = 'TERBARU')),
                const SizedBox(width: 8),
                _buildSelectChip(
                    label: 'Terlama',
                    isSelected: _sort == 'TERLAMA',
                    onTap: () => setState(() => _sort = 'TERLAMA')),
              ],
            ),
            const SizedBox(height: 20),

            // Periode
            _buildSectionLabel('Periode Waktu'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.periodeOptions.map((opt) {
                final isSelected = _periode == opt['key'];
                if (opt['key'] == 'CUSTOM') {
                  return GestureDetector(
                    onTap: widget.onPickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected && _customRange != null
                            ? Colors.teal.shade700
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected && _customRange != null
                              ? Colors.teal.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.date_range_outlined,
                              size: 14,
                              color: isSelected && _customRange != null
                                  ? Colors.white
                                  : Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            isSelected && _customRange != null
                                ? '${DateFormat('dd/MM/yy').format(_customRange!.start)} – ${DateFormat('dd/MM/yy').format(_customRange!.end)}'
                                : 'Kustom',
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected && _customRange != null
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: isSelected && _customRange != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return _buildSelectChip(
                  label: opt['label']!,
                  isSelected: isSelected,
                  onTap: () => setState(() => _periode = opt['key']!),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Jenis Rapat — hanya tampil jika ada lebih dari 1 opsi (selain SEMUA)
            if (widget.jenisRapatOptions.length > 1) ...[
              _buildSectionLabel('Jenis Rapat'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.jenisRapatOptions.map((opt) {
                  return _buildSelectChip(
                    label: opt['label']!,
                    isSelected: _jenisRapat == opt['key'],
                    onTap: () => setState(() => _jenisRapat = opt['key']!),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Ruang
            _buildSectionLabel('Ruang Meeting'),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _ruangOptions.contains(_ruang) ? _ruang : 'SEMUA',
                  isExpanded: true,
                  icon: Icon(Icons.expand_more, color: Colors.grey.shade600),
                  style:
                      TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  items: widget.ruangOptions.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text(
                        r == 'SEMUA' ? 'Semua Ruang' : r,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _ruang = val);
                  },
                ),
              ),
            ),

            // Divisi
            if (widget.showDivisi) ...[
              const SizedBox(height: 20),
              _buildSectionLabel('Divisi'),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.divisiOptions.contains(_divisi)
                        ? _divisi
                        : 'SEMUA',
                    isExpanded: true,
                    icon:
                        Icon(Icons.expand_more, color: Colors.grey.shade600),
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade800),
                    items: widget.divisiOptions.map((d) {
                      return DropdownMenuItem(
                        value: d,
                        child: Text(
                          d == 'SEMUA' ? 'Semua Divisi' : d,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _divisi = val);
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(
                      _periode, _customRange, _ruang, _jenisRapat, _divisi, _sort);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Terapkan Filter',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _ruangOptions => widget.ruangOptions;

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildSelectChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}