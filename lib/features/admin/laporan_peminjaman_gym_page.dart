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

import '../gym/detail_peminjaman_gym_page.dart';

class LaporanPeminjamanGymPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const LaporanPeminjamanGymPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<LaporanPeminjamanGymPage> createState() =>
      _LaporanPeminjamanGymPageState();
}

class _LaporanPeminjamanGymPageState extends State<LaporanPeminjamanGymPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _laporanList = [];
  String _searchQuery = '';

  // ─── Filter State ───
  String _selectedPeriode = 'SEMUA';
  DateTimeRange? _customDateRange;
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

  List<String> _divisiOptions = ['SEMUA'];

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

  // ─── Load Data ───
  // Ambil status DONE + APPROVED yang waktuSelesai sudah lewat
  Future<void> _loadLaporan() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshotDone;
      QuerySnapshot snapshotApproved;

      if (widget.role == 'user') {
        snapshotDone = await FirebaseFirestore.instance
            .collection('gym_bookings')
            .where('status', isEqualTo: 'DONE')
            .where('peminjam.userId', isEqualTo: widget.userId)
            .get();
        snapshotApproved = await FirebaseFirestore.instance
            .collection('gym_bookings')
            .where('status', isEqualTo: 'APPROVED')
            .where('peminjam.userId', isEqualTo: widget.userId)
            .get();
      } else {
        snapshotDone = await FirebaseFirestore.instance
            .collection('gym_bookings')
            .where('status', isEqualTo: 'DONE')
            .get();
        snapshotApproved = await FirebaseFirestore.instance
            .collection('gym_bookings')
            .where('status', isEqualTo: 'APPROVED')
            .get();
      }

      final now = DateTime.now();
      final List<Map<String, dynamic>> allDocs = [];

      for (final doc in snapshotDone.docs) {
        allDocs.add({'id': doc.id, ...doc.data() as Map<String, dynamic>});
      }

      // Masukkan APPROVED yang waktu selesainya sudah lewat
      for (final doc in snapshotApproved.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final waktuSelesai = (data['waktuSelesai'] as Timestamp?)?.toDate();
        if (waktuSelesai != null && waktuSelesai.isBefore(now)) {
          allDocs.add({'id': doc.id, '_displayAsDone': true, ...data});
        }
      }

      // Kumpulkan opsi divisi dari data aktual
      final divisiSet = <String>{};
      for (final item in allDocs) {
        final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
        final divisi = peminjam['divisi']?.toString() ?? '';
        if (divisi.isNotEmpty) divisiSet.add(divisi);
      }

      if (mounted) {
        setState(() {
          _laporanList = allDocs;
          _divisiOptions = ['SEMUA', ...divisiSet.toList()..sort()];
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading laporan gym: $e');
      if (mounted) _showSnackbar('Error memuat data laporan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Filter Logic ───
  List<Map<String, dynamic>> get _filteredLaporan {
    List<Map<String, dynamic>> result = List.from(_laporanList);

    // Filter periode — gunakan waktuMulai sebagai acuan
    if (_selectedPeriode != 'SEMUA') {
      DateTime? fromDate;
      final now = DateTime.now();

      if (_selectedPeriode == 'CUSTOM' && _customDateRange != null) {
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
          return date.isAfter(
                  startOfDay.subtract(const Duration(seconds: 1))) &&
              date.isBefore(endOfDay.add(const Duration(seconds: 1)));
        }).toList();
        return _sortList(result);
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
          return ts
              .toDate()
              .isAfter(fromDate!.subtract(const Duration(seconds: 1)));
        }).toList();
      }
    }

    // Filter divisi (khusus non-user)
    if (_selectedDivisi != 'SEMUA' && widget.role != 'user') {
      result = result.where((item) {
        final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
        return (peminjam['divisi']?.toString() ?? '') == _selectedDivisi;
      }).toList();
    }

    // Search bar
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      result = result.where((item) {
        final peminjam = item['peminjam'] as Map<String, dynamic>? ?? {};
        final nama = (peminjam['nama'] ?? '').toString().toLowerCase();
        final divisi = (peminjam['divisi'] ?? '').toString().toLowerCase();
        final jabatan = (peminjam['jabatan'] ?? '').toString().toLowerCase();
        final catatan = (item['catatan'] ?? '').toString().toLowerCase();
        return nama.contains(q) ||
            divisi.contains(q) ||
            jabatan.contains(q) ||
            catatan.contains(q);
      }).toList();
    }

    return _sortList(result);
  }

  List<Map<String, dynamic>> _sortList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
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
    if (_selectedDivisi != 'SEMUA') count++;
    if (_sortOrder != 'TERBARU') count++;
    return count;
  }

  // ─── Helpers ───
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
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
    if (_selectedDivisi != 'SEMUA') parts.add(_selectedDivisi);
    return parts.join(' | ');
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
              '${filtered.length} data akan diekspor'
              '${_activeFilterCount > 0 ? ' (filter aktif)' : ''}',
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
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
        final nama = peminjam['nama']?.toString() ?? '-';
        final divisi = peminjam['divisi']?.toString() ?? '-';
        final jabatan = peminjam['jabatan']?.toString() ?? '-';
        final catatan = item['catatan']?.toString() ?? '-';
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
          jabatan,
          catatan.isNotEmpty && catatan != '-' ? catatan : '-',
          '$tglMulai\ns/d\n$tglSelesai',
          _durasiLabel(durasi),
        ];
      }).toList();

      const int rowsPerPage = 18;
      final chunks = <List<List<String>>>[];
      for (int i = 0; i < rows.length; i += rowsPerPage) {
        chunks.add(rows.sublist(
            i,
            i + rowsPerPage > rows.length
                ? rows.length
                : i + rowsPerPage));
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
                            'LAPORAN PEMINJAMAN GYM',
                            style:
                                pw.TextStyle(font: fontBold, fontSize: 14),
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
                            font: font,
                            fontSize: 9,
                            color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(
                      thickness: 1.5, color: PdfColors.orange800),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.2),
                      1: const pw.FlexColumnWidth(2.0),
                      2: const pw.FlexColumnWidth(2.0),
                      3: const pw.FlexColumnWidth(3.0),
                      4: const pw.FlexColumnWidth(2.2),
                      5: const pw.FlexColumnWidth(1.0),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.orange800),
                        children: [
                          'Nama Peminjam',
                          'Divisi',
                          'Jabatan',
                          'Catatan',
                          'Waktu',
                          'Durasi',
                        ]
                            .map((h) => pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 6),
                                  child: pw.Text(h,
                                      style: pw.TextStyle(
                                          font: fontBold,
                                          fontSize: 9,
                                          color: PdfColors.white)),
                                ))
                            .toList(),
                      ),
                      ...chunk.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final row = entry.value;
                        final bgColor = idx.isEven
                            ? PdfColors.grey50
                            : PdfColors.white;
                        return pw.TableRow(
                          decoration:
                              pw.BoxDecoration(color: bgColor),
                          children: row
                              .map((cell) => pw.Padding(
                                    padding: const pw.EdgeInsets
                                        .symmetric(
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
                    pw.Divider(
                        thickness: 0.5, color: PdfColors.grey400),
                    pw.Text(
                      'Total: ${data.length} peminjaman',
                      style:
                          pw.TextStyle(font: fontBold, fontSize: 9),
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
          'laporan_gym_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
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
      excel.rename('Sheet1', 'Laporan Gym');
      final sheet = excel['Laporan Gym'];

      CellStyle headerStyle() => CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#E65100'),
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
      sheet.merge(
          CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('LAPORAN PEMINJAMAN GYM');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      sheet.setRowHeight(0, 30);

      // Filter
      sheet.merge(
          CellIndex.indexByString('A2'), CellIndex.indexByString('H2'));
      sheet.cell(CellIndex.indexByString('A2')).value =
          TextCellValue('Filter: ${_getFilterDesc()}');
      sheet.setRowHeight(1, 20);

      // Tanggal cetak
      sheet.merge(
          CellIndex.indexByString('A3'), CellIndex.indexByString('H3'));
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
          'Dicetak: ${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now())}');
      sheet.setRowHeight(2, 18);

      // Spasi
      sheet.setRowHeight(3, 10);

      // Header tabel
      final headers = [
        'No',
        'Nama Peminjam',
        'Divisi',
        'Jabatan',
        'Catatan',
        'Tgl & Jam Mulai',
        'Tgl & Jam Selesai',
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
        final peminjam =
            item['peminjam'] as Map<String, dynamic>? ?? {};
        final nama = peminjam['nama']?.toString() ?? '-';
        final divisi = peminjam['divisi']?.toString() ?? '-';
        final jabatan = peminjam['jabatan']?.toString() ?? '-';
        final catatan = item['catatan']?.toString() ?? '';
        final waktuMulai = item['waktuMulai'] as Timestamp?;
        final waktuSelesai = item['waktuSelesai'] as Timestamp?;
        final durasi = _hitungDurasi(waktuMulai, waktuSelesai);

        final rowData = [
          (rowIdx + 1).toString(),
          nama,
          divisi,
          jabatan,
          catatan.isNotEmpty ? catatan : '-',
          waktuMulai != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(waktuMulai.toDate())
              : '-',
          waktuSelesai != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(waktuSelesai.toDate())
              : '-',
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
        CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: totalRowIdx),
        CellIndex.indexByColumnRow(
            columnIndex: 7, rowIndex: totalRowIdx),
      );
      final totalCell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: 0, rowIndex: totalRowIdx));
      totalCell.value =
          TextCellValue('Total: ${data.length} peminjaman');
      totalCell.cellStyle = CellStyle(bold: true);

      final colWidths = [
        5.0, 22.0, 18.0, 18.0, 30.0, 18.0, 18.0, 10.0
      ];
      for (int i = 0; i < colWidths.length; i++) {
        sheet.setColumnWidth(i, colWidths[i]);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Gagal menyimpan excel');

      final fileName =
          'laporan_gym_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(fileBytes),
            name: fileName,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Laporan Peminjaman Gym',
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterBottomSheetGym(
        selectedPeriode: _selectedPeriode,
        customDateRange: _customDateRange,
        selectedDivisi: _selectedDivisi,
        sortOrder: _sortOrder,
        periodeOptions: _periodeOptions,
        divisiOptions: _divisiOptions,
        showDivisi: widget.role != 'user',
        onApply:
            (periode, customRange, divisi, sort) {
          if (mounted) {
            setState(() {
              _selectedPeriode = periode;
              _customDateRange = customRange;
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
      initialDate: _customDateRange?.end ??
          pickedStart.add(const Duration(days: 1)),
      firstDate: pickedStart,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
    );
    if (pickedEnd == null || !mounted) return;

    setState(() {
      _customDateRange =
          DateTimeRange(start: pickedStart, end: pickedEnd);
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
                        color: Colors.orange.shade800,
                      ),
                      const Spacer(),
                      // Tombol ekspor
                      GestureDetector(
                        onTap:
                            _isExporting ? null : _showExportDialog,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.shade50,
                            border: Border.all(
                                color: Colors.green.shade200),
                          ),
                          child: _isExporting
                              ? Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.green.shade700),
                                )
                              : Icon(Icons.download_rounded,
                                  size: 20,
                                  color: Colors.green.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.shade100,
                        ),
                        child: Icon(Icons.fitness_center_rounded,
                            size: 22, color: Colors.orange.shade800),
                      ),
                    ],
                  ),
                ),

                // ── Title ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laporan Peminjaman Gym',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Riwayat peminjaman gym yang telah selesai',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Search + Filter ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            if (mounted)
                              setState(() => _searchQuery = val);
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Cari nama, divisi, catatan...',
                            prefixIcon: Icon(Icons.search,
                                color: Colors.grey.shade600),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close,
                                        color: Colors.grey.shade500,
                                        size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      if (mounted)
                                        setState(
                                            () => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                            hintStyle: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500),
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
                                ? Colors.orange.shade700
                                : Colors.grey.shade50,
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                              color: _activeFilterCount > 0
                                  ? Colors.orange.shade700
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
                                    decoration:
                                        const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$_activeFilterCount',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.bold),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24),
                    child: Row(
                      children: [
                        if (_selectedPeriode != 'SEMUA')
                          _buildActiveChip(
                            label: _selectedPeriode == 'CUSTOM' &&
                                    _customDateRange != null
                                ? _formatDateRange(
                                    _customDateRange!)
                                : _periodeOptions
                                        .firstWhere(
                                          (e) =>
                                              e['key'] ==
                                              _selectedPeriode,
                                          orElse: () => {
                                            'label': _selectedPeriode
                                          },
                                        )['label'] ??
                                    _selectedPeriode,
                            onRemove: () {
                              if (mounted)
                                setState(() {
                                  _selectedPeriode = 'SEMUA';
                                  _customDateRange = null;
                                });
                            },
                          ),
                        if (_selectedDivisi != 'SEMUA')
                          _buildActiveChip(
                            label: _selectedDivisi,
                            onRemove: () {
                              if (mounted)
                                setState(
                                    () => _selectedDivisi = 'SEMUA');
                            },
                          ),
                        if (_sortOrder != 'TERBARU')
                          _buildActiveChip(
                            label: 'Terlama',
                            onRemove: () {
                              if (mounted)
                                setState(
                                    () => _sortOrder = 'TERBARU');
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24),
                    child: _buildSummaryRow(filtered),
                  ),

                const SizedBox(height: 24),

                // ── List Header ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
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
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${filtered.length} data',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade800,
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
                    child: Center(
                        child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ||
                                  _activeFilterCount > 0
                              ? Icons.search_off_rounded
                              : Icons.fitness_center_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ||
                                  _activeFilterCount > 0
                              ? 'Data tidak ditemukan'
                              : 'Belum ada laporan peminjaman',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty ||
                                  _activeFilterCount > 0
                              ? 'Coba ubah kata kunci atau filter'
                              : 'Peminjaman gym yang sudah selesai\nakan muncul di sini',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24),
                    child: Column(
                      children: [
                        ...filtered
                            .map((item) =>
                                _buildLaporanCard(item))
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
            color: Colors.orange.shade700,
            bgColor: Colors.orange.shade50,
            borderColor: Colors.orange.shade100,
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
                        fontSize: 11,
                        color: color.withOpacity(0.8))),
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
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close,
                size: 14, color: Colors.orange.shade700),
          ),
        ],
      ),
    );
  }

  // ─── Laporan Card ───
  Widget _buildLaporanCard(Map<String, dynamic> item) {
    final peminjam =
        item['peminjam'] as Map<String, dynamic>? ?? {};
    final namaPeminjam = peminjam['nama']?.toString() ?? '-';
    final divisi = peminjam['divisi']?.toString() ?? '-';
    final jabatan = peminjam['jabatan']?.toString() ?? '-';
    final catatan = item['catatan']?.toString() ?? '';
    final waktuMulai = item['waktuMulai'] as Timestamp?;
    final waktuSelesai = item['waktuSelesai'] as Timestamp?;
    final durasi = _hitungDurasi(waktuMulai, waktuSelesai);
    final displayAsDone = item['_displayAsDone'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
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
                      color: Colors.orange.shade700
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.fitness_center_rounded,
                        color: Colors.orange.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                namaPeminjam,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                jabatan,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge status selesai
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: displayAsDone
                                ? Colors.orange.shade50
                                : Colors.grey.shade100,
                            borderRadius:
                                BorderRadius.circular(20),
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
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Divisi (hanya untuk non-user agar relevan)
              if (widget.role != 'user') ...[
                _buildDetailRow(
                  icon: Icons.business_outlined,
                  label: 'Divisi',
                  value: divisi,
                ),
                const SizedBox(height: 10),
              ],

              // Catatan (tampilkan jika ada)
              if (catatan.isNotEmpty) ...[
                _buildDetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Catatan',
                  value: catatan,
                ),
                const SizedBox(height: 10),
              ],

              // Waktu
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Waktu',
                value:
                    '${_formatDate(waktuMulai)}  ${_formatTimeOnly(waktuMulai)} – ${_formatTimeOnly(waktuSelesai)}',
              ),

              // Durasi
              if (durasi > 0) ...[
                const SizedBox(height: 10),
                _buildDetailRow(
                  icon: Icons.timer_outlined,
                  label: 'Durasi',
                  value: _durasiLabel(durasi),
                  valueColor: Colors.orange.shade700,
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
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
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
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
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
// Filter Bottom Sheet Gym
// ─────────────────────────────────────────
class _FilterBottomSheetGym extends StatefulWidget {
  final String selectedPeriode;
  final DateTimeRange? customDateRange;
  final String selectedDivisi;
  final String sortOrder;
  final List<Map<String, String>> periodeOptions;
  final List<String> divisiOptions;
  final bool showDivisi;
  final Function(String, DateTimeRange?, String, String) onApply;
  final VoidCallback onPickDateRange;

  const _FilterBottomSheetGym({
    required this.selectedPeriode,
    required this.customDateRange,
    required this.selectedDivisi,
    required this.sortOrder,
    required this.periodeOptions,
    required this.divisiOptions,
    required this.showDivisi,
    required this.onApply,
    required this.onPickDateRange,
  });

  @override
  State<_FilterBottomSheetGym> createState() =>
      _FilterBottomSheetGymState();
}

class _FilterBottomSheetGymState
    extends State<_FilterBottomSheetGym> {
  late String _periode;
  late DateTimeRange? _customRange;
  late String _divisi;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _periode = widget.selectedPeriode;
    _customRange = widget.customDateRange;
    _divisi = widget.selectedDivisi;
    _sort = widget.sortOrder;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
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
                      _divisi = 'SEMUA';
                      _sort = 'TERBARU';
                    });
                  },
                  child: Text('Reset',
                      style:
                          TextStyle(color: Colors.red.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Urutan ──
            _buildSectionLabel('Urutan'),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSelectChip(
                    label: 'Terbaru',
                    isSelected: _sort == 'TERBARU',
                    onTap: () =>
                        setState(() => _sort = 'TERBARU')),
                const SizedBox(width: 8),
                _buildSelectChip(
                    label: 'Terlama',
                    isSelected: _sort == 'TERLAMA',
                    onTap: () =>
                        setState(() => _sort = 'TERLAMA')),
              ],
            ),
            const SizedBox(height: 20),

            // ── Periode ──
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
                            ? Colors.orange.shade700
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected &&
                                  _customRange != null
                              ? Colors.orange.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.date_range_outlined,
                              size: 14,
                              color: isSelected &&
                                      _customRange != null
                                  ? Colors.white
                                  : Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            isSelected && _customRange != null
                                ? '${DateFormat('dd/MM/yy').format(_customRange!.start)} – ${DateFormat('dd/MM/yy').format(_customRange!.end)}'
                                : 'Kustom',
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected &&
                                      _customRange != null
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: isSelected &&
                                      _customRange != null
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
                  onTap: () =>
                      setState(() => _periode = opt['key']!),
                );
              }).toList(),
            ),

            // ── Divisi (hanya untuk admin/operator) ──
            if (widget.showDivisi) ...[
              const SizedBox(height: 20),
              _buildSectionLabel('Divisi'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
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
                    icon: Icon(Icons.expand_more,
                        color: Colors.grey.shade600),
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade800),
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
                      if (val != null)
                        setState(() => _divisi = val);
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
                      _periode, _customRange, _divisi, _sort);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Terapkan Filter',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange.shade700
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.orange.shade700
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color:
                isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
