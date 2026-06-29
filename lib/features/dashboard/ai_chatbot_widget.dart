import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const String _kGeminiApiKey = 'AIzaSyAa5sGGmTVmaDIP5ZWB1-vvDcQr2SAjkTA';
const String _kGeminiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isLoading;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
    this.isLoading = false,
  }) : time = time ?? DateTime.now();
}

class _FirebaseDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Jadwal meeting mendatang
  Future<List<Map<String, dynamic>>> getMeetingSchedules() async {
    try {
      final snap = await _db.collection('room_bookings').where(
        'status',
        whereIn: ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3'],
      ).get();

      final now = DateTime.now();
      final list = snap.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).where((b) {
        final mulai = (b['waktuMulai'] as Timestamp?)?.toDate();
        return mulai != null && mulai.isAfter(now.subtract(const Duration(hours: 1)));
      }).toList();

      list.sort((a, b) {
        final aT = (a['waktuMulai'] as Timestamp?)?.toDate() ?? DateTime(9999);
        final bT = (b['waktuMulai'] as Timestamp?)?.toDate() ?? DateTime(9999);
        return aT.compareTo(bT);
      });
      return list;
    } catch (e) {
      return [];
    }
  }

  // Jadwal kendaraan mendatang
  Future<List<Map<String, dynamic>>> getVehicleSchedules() async {
    try {
      final snap = await _db.collection('vehicle_bookings').where(
        'status',
        whereIn: ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'ON_GOING'],
      ).get();

      final now = DateTime.now();
      final list = snap.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).where((b) {
        final pinjam = (b['waktuPinjam'] as Timestamp?)?.toDate();
        return pinjam != null && pinjam.isAfter(now.subtract(const Duration(hours: 1)));
      }).toList();

      list.sort((a, b) {
        final aT = (a['waktuPinjam'] as Timestamp?)?.toDate() ?? DateTime(9999);
        final bT = (b['waktuPinjam'] as Timestamp?)?.toDate() ?? DateTime(9999);
        return aT.compareTo(bT);
      });
      return list;
    } catch (e) {
      return [];
    }
  }

  // Semua kendaraan beserta detail lengkap
  Future<List<Map<String, dynamic>>> getAllVehicles() async {
    try {
      final snap = await _db.collection('vehicles').get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  // Semua ruang meeting beserta detail lengkap
  Future<List<Map<String, dynamic>>> getAllRooms() async {
    try {
      final snap = await _db.collection('rooms').get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  // Status ruang saat ini
  Future<Map<String, dynamic>> getRoomStatus() async {
    try {
      final now = Timestamp.now();
      final totalSnap = await _db
          .collection('rooms')
          .where('status', isEqualTo: 'available')
          .get();
      final activeSnap = await _db
          .collection('room_bookings')
          .where('status', isEqualTo: 'APPROVAL_3')
          .where('waktuMulai', isLessThanOrEqualTo: now)
          .where('waktuSelesai', isGreaterThan: now)
          .get();
      final busyIds = activeSnap.docs
          .map((d) => d.data()['ruang']?['roomId'] as String?)
          .where((id) => id != null)
          .toSet();
      return {
        'total': totalSnap.docs.length,
        'tersedia': totalSnap.docs.length - busyIds.length,
        'terpakai': busyIds.length,
      };
    } catch (e) {
      return {'total': 0, 'tersedia': 0, 'terpakai': 0};
    }
  }

  // Status kendaraan saat ini
  Future<Map<String, dynamic>> getVehicleStatus() async {
    try {
      final totalSnap = await _db
          .collection('vehicles')
          .where('statusAktif', isEqualTo: true)
          .get();
      final ongoingSnap = await _db
          .collection('vehicle_bookings')
          .where('status', isEqualTo: 'ON_GOING')
          .get();
      final usedIds = ongoingSnap.docs
          .map((d) => d.data()['vehicleId'] as String?)
          .where((id) => id != null)
          .toSet();
      return {
        'total': totalSnap.docs.length,
        'tersedia': totalSnap.docs.length - usedIds.length,
        'dipakai': usedIds.length,
      };
    } catch (e) {
      return {'total': 0, 'tersedia': 0, 'dipakai': 0};
    }
  }

  // Jadwal berdasarkan tanggal tertentu
  Future<Map<String, dynamic>> getScheduleByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final meetingSnap = await _db
          .collection('room_bookings')
          .where('status', whereIn: ['APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3']).get();
      final meetings = meetingSnap.docs.map((d) => {'id': d.id, ...d.data()}).where((b) {
        final t = (b['waktuMulai'] as Timestamp?)?.toDate();
        return t != null && t.isAfter(startOfDay) && t.isBefore(endOfDay);
      }).toList();

      final vehicleSnap = await _db
          .collection('vehicle_bookings')
          .where('status', whereIn: ['APPROVAL_2', 'APPROVAL_3', 'ON_GOING']).get();
      final vehicles = vehicleSnap.docs.map((d) => {'id': d.id, ...d.data()}).where((b) {
        final t = (b['waktuPinjam'] as Timestamp?)?.toDate();
        return t != null && t.isAfter(startOfDay) && t.isBefore(endOfDay);
      }).toList();

      return {'meetings': meetings, 'vehicles': vehicles};
    } catch (e) {
      return {'meetings': [], 'vehicles': []};
    }
  }
}

// ============================================================
// GEMINI AI SERVICE
// ============================================================
class _GeminiService {
  final _dataService = _FirebaseDataService();

  String _fmt(DateTime? dt) =>
      dt == null ? '-' : DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);

  String _statusLabel(String s) {
    const m = {
      'SUBMITTED': 'Menunggu Approval Manager Divisi',
      'APPROVAL_1': 'Disetujui Manager Divisi',
      'APPROVAL_2': 'Disetujui Operator',
      'APPROVAL_3': 'Disetujui Manager Umum',
      'ON_GOING': 'Sedang Berjalan',
      'DONE': 'Selesai',
      'CANCELLED': 'Dibatalkan',
    };
    return m[s] ?? s;
  }

  // Hapus semua simbol markdown agar tidak muncul ** di layar
  String _cleanMarkdown(String text) {
    String result = text;
    // **teks** → teks  (harus sebelum * tunggal)
    result = result.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // *teks* → teks
    result = result.replaceAllMapped(
      RegExp(r'\*(.+?)\*', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // __teks__ → teks
    result = result.replaceAllMapped(
      RegExp(r'__(.+?)__', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // _teks_ → teks
    result = result.replaceAllMapped(
      RegExp(r'_(.+?)_', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // ### heading → hapus simbol #
    result = result.replaceAll(RegExp(r'#{1,6} ?'), '');
    return result;
  }

  // Kumpulkan konteks data dari Firebase sesuai pertanyaan user
  Future<String> _buildContext(String userMessage) async {
    final msg = userMessage.toLowerCase();
    final buf = StringBuffer();

    final wantMeeting = msg.contains('meeting') ||
        msg.contains('rapat') ||
        msg.contains('ruang') ||
        msg.contains('jadwal') ||
        msg.contains('semua') ||
        msg.contains('hari ini');

    final wantVehicle = msg.contains('kendaraan') ||
        msg.contains('mobil') ||
        msg.contains('nopol') ||
        msg.contains('plat') ||
        msg.contains('peminjaman') ||
        msg.contains('jadwal') ||
        msg.contains('semua') ||
        msg.contains('hari ini');

    // ── RUANG MEETING ─────────────────────────────────────────
    if (wantMeeting) {
      // Daftar semua ruang
      final rooms = await _dataService.getAllRooms();
      buf.writeln('\n=== DAFTAR RUANG MEETING ===');
      for (final r in rooms) {
        final fasilitas = (r['fasilitas'] as List?)?.join(', ') ?? '-';
        buf.writeln(
          'Nama: ${r['namaRuang'] ?? '-'}'
          ' | Lokasi: ${r['lokasi'] ?? '-'}'
          ' | Kapasitas: ${r['kapasitas'] ?? '-'} orang'
          ' | Tipe: ${r['tipe'] ?? '-'}'
          ' | Fasilitas: $fasilitas'
          ' | Status: ${r['status'] ?? '-'}',
        );
      }

      // Status ruang sekarang
      final rs = await _dataService.getRoomStatus();
      buf.writeln(
        '\n=== STATUS RUANG SEKARANG ==='
        '\nTotal: ${rs['total']} | Kosong: ${rs['tersedia']} | Dipakai: ${rs['terpakai']}',
      );

      // Jadwal booking mendatang
      final meetings = await _dataService.getMeetingSchedules();
      buf.writeln('\n=== JADWAL BOOKING RUANG MEETING (mendatang) ===');
      if (meetings.isEmpty) {
        buf.writeln('Tidak ada jadwal meeting mendatang.');
      } else {
        for (final m in meetings.take(15)) {
          final peminjam = m['peminjam'] as Map? ?? {};
          final ruang = m['ruang'] as Map? ?? {};
          final mulai = (m['waktuMulai'] as Timestamp?)?.toDate();
          final selesai = (m['waktuSelesai'] as Timestamp?)?.toDate();
          final konsumsi = (m['konsumsi'] as List?)?.join(', ') ?? 'tidak ada';
          buf.writeln(
            'Kegiatan: ${m['namaKegiatan'] ?? '-'}'
            ' | Ruang: ${ruang['namaRuang'] ?? m['namaRuang'] ?? '-'}'
            ' | Lokasi: ${ruang['lokasi'] ?? m['lokasiRuang'] ?? '-'}'
            ' | Peminjam: ${peminjam['nama'] ?? '-'}'
            ' | Divisi: ${peminjam['divisi'] ?? '-'}'
            ' | Mulai: ${_fmt(mulai)}'
            ' | Selesai: ${_fmt(selesai)}'
            ' | Jenis: ${m['jenisRapat'] ?? '-'}'
            ' | Peserta: ${m['peserta'] ?? '-'} orang'
            ' | Konsumsi: $konsumsi'
            ' | Status: ${_statusLabel(m['status'] ?? '')}',
          );
        }
      }
    }

    // ── KENDARAAN ─────────────────────────────────────────────
    if (wantVehicle) {
      // Daftar semua kendaraan
      final allVehicles = await _dataService.getAllVehicles();
      buf.writeln('\n=== DAFTAR SEMUA KENDARAAN ===');
      for (final v in allVehicles) {
        final kelengkapan = (v['kelengkapan'] as List?)?.join(', ') ?? '-';
        buf.writeln(
          'Nama: ${v['nama'] ?? '-'}'
          ' | Nopol: ${v['platNomor'] ?? '-'}'
          ' | Jenis: ${v['jenis'] ?? '-'}'
          ' | Tahun: ${v['tahun'] ?? '-'}'
          ' | Kursi: ${v['kursi'] ?? '-'}'
          ' | BBM: ${v['bbm'] ?? '-'}'
          ' | Transmisi: ${v['transmisi'] ?? '-'}'
          ' | Odometer: ${v['odometerTerakhir'] ?? '-'} km'
          ' | Aktif: ${v['statusAktif'] == true ? 'Ya' : 'Tidak'}'
          ' | Kelengkapan: $kelengkapan',
        );
      }

      // Status kendaraan sekarang
      final vs = await _dataService.getVehicleStatus();
      buf.writeln(
        '\n=== STATUS KENDARAAN SEKARANG ==='
        '\nTotal: ${vs['total']} | Tersedia: ${vs['tersedia']} | Dipakai: ${vs['dipakai']}',
      );

      // Jadwal peminjaman mendatang
      final bookings = await _dataService.getVehicleSchedules();
      buf.writeln('\n=== JADWAL PEMINJAMAN KENDARAAN (mendatang) ===');
      if (bookings.isEmpty) {
        buf.writeln('Tidak ada jadwal peminjaman kendaraan mendatang.');
      } else {
        for (final b in bookings.take(15)) {
          final vehicle = b['vehicle'] as Map? ?? {};
          final pinjam = (b['waktuPinjam'] as Timestamp?)?.toDate();
          final kembali = (b['waktuKembali'] as Timestamp?)?.toDate();
          buf.writeln(
            'Kendaraan: ${vehicle['nama'] ?? '-'}'
            ' | Nopol: ${vehicle['platNomor'] ?? '-'}'
            ' | Jenis: ${vehicle['jenis'] ?? '-'}'
            ' | Tahun: ${vehicle['tahun'] ?? '-'}'
            ' | Peminjam: ${b['namaPeminjam'] ?? '-'}'
            ' | Divisi: ${b['divisi'] ?? '-'}'
            ' | Keperluan: ${b['keperluan'] ?? '-'}'
            ' | Tujuan: ${b['tujuan'] ?? '-'}'
            ' | Pinjam: ${_fmt(pinjam)}'
            ' | Kembali: ${_fmt(kembali)}'
            ' | Status: ${_statusLabel(b['status'] ?? '')}',
          );
        }
      }
    }

    // ── CEK TANGGAL TERTENTU ──────────────────────────────────
    final dateRe = RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{4}))?\b');
    final dateMatch = dateRe.firstMatch(msg);
    if (dateMatch != null) {
      try {
        final day = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final year = int.tryParse(dateMatch.group(3) ?? '') ?? DateTime.now().year;
        final targetDate = DateTime(year, month, day);
        final schedule = await _dataService.getScheduleByDate(targetDate);
        final dateStr = DateFormat('dd MMMM yyyy', 'id_ID').format(targetDate);

        buf.writeln('\n=== JADWAL TANGGAL $dateStr ===');
        final ms = schedule['meetings'] as List;
        final vs = schedule['vehicles'] as List;
        buf.writeln('Jumlah meeting: ${ms.length}');
        for (final m in ms) {
          final peminjam = m['peminjam'] as Map? ?? {};
          final ruang = m['ruang'] as Map? ?? {};
          final mulai = (m['waktuMulai'] as Timestamp?)?.toDate();
          final selesai = (m['waktuSelesai'] as Timestamp?)?.toDate();
          buf.writeln(
            '  - ${m['namaKegiatan'] ?? '-'}'
            ' | Ruang: ${ruang['namaRuang'] ?? '-'}'
            ' | ${_fmt(mulai)} s/d ${_fmt(selesai)}'
            ' | Peminjam: ${peminjam['nama'] ?? '-'}',
          );
        }
        buf.writeln('Jumlah kendaraan: ${vs.length}');
        for (final v in vs) {
          final vehicle = v['vehicle'] as Map? ?? {};
          final pinjam = (v['waktuPinjam'] as Timestamp?)?.toDate();
          buf.writeln(
            '  - ${vehicle['nama'] ?? '-'} (${vehicle['platNomor'] ?? '-'})'
            ' | ${v['namaPeminjam'] ?? '-'}'
            ' | ${_fmt(pinjam)}',
          );
        }
      } catch (_) {}
    }

    return buf.toString();
  }

  // Kirim pesan ke Gemini dan kembalikan teks bersih
  Future<String> sendMessage(String userMessage, List<Map<String, String>> history) async {
    try {
      final context = await _buildContext(userMessage);

      final systemPrompt =
          'Kamu adalah asisten bernama PINTRA AI untuk sistem peminjaman '
          'kendaraan dan ruang meeting di Pelindo. '
          'Gunakan data Firebase di bawah untuk menjawab dengan detail dan akurat. '
          'Sebutkan nopol, nama ruang, kapasitas, fasilitas, dan info spesifik lainnya jika ditanya.\n\n'
          'DATA:\n$context\n\n'
          'ATURAN WAJIB:\n'
          '- Jawab dalam Bahasa Indonesia yang ramah.\n'
          '- DILARANG menggunakan format markdown seperti **teks**, *teks*, __teks__, atau # heading.\n'
          '- Gunakan tanda strip (-) untuk membuat list.\n'
          '- Boleh pakai emoji secukupnya.\n'
          '- Jawaban singkat, padat, mudah dibaca di layar HP.';

      final contents = <Map<String, dynamic>>[];
      for (final msg in history.take(10)) {
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [{'text': msg['content'] ?? ''}],
        });
      }
      contents.add({
        'role': 'user',
        'parts': [{'text': userMessage}],
      });

      final response = await http.post(
        Uri.parse('$_kGeminiUrl?key=$_kGeminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [{'text': systemPrompt}],
          },
          'contents': contents,
          'generationConfig': {
            'temperature': 0.6,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['candidates']?[0]?['content']?['parts']?[0]?['text']
            ?? 'Maaf, tidak ada respons dari AI.';
        return _cleanMarkdown(raw);
      } else {
        return 'Maaf, terjadi kesalahan server (${response.statusCode}). Coba lagi.';
      }
    } catch (e) {
      return 'Maaf, terjadi kesalahan koneksi. Periksa internet kamu.';
    }
  }
}

// ============================================================
// WIDGET UTAMA — AI CHATBOT POPUP
// ============================================================
class AIChatbotWidget extends StatefulWidget {
  final String? userId;
  final String? userDivision;
  final String? userName;

  const AIChatbotWidget({
    super.key,
    this.userId,
    this.userDivision,
    this.userName,
  });

  @override
  State<AIChatbotWidget> createState() => _AIChatbotWidgetState();
}

class _AIChatbotWidgetState extends State<AIChatbotWidget>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  bool _isTyping = false;
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _history = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _gemini = _GeminiService();
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  final List<String> _quickActions = [
    '📅 Jadwal meeting hari ini',
    '🚗 Daftar kendaraan tersedia',
    '🏢 Status ruang meeting',
    '📋 Jadwal peminjaman kendaraan',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);

    _messages.add(ChatMessage(
      text: 'Halo${widget.userName != null ? ', ${widget.userName}' : ''}! 👋\n\n'
          'Saya PINTRA AI, asisten virtual peminjaman kendaraan dan ruang meeting.\n\n'
          'Saya bisa membantu:\n'
          '- Cek jadwal meeting dan kendaraan\n'
          '- Info detail ruang (kapasitas, fasilitas, lokasi)\n'
          '- Info detail kendaraan (nopol, jenis, tahun)\n'
          '- Status ketersediaan\n\n'
          'Ada yang bisa dibantu?',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _inputController.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(ChatMessage(text: '', isUser: false, isLoading: true));
      _isTyping = true;
    });
    _scrollToBottom();

    _history.add({'role': 'user', 'content': text});
    final reply = await _gemini.sendMessage(text, List.from(_history));
    _history.add({'role': 'assistant', 'content': reply});

    setState(() {
      _messages.removeLast();
      _messages.add(ChatMessage(text: reply, isUser: false));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  Widget _buildBubble(ChatMessage msg) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 8, right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [0, 1, 2].map((i) => _dot(i)).toList(),
          ),
        ),
      );
    }

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: msg.isUser ? 48 : 8,
          right: msg.isUser ? 8 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isUser ? Colors.blue.shade700 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 18),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                color: msg.isUser ? Colors.white : Colors.grey.shade800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.time),
              style: TextStyle(
                fontSize: 10,
                color: msg.isUser ? Colors.white.withOpacity(0.7) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (_, v, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.blue.shade300.withOpacity(v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return ScaleTransition(
      scale: _scaleAnim,
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          width: 320,
          height: 500,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PINTRA AI',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            _isTyping ? 'Sedang mencari data...' : 'Online',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: _toggleChat,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              // Pesan
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _buildBubble(_messages[i]),
                ),
              ),

              // Quick actions
              if (_messages.length <= 2)
                Container(
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickActions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _sendMessage(_quickActions[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          _quickActions[i],
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 6),

              // Input
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Tanya sesuatu...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          isDense: true,
                        ),
                        onSubmitted: _isTyping ? null : _sendMessage,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isTyping ? null : () => _sendMessage(_inputController.text),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _isTyping ? Colors.grey.shade300 : Colors.blue.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isTyping ? Icons.hourglass_empty : Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isOpen) ...[
            _buildChatPanel(),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: _toggleChat,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isOpen
                      ? [Colors.red.shade400, Colors.red.shade600]
                      : [Colors.blue.shade500, Colors.blue.shade800],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isOpen ? Colors.red : Colors.blue).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isOpen ? Icons.close_rounded : Icons.smart_toy_rounded,
                  key: ValueKey(_isOpen),
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}