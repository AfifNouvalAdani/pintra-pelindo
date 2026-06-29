import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../vehicle/detail_peminjaman_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:typed_data';

class LaporanPeminjamanKendaraanPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;

  const LaporanPeminjamanKendaraanPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
  });

  @override
  State<LaporanPeminjamanKendaraanPage> createState() =>
      _LaporanPeminjamanKendaraanPageState();
}

class _LaporanPeminjamanKendaraanPageState
    extends State<LaporanPeminjamanKendaraanPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _laporanList = [];
  String _searchQuery = '';

  // ─── Filter State ───
  String _selectedPeriode = 'SEMUA';
  DateTimeRange? _customDateRange;
  String _selectedKendaraan = 'SEMUA';
  String _selectedJenisKegiatan = 'SEMUA';
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

  final List<Map<String, String>> _jenisKegiatanOptions = [
    {'key': 'SEMUA', 'label': 'Semua Kegiatan'},
    {'key': 'DINAS', 'label': 'DINAS'},
    {'key': 'UNDANGAN', 'label': 'Undangan'},
    {'key': 'LAINNYA', 'label': 'Kegiatan Lain'},
  ];

  List<String> _kendaraanOptions = ['SEMUA'];
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

pw.Widget _buildFotoSectionPdf({
  required String title,
  required List<dynamic> fotoList,
  required pw.Font fontBold,
  required pw.Font font,
}) {
  if (fotoList.isEmpty) return pw.SizedBox();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 12),
      pw.Text(
        title,
        style: pw.TextStyle(font: fontBold, fontSize: 10),
      ),
      pw.SizedBox(height: 8),
      pw.Builder(builder: (_) {
        final items = fotoList.asMap().entries.map((entry) {
          try {
            final bytes = base64Decode(entry.value.toString());
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 150,
                  height: 110,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 4,
                    verticalRadius: 4,
                    child: pw.Image(
                      pw.MemoryImage(bytes),
                      fit: pw.BoxFit.cover,
                      width: 150,
                      height: 110,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Foto ${entry.key + 1}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            );
          } catch (e) {
            return pw.SizedBox(width: 0, height: 0);
          }
        }).toList();

        final rows = <pw.Widget>[];
        for (int i = 0; i < items.length; i += 3) {
          final end = (i + 3 > items.length) ? items.length : i + 3;
          final rowItems = List<pw.Widget>.from(items.sublist(i, end));
          while (rowItems.length < 3) {
            rowItems.add(pw.SizedBox(width: 158)); // 150 + 8 padding
          }
          rows.add(pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: rowItems
                .map((w) => pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 8),
                      child: w,
                    ))
                .toList(),
          ));
          rows.add(pw.SizedBox(height: 8));
        }
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: rows,
        );
      }),
    ],
  );
}

  // ─── Load Data ───
  Future<void> _loadLaporan() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', isEqualTo: 'DONE');

      // Filter by role
      if (widget.role == 'user') {
        query = query.where('peminjamId', isEqualTo: widget.userId);
      }

      final snapshot = await query.get();

      _laporanList = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();

      // Kumpulkan opsi kendaraan & divisi unik
      final kendaraanSet = <String>{};
      final divisiSet = <String>{};
      for (final item in _laporanList) {
        final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
        final plat = vehicle['platNomor']?.toString() ?? '';
        final nama = vehicle['nama']?.toString() ??
            vehicle['namaKendaraan']?.toString() ??
            '';
        if (plat.isNotEmpty) {
          kendaraanSet.add(nama.isNotEmpty ? '$nama - $plat' : plat);
        }
        final divisi = item['divisi']?.toString() ?? '';
        if (divisi.isNotEmpty) divisiSet.add(divisi);
      }

      if (mounted) {
        setState(() {
          _kendaraanOptions = ['SEMUA', ...kendaraanSet.toList()..sort()];
          _divisiOptions = ['SEMUA', ...divisiSet.toList()..sort()];
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading laporan: $e');
      if (mounted) {
        _showSnackbar('Error memuat data laporan: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Filter Logic ───
  List<Map<String, dynamic>> get _filteredLaporan {
    List<Map<String, dynamic>> result = List.from(_laporanList);

    // Filter periode
    if (_selectedPeriode != 'SEMUA') {
      DateTime? fromDate;
      final now = DateTime.now();

      if (_selectedPeriode == 'CUSTOM' && _customDateRange != null) {
        result = result.where((item) {
          final ts = item['createdAt'] as Timestamp?;
          if (ts == null) return false;
          final date = ts.toDate();
          return date.isAfter(
                  _customDateRange!.start.subtract(const Duration(days: 1))) &&
              date.isBefore(
                  _customDateRange!.end.add(const Duration(days: 1)));
        }).toList();
      } else {
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
            final ts = item['createdAt'] as Timestamp?;
            if (ts == null) return false;
            return ts.toDate().isAfter(fromDate!);
          }).toList();
        }
      }
    }

    // Filter kendaraan
    if (_selectedKendaraan != 'SEMUA') {
      result = result.where((item) {
        final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
        final plat = vehicle['platNomor']?.toString() ?? '';
        final nama = vehicle['nama']?.toString() ??
            vehicle['namaKendaraan']?.toString() ??
            '';
        final displayName = nama.isNotEmpty ? '$nama - $plat' : plat;
        return displayName == _selectedKendaraan;
      }).toList();
    }

    // Filter jenis kegiatan
    if (_selectedJenisKegiatan != 'SEMUA') {
      result = result.where((item) {
        final keperluan = (item['keperluan'] ?? '').toString().toUpperCase();
        switch (_selectedJenisKegiatan) {
          case 'DINAS':
            return keperluan.contains('DINAS');
          case 'UNDANGAN':
            return keperluan.contains('UNDANGAN');
          case 'LAINNYA':
            return !keperluan.contains('DINAS') &&
                !keperluan.contains('UNDANGAN');
          default:
            return true;
        }
      }).toList();
    }

    // Filter divisi (admin/operator/manager)
    if (_selectedDivisi != 'SEMUA' && widget.role != 'user') {
      result = result.where((item) {
        return (item['divisi']?.toString() ?? '') == _selectedDivisi;
      }).toList();
    }

    // Search bar
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((item) {
        final nama = (item['namaPeminjam'] ?? '').toString().toLowerCase();
        final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
        final plat = (vehicle['platNomor'] ?? '').toString().toLowerCase();
        final kendaraanNama = (vehicle['nama'] ??
                vehicle['namaKendaraan'] ??
                '')
            .toString()
            .toLowerCase();
        final tujuan = (item['tujuan'] ?? '').toString().toLowerCase();
        final keperluan = (item['keperluan'] ?? '').toString().toLowerCase();
        final divisi = (item['divisi'] ?? '').toString().toLowerCase();
        return nama.contains(q) ||
            plat.contains(q) ||
            kendaraanNama.contains(q) ||
            tujuan.contains(q) ||
            keperluan.contains(q) ||
            divisi.contains(q);
      }).toList();
    }

    // Sort
    result.sort((a, b) {
      final tsA = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final tsB = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return _sortOrder == 'TERBARU' ? tsB.compareTo(tsA) : tsA.compareTo(tsB);
    });

    return result;
  }

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
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
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

  Future<void> _exportToPdf(List<Map<String, dynamic>> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      _showSnackbar('Membuat PDF...');
      final pdf = pw.Document();

      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      // Build rows
      final rows = data.map((item) {
        final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
        final platNomor = vehicle['platNomor']?.toString() ?? '-';
        final namaKendaraan = vehicle['nama']?.toString() ??
            vehicle['namaKendaraan']?.toString() ??
            '-';
        final namaPeminjam = item['namaPeminjam']?.toString() ?? '-';
        final divisi = item['divisi']?.toString() ?? '-';
        final tujuan = item['tujuan']?.toString() ?? '-';
        final keperluan = item['keperluan']?.toString() ?? '-';
        final waktuPinjam = item['waktuPinjam'] as Timestamp?;
        final waktuKembali = item['waktuKembali'] as Timestamp?;
        final kondisiAwal = item['kondisiAwal'] as Map<String, dynamic>?;
        final kondisiAkhir = item['kondisiAkhir'] as Map<String, dynamic>?;

        String jarakStr = '-';
        if (kondisiAwal != null && kondisiAkhir != null) {
          final odo1 = kondisiAwal['odometerAwal'];
          final odo2 = kondisiAkhir['odometerAkhir'];
          if (odo1 != null && odo2 != null) {
            final jarak = ((odo2 as num) - (odo1 as num)).toInt();
            jarakStr = '$jarak km';
          }
        }

        final tglPinjam = waktuPinjam != null
            ? DateFormat('dd/MM/yyyy').format(waktuPinjam.toDate())
            : '-';
        final tglKembali = waktuKembali != null
            ? DateFormat('dd/MM/yyyy').format(waktuKembali.toDate())
            : '-';

        return [
          namaPeminjam,
          divisi,
          '$namaKendaraan\n$platNomor',
          tujuan,
          keperluan,
          '$tglPinjam\ns/d\n$tglKembali',
          jarakStr,
        ];
      }).toList();

      // Filter description
      String filterDesc = 'Semua Data';
      if (_activeFilterCount > 0) {
        final parts = <String>[];
        if (_selectedPeriode != 'SEMUA') {
          parts.add(_selectedPeriode == 'CUSTOM' && _customDateRange != null
              ? _formatDateRange(_customDateRange!)
              : _periodeOptions.firstWhere(
                      (e) => e['key'] == _selectedPeriode,
                      orElse: () => {'label': _selectedPeriode})['label'] ??
                  _selectedPeriode);
        }
        if (_selectedKendaraan != 'SEMUA') parts.add(_selectedKendaraan);
        if (_selectedJenisKegiatan != 'SEMUA')
          parts.add(_selectedJenisKegiatan);
        if (_selectedDivisi != 'SEMUA') parts.add(_selectedDivisi);
        filterDesc = parts.join(' | ');
      }

      // Chunk data: ~15 rows per page
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
                  // Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'LAPORAN PEMINJAMAN KENDARAAN',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Filter: $filterDesc',
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
                  pw.Divider(thickness: 1.5, color: PdfColors.blue800),
                  pw.SizedBox(height: 8),

                  // Table
                  pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.2), // Peminjam
                      1: const pw.FlexColumnWidth(1.8), // Divisi
                      2: const pw.FlexColumnWidth(2.0), // Kendaraan
                      3: const pw.FlexColumnWidth(2.2), // Tujuan
                      4: const pw.FlexColumnWidth(1.5), // Keperluan
                      5: const pw.FlexColumnWidth(1.5), // Tanggal
                      6: const pw.FlexColumnWidth(1.2), // Jarak
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.blue800),
                        children: [
                          'Peminjam',
                          'Divisi',
                          'Kendaraan',
                          'Tujuan',
                          'Keperluan',
                          'Tanggal',
                          'Jarak'
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
                      // Data rows
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
                                    child: pw.Text(
                                      cell,
                                      style:
                                          pw.TextStyle(font: font, fontSize: 8),
                                    ),
                                  ))
                              .toList(),
                        );
                      }).toList(),
                    ],
                  ),

                  pw.SizedBox(height: 8),
                  // Summary footer hanya di halaman terakhir
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

      // ── Halaman foto per item ──
for (int itemIdx = 0; itemIdx < data.length; itemIdx++) {
  final item = data[itemIdx];
  final kondisiAwal = item['kondisiAwal'] as Map<String, dynamic>?;
  final kondisiAkhir = item['kondisiAkhir'] as Map<String, dynamic>?;

  final fotoAwal = kondisiAwal?['fotoBase64List'] as List? ?? [];
  final fotoAkhir = kondisiAkhir?['fotoPengembalianBase64List'] as List? ?? [];

  // Skip jika tidak ada foto sama sekali
  if (fotoAwal.isEmpty && fotoAkhir.isEmpty) continue;

  final namaPeminjam = item['namaPeminjam']?.toString() ?? '-';
  final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
  final platNomor = vehicle['platNomor']?.toString() ?? '-';
  final namaKendaraan = vehicle['nama']?.toString() ??
      vehicle['namaKendaraan']?.toString() ?? '-';
  final waktuPinjam = item['waktuPinjam'] as Timestamp?;

pdf.addPage(
  pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(24),
build: (pw.Context ctx) => [
  // Header halaman foto
  pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'LAMPIRAN FOTO KENDARAAN',
            style: pw.TextStyle(font: fontBold, fontSize: 13),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$namaPeminjam — $namaKendaraan ($platNomor)',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
          ),
          if (waktuPinjam != null)
            pw.Text(
              'Tanggal: ${DateFormat('dd MMM yyyy').format(waktuPinjam.toDate())}',
              style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
            ),
        ],
      ),
      pw.Text(
        'No. ${itemIdx + 1}',
        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
      ),
    ],
  ),
  pw.SizedBox(height: 4),
  pw.Divider(thickness: 1.5, color: PdfColors.blue800),

// Foto kondisi awal
  if (fotoAwal.isNotEmpty)
    _buildFotoSectionPdf(
      title: 'Foto Kondisi Awal',
      fotoList: fotoAwal,
      fontBold: fontBold,
      font: font,
    )
  else
    pw.SizedBox(),

  // Foto kondisi akhir
  if (fotoAkhir.isNotEmpty)
    _buildFotoSectionPdf(
      title: 'Foto Kondisi Pengembalian',
      fotoList: fotoAkhir,
      fontBold: fontBold,
      font: font,
    )
  else
    pw.SizedBox(),
],
    ),
  );
}

      final pdfBytes = await pdf.save();
      final fileName =
          'laporan_peminjaman_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      debugPrint('❌ Error export PDF: $e');
      if (mounted) _showSnackbar('Gagal membuat PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      _showSnackbar('Membuat Excel...');

      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Laporan Peminjaman');
      final sheet = excel['Laporan Peminjaman'];

      // Style helpers
      CellStyle headerStyle() => CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
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

      // ── Baris 1: Judul ──
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('J1'));
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('LAPORAN PEMINJAMAN KENDARAAN');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      sheet.setRowHeight(0, 30);

      // ── Baris 2: Info filter ──
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('J2'));
      String filterDesc = 'Filter: Semua Data';
      if (_activeFilterCount > 0) {
        final parts = <String>[];
        if (_selectedPeriode != 'SEMUA') {
          parts.add(_selectedPeriode == 'CUSTOM' && _customDateRange != null
              ? _formatDateRange(_customDateRange!)
              : _periodeOptions.firstWhere(
                      (e) => e['key'] == _selectedPeriode,
                      orElse: () => {'label': _selectedPeriode})['label'] ??
                  _selectedPeriode);
        }
        if (_selectedKendaraan != 'SEMUA') parts.add(_selectedKendaraan);
        if (_selectedJenisKegiatan != 'SEMUA')
          parts.add(_selectedJenisKegiatan);
        if (_selectedDivisi != 'SEMUA') parts.add(_selectedDivisi);
        filterDesc = 'Filter: ${parts.join(' | ')}';
      }
      sheet.cell(CellIndex.indexByString('A2')).value =
          TextCellValue(filterDesc);
      sheet.setRowHeight(1, 20);

      // ── Baris 3: Tanggal cetak ──
      sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('J3'));
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
          'Dicetak: ${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now())}');
      sheet.setRowHeight(2, 18);

      // ── Baris 4: Kosong ──
      sheet.setRowHeight(3, 10);

      // ── Baris 5: Header tabel ──
      final headers = [
        'No',
        'Nama Peminjam',
        'Divisi',
        'Kendaraan',
        'Plat Nomor',
        'Tujuan',
        'Keperluan',
        'Tgl Pinjam',
        'Tgl Kembali',
        'Jarak Tempuh (km)'
      ];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle();
      }
      sheet.setRowHeight(4, 28);

      // ── Data rows mulai baris 6 ──
      for (int rowIdx = 0; rowIdx < data.length; rowIdx++) {
        final item = data[rowIdx];
        final isEven = rowIdx.isEven;
        final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
        final platNomor = vehicle['platNomor']?.toString() ?? '-';
        final namaKendaraan = vehicle['nama']?.toString() ??
            vehicle['namaKendaraan']?.toString() ??
            '-';
        final namaPeminjam = item['namaPeminjam']?.toString() ?? '-';
        final divisi = item['divisi']?.toString() ?? '-';
        final tujuan = item['tujuan']?.toString() ?? '-';
        final keperluan = item['keperluan']?.toString() ?? '-';
        final waktuPinjam = item['waktuPinjam'] as Timestamp?;
        final waktuKembali = item['waktuKembali'] as Timestamp?;
        final kondisiAwal = item['kondisiAwal'] as Map<String, dynamic>?;
        final kondisiAkhir = item['kondisiAkhir'] as Map<String, dynamic>?;

        int? jarak;
        if (kondisiAwal != null && kondisiAkhir != null) {
          final odo1 = kondisiAwal['odometerAwal'];
          final odo2 = kondisiAkhir['odometerAkhir'];
          if (odo1 != null && odo2 != null) {
            jarak = ((odo2 as num) - (odo1 as num)).toInt();
          }
        }

        final rowData = [
          (rowIdx + 1).toString(),
          namaPeminjam,
          divisi,
          namaKendaraan,
          platNomor,
          tujuan,
          keperluan,
          waktuPinjam != null
              ? DateFormat('dd/MM/yyyy').format(waktuPinjam.toDate())
              : '-',
          waktuKembali != null
              ? DateFormat('dd/MM/yyyy').format(waktuKembali.toDate())
              : '-',
          jarak?.toString() ?? '-',
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

      // ── Baris total ──
      final totalRowIdx = data.length + 5;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRowIdx),
        CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: totalRowIdx),
      );
      final totalCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRowIdx));
      totalCell.value = TextCellValue('Total: ${data.length} peminjaman');
      totalCell.cellStyle = CellStyle(bold: true);

      // Set column widths
      final colWidths = [
        6.0,
        22.0,
        18.0,
        20.0,
        14.0,
        24.0,
        16.0,
        14.0,
        14.0,
        18.0
      ];
      for (int i = 0; i < colWidths.length; i++) {
        sheet.setColumnWidth(i, colWidths[i]);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Gagal menyimpan excel');

      final fileName =
          'laporan_peminjaman_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(fileBytes),
            name: fileName,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Laporan Peminjaman Kendaraan',
      );
    } catch (e) {
      debugPrint('❌ Error export Excel: $e');
      if (mounted) _showSnackbar('Gagal membuat Excel: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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

  String _formatDateRange(DateTimeRange range) {
    final fmt = DateFormat('dd/MM/yy');
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }

  String _jenisKegiatanLabel(String keperluan) {
    final k = keperluan.toUpperCase();
    if (k.contains('DINAS')) return 'DINAS';
    if (k.contains('UNDANGAN')) return 'Undangan';
    return 'Kegiatan Lain';
  }

  Color _jenisKegiatanColor(String keperluan) {
    final k = keperluan.toUpperCase();
    if (k.contains('DINAS')) return Colors.purple.shade600;
    if (k.contains('UNDANGAN')) return Colors.blue.shade600;
    return Colors.orange.shade600;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterBottomSheet(
        selectedPeriode: _selectedPeriode,
        customDateRange: _customDateRange,
        selectedKendaraan: _selectedKendaraan,
        selectedJenisKegiatan: _selectedJenisKegiatan,
        selectedDivisi: _selectedDivisi,
        sortOrder: _sortOrder,
        periodeOptions: _periodeOptions,
        jenisKegiatanOptions: _jenisKegiatanOptions,
        kendaraanOptions: _kendaraanOptions,
        divisiOptions: _divisiOptions,
        showDivisi: widget.role != 'user',
        onApply:
            (periode, customRange, kendaraan, jenisKegiatan, divisi, sort) {
          if (mounted) {
            setState(() {
              _selectedPeriode = periode;
              _customDateRange = customRange;
              _selectedKendaraan = kendaraan;
              _selectedJenisKegiatan = jenisKegiatan;
              _selectedDivisi = divisi;
              _sortOrder = sort;
            });
          }
        },
        onPickDateRange: () async {
          // Pop bottom sheet terlebih dahulu
          Navigator.of(context).pop();
          // Tunggu bottom sheet selesai dismiss
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          // Buka dua date picker terpisah untuk start dan end
          await _pickCustomDateRange();
        },
      ),
    );
  }

  // ─── Fungsi baru untuk memilih rentang tanggal dengan dua picker terpisah ───
  Future<void> _pickCustomDateRange() async {
    if (!mounted) return;

    DateTime? startDate = _customDateRange?.start;
    DateTime? endDate = _customDateRange?.end;

    // Pilih tanggal mulai
    final pickedStart = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
    );

    if (pickedStart == null || !mounted) return;

    // Pilih tanggal selesai (minimal pickedStart)
    final pickedEnd = await showDatePicker(
      context: context,
      initialDate: endDate ?? pickedStart.add(const Duration(days: 1)),
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

  // ─── Active Filter Count ───
  int get _activeFilterCount {
    int count = 0;
    if (_selectedPeriode != 'SEMUA') count++;
    if (_selectedKendaraan != 'SEMUA') count++;
    if (_selectedJenisKegiatan != 'SEMUA') count++;
    if (_selectedDivisi != 'SEMUA') count++;
    if (_sortOrder != 'TERBARU') count++;
    return count;
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
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.grey.shade700,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/images/logo-pelindo.webp',
                        height: 28,
                        color: Colors.blue.shade800,
                      ),
                      const Spacer(),
                      // ── Tombol Ekspor ──
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
                          child: Icon(
                            Icons.download_rounded,
                            size: 20,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade100,
                        ),
                        child: Icon(
                          Icons.assessment_outlined,
                          size: 22,
                          color: Colors.blue.shade800,
                        ),
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
                        'Laporan Peminjaman',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Riwayat peminjaman kendaraan yang telah selesai',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
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
                            hintText: 'Cari nama, kendaraan, tujuan...',
                            prefixIcon:
                                Icon(Icons.search, color: Colors.grey.shade600),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close,
                                        color: Colors.grey.shade500, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      if (mounted) setState(() => _searchQuery = '');
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
                      // Filter button
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _activeFilterCount > 0
                                ? Colors.blue.shade700
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _activeFilterCount > 0
                                  ? Colors.blue.shade700
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
                                            {'label': _selectedPeriode})[
                                    'label']!,
                            onRemove: () {
                              if (mounted) {
                                setState(() {
                                  _selectedPeriode = 'SEMUA';
                                  _customDateRange = null;
                                });
                              }
                            },
                          ),
                        if (_selectedKendaraan != 'SEMUA')
                          _buildActiveChip(
                            label: _selectedKendaraan,
                            onRemove: () {
                              if (mounted) setState(() => _selectedKendaraan = 'SEMUA');
                            },
                          ),
                        if (_selectedJenisKegiatan != 'SEMUA')
                          _buildActiveChip(
                            label: _jenisKegiatanOptions.firstWhere(
                                (e) => e['key'] == _selectedJenisKegiatan,
                                orElse: () =>
                                    {'label': _selectedJenisKegiatan})['label']!,
                            onRemove: () {
                              if (mounted) setState(() => _selectedJenisKegiatan = 'SEMUA');
                            },
                          ),
                        if (_selectedDivisi != 'SEMUA')
                          _buildActiveChip(
                            label: _selectedDivisi,
                            onRemove: () {
                              if (mounted) setState(() => _selectedDivisi = 'SEMUA');
                            },
                          ),
                        if (_sortOrder != 'TERBARU')
                          _buildActiveChip(
                            label: 'Terlama',
                            onRemove: () {
                              if (mounted) setState(() => _sortOrder = 'TERBARU');
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
                          color: Colors.blue.shade700,
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
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${filtered.length} data',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade800,
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
                              : Icons.assessment_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _activeFilterCount > 0
                              ? 'Data tidak ditemukan'
                              : 'Belum ada laporan peminjaman',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _activeFilterCount > 0
                              ? 'Coba ubah kata kunci atau filter'
                              : 'Peminjaman yang sudah selesai akan muncul di sini',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        ...filtered.map((item) => _buildLaporanCard(item)).toList(),
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
    int totalJarak = 0;
    int totalData = data.length;

    for (final item in data) {
      final kondisiAwal = item['kondisiAwal'] as Map<String, dynamic>?;
      final kondisiAkhir = item['kondisiAkhir'] as Map<String, dynamic>?;
      if (kondisiAwal != null && kondisiAkhir != null) {
        final odo1 = kondisiAwal['odometerAwal'];
        final odo2 = kondisiAkhir['odometerAkhir'];
        if (odo1 != null && odo2 != null) {
          totalJarak += ((odo2 as num) - (odo1 as num)).toInt();
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.receipt_long_outlined,
            label: 'Total Laporan',
            value: totalData.toString(),
            color: Colors.blue.shade700,
            bgColor: Colors.blue.shade50,
            borderColor: Colors.blue.shade100,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.speed_outlined,
            label: 'Total Jarak',
            value: totalJarak > 0 ? '${_formatNumber(totalJarak)} km' : '- km',
            color: Colors.green.shade700,
            bgColor: Colors.green.shade50,
            borderColor: Colors.green.shade100,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    return NumberFormat('#,###', 'id_ID').format(n);
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Active Chip ───
  Widget _buildActiveChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  // ─── Laporan Card ───
  Widget _buildLaporanCard(Map<String, dynamic> item) {
    final vehicle = item['vehicle'] as Map<String, dynamic>? ?? {};
    final platNomor = vehicle['platNomor']?.toString() ?? '-';
    final namaKendaraan = vehicle['nama']?.toString() ??
        vehicle['namaKendaraan']?.toString() ??
        '-';
    final namaPeminjam = item['namaPeminjam']?.toString() ?? '-';
    final divisi = item['divisi']?.toString() ?? '-';
    final tujuan = item['tujuan']?.toString() ?? '-';
    final keperluan = item['keperluan']?.toString() ?? '';
    final waktuPinjam = item['waktuPinjam'] as Timestamp?;
    final waktuKembali = item['waktuKembali'] as Timestamp?;
    final kondisiAwal = item['kondisiAwal'] as Map<String, dynamic>?;
    final kondisiAkhir = item['kondisiAkhir'] as Map<String, dynamic>?;

    int? jarakTempuh;
    if (kondisiAwal != null && kondisiAkhir != null) {
      final odo1 = kondisiAwal['odometerAwal'];
      final odo2 = kondisiAkhir['odometerAkhir'];
      if (odo1 != null && odo2 != null) {
        jarakTempuh = ((odo2 as num) - (odo1 as num)).toInt();
      }
    }

    final jenisLabel = keperluan.isNotEmpty ? _jenisKegiatanLabel(keperluan) : '-';
    final jenisColor = keperluan.isNotEmpty
        ? _jenisKegiatanColor(keperluan)
        : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
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
                      color: Colors.green.shade700.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
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
                                platNomor,
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
                                namaKendaraan,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Status DONE badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Selesai',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Jenis kegiatan badge
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
                                jenisLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: jenisColor,
                                ),
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

              // ── Detail Rows ──
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
                icon: Icons.place_outlined,
                label: 'Tujuan',
                value: tujuan,
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Tanggal',
                value:
                    '${_formatDate(waktuPinjam)} – ${_formatDate(waktuKembali)}',
              ),
              if (jarakTempuh != null) ...[
                const SizedBox(height: 10),
                _buildDetailRow(
                  icon: Icons.speed_outlined,
                  label: 'Jarak Tempuh',
                  value: '${_formatNumber(jarakTempuh)} km',
                  valueColor: Colors.green.shade700,
                ),
              ],

              const SizedBox(height: 16),

              // ── Footer ──
              Row(
                children: [
                  Icon(Icons.access_time_outlined,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(
                    'Diajukan: ${_formatTimestamp(item['createdAt'] as Timestamp?)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
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
// Filter Bottom Sheet Widget
// ─────────────────────────────────────────
class _FilterBottomSheet extends StatefulWidget {
  final String selectedPeriode;
  final DateTimeRange? customDateRange;
  final String selectedKendaraan;
  final String selectedJenisKegiatan;
  final String selectedDivisi;
  final String sortOrder;
  final List<Map<String, String>> periodeOptions;
  final List<Map<String, String>> jenisKegiatanOptions;
  final List<String> kendaraanOptions;
  final List<String> divisiOptions;
  final bool showDivisi;
  final Function(String, DateTimeRange?, String, String, String, String)
      onApply;
  final VoidCallback onPickDateRange;

  const _FilterBottomSheet({
    required this.selectedPeriode,
    required this.customDateRange,
    required this.selectedKendaraan,
    required this.selectedJenisKegiatan,
    required this.selectedDivisi,
    required this.sortOrder,
    required this.periodeOptions,
    required this.jenisKegiatanOptions,
    required this.kendaraanOptions,
    required this.divisiOptions,
    required this.showDivisi,
    required this.onApply,
    required this.onPickDateRange,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _periode;
  late DateTimeRange? _customRange;
  late String _kendaraan;
  late String _jenisKegiatan;
  late String _divisi;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _periode = widget.selectedPeriode;
    _customRange = widget.customDateRange;
    _kendaraan = widget.selectedKendaraan;
    _jenisKegiatan = widget.selectedJenisKegiatan;
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
            // Handle
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
                Text(
                  'Filter & Urutkan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _periode = 'SEMUA';
                      _customRange = null;
                      _kendaraan = 'SEMUA';
                      _jenisKegiatan = 'SEMUA';
                      _divisi = 'SEMUA';
                      _sort = 'TERBARU';
                    });
                  },
                  child: Text(
                    'Reset',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
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
                  onTap: () => setState(() => _sort = 'TERBARU'),
                ),
                const SizedBox(width: 8),
                _buildSelectChip(
                  label: 'Terlama',
                  isSelected: _sort == 'TERLAMA',
                  onTap: () => setState(() => _sort = 'TERLAMA'),
                ),
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
                    onTap: () {
                      // onPickDateRange sudah handle: pop bottom sheet + buka date picker
                      widget.onPickDateRange();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected && _customRange != null
                            ? Colors.blue.shade700
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected && _customRange != null
                              ? Colors.blue.shade700
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
                                ? DateFormat('dd/MM/yy').format(_customRange!.start) +
                                    ' – ' +
                                    DateFormat('dd/MM/yy').format(_customRange!.end)
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

            // ── Jenis Kegiatan ──
            _buildSectionLabel('Jenis Kegiatan'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.jenisKegiatanOptions.map((opt) {
                return _buildSelectChip(
                  label: opt['label']!,
                  isSelected: _jenisKegiatan == opt['key'],
                  onTap: () => setState(() => _jenisKegiatan = opt['key']!),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Kendaraan ──
            _buildSectionLabel('Kendaraan'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _kendaraan,
                  isExpanded: true,
                  icon: Icon(Icons.expand_more, color: Colors.grey.shade600),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  items: widget.kendaraanOptions.map((k) {
                    return DropdownMenuItem(
                      value: k,
                      child: Text(
                        k == 'SEMUA' ? 'Semua Kendaraan' : k,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _kendaraan = val);
                  },
                ),
              ),
            ),

            // ── Divisi (admin/operator only) ──
            if (widget.showDivisi) ...[
              const SizedBox(height: 20),
              _buildSectionLabel('Divisi'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _divisi,
                    isExpanded: true,
                    icon: Icon(Icons.expand_more, color: Colors.grey.shade600),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
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

            // ── Apply Button ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_periode, _customRange, _kendaraan,
                      _jenisKegiatan, _divisi, _sort);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Terapkan Filter',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
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