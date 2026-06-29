import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'dart:async' show TimeoutException;

class ApprovalNotificationService {
  static const String WA_API_URL = 'https://api.watzap.id/v1/send_message';
  static const String WA_API_KEY = 'V3ELWOCBWBWHDEMX';
  static const String WA_NUMBER_KEY = 'RpIykFL9oV4ChXpz';

  static Future<String> generateApprovalToken(
    String bookingId,
    String userId, {
    String bookingType = 'vehicle',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomString = DateTime.now().microsecondsSinceEpoch.toString();
    final data = '$bookingId|$userId|$timestamp|$randomString';

    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes).toString();

    await FirebaseFirestore.instance
        .collection('approval_tokens')
        .doc(hash)
        .set({
      'bookingId': bookingId,
      'userId': userId,
      'token': hash,
      'bookingType': bookingType,
      'createdAt': Timestamp.now(),
      'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24))),
      'used': false,
    });

    return hash;
  }

  static Future<Map<String, dynamic>?> validateToken(String token) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('approval_tokens')
          .doc(token)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final used = data['used'] as bool;

      if (DateTime.now().isAfter(expiresAt) || used) {
        return null;
      }

      return data;
    } catch (e) {
      print('Error validating token: $e');
      return null;
    }
  }

  static Future<void> markTokenAsUsed(String token) async {
    await FirebaseFirestore.instance
        .collection('approval_tokens')
        .doc(token)
        .update({'used': true, 'usedAt': Timestamp.now()});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── VEHICLE BOOKING NOTIFICATIONS ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<bool> sendApprovalNotificationToManagerDivisi({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final divisi = bookingData['divisi'];
      print('🔍 Mencari manager untuk divisi: $divisi');

      final managerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .where('divisi', isEqualTo: divisi)
          .get();

      final managers = managerQuery.docs.where((doc) {
        final jabatan = (doc.data()['jabatan'] ?? '').toLowerCase();
        return jabatan.contains('manager');
      }).toList();

      if (managers.isEmpty) {
        print('❌ Manager Divisi tidak ditemukan untuk divisi: $divisi');
        return false;
      }

      final managerData = managers.first.data();
      final managerId = managers.first.id;
      final managerPhone = managerData['noTelp']?.toString() ?? '';

      if (managerPhone.isEmpty) {
        print('❌ Nomor WA Manager tidak ditemukan');
        return false;
      }

      final token = await generateApprovalToken(bookingId, managerId);
      final rawLink =
          'https://pintra-mobile.web.app/approval?bookingId=$bookingId&token=$token';
      final approvalLink = '<$rawLink>';

      final message = await _buildVehicleApprovalMessage(
        bookingData: bookingData,
        approvalLink: approvalLink,
        managerName: managerData['nama'] ?? 'Manager',
      );

      return await _sendWhatsApp(managerPhone, message);
    } catch (e, stackTrace) {
      print('❌ Error sending notification to Manager Divisi: $e');
      print('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> sendApprovalNotificationToManagerUmum({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final managerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      if (managerQuery.docs.isEmpty) {
        print('Manager Umum / Admin tidak ditemukan');
        return false;
      }

      bool atLeastOneSuccess = false;

      for (final doc in managerQuery.docs) {
        final managerData = doc.data();
        final managerId = doc.id;
        final managerPhone = managerData['noTelp']?.toString() ?? '';

        if (managerPhone.isEmpty) continue;

        final token = await generateApprovalToken(bookingId, managerId);
        final rawLink =
            'https://pintra-mobile.web.app/approval?bookingId=$bookingId&token=$token';
        final approvalLink = '<$rawLink>';

        final message = await _buildVehicleApprovalMessage(
          bookingData: bookingData,
          approvalLink: approvalLink,
          managerName: managerData['nama'] ?? 'Manager',
        );

        final result = await _sendWhatsApp(managerPhone, message);
        if (result) atLeastOneSuccess = true;

        await Future.delayed(const Duration(seconds: 5));
      }

      return atLeastOneSuccess;
    } catch (e) {
      print('Error sending notification to Manager Umum: $e');
      return false;
    }
  }

  static Future<bool> sendApprovalNotificationToOperator({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final operatorQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'operator')
          .get();

      final operatorDocs = operatorQuery.docs.where((doc) {
        final opType = doc.data()['operatorType'] as String?;
        return opType == null || opType == 'kendaraan';
      }).toList();

      bool atLeastOneSuccess = false;

      for (final doc in operatorDocs) {
        final operatorData = doc.data();
        final operatorId = doc.id;
        final operatorPhone = operatorData['noTelp']?.toString() ?? '';

        if (operatorPhone.isEmpty) continue;

        final token = await generateApprovalToken(bookingId, operatorId);
        final rawLink =
            'https://pintra-mobile.web.app/approval?bookingId=$bookingId&token=$token';
        final approvalLink = '<$rawLink>';

        final message = await _buildVehicleApprovalMessage(
          bookingData: bookingData,
          approvalLink: approvalLink,
          managerName: operatorData['nama'] ?? 'Operator',
        );

        final result = await _sendWhatsApp(operatorPhone, message);
        if (result) atLeastOneSuccess = true;

        await Future.delayed(const Duration(seconds: 5));
      }

      return atLeastOneSuccess;
    } catch (e) {
      print('Error sending notification to Operators: $e');
      return false;
    }
  }

  static Future<String> _buildVehicleApprovalMessage({
    required Map<String, dynamic> bookingData,
    required String approvalLink,
    required String managerName,
  }) async {
    final waktuPinjam = bookingData['waktuPinjam'] is Timestamp
        ? (bookingData['waktuPinjam'] as Timestamp).toDate()
        : null;
    final waktuKembali = bookingData['waktuKembali'] is Timestamp
        ? (bookingData['waktuKembali'] as Timestamp).toDate()
        : null;

    final tglPinjam = waktuPinjam != null
        ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuPinjam)
        : '-';
    final tglKembali = waktuKembali != null
        ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuKembali)
        : '-';

    String nipp = bookingData['nipp']?.toString() ?? '';

    if (nipp.isEmpty) {
      try {
        final peminjamId = bookingData['peminjamId'];
        if (peminjamId != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(peminjamId)
              .get();
          if (userDoc.exists) {
            nipp = userDoc.data()?['nipp']?.toString() ?? '-';
          } else {
            nipp = '-';
          }
        } else {
          nipp = '-';
        }
      } catch (e) {
        nipp = '-';
      }
    }

    return '''
*APPROVAL PEMINJAMAN KENDARAAN*

Yth. $managerName,

Terdapat pengajuan peminjaman kendaraan yang memerlukan persetujuan Anda:

*Detail Peminjaman:*
- ID Pemesanan: ${bookingData['id']}
- Nama: ${bookingData['namaPeminjam']}
- NIPP: $nipp
- Divisi: ${bookingData['divisi']}
- Kendaraan: ${bookingData['vehicle']?['nama'] ?? '-'} (${bookingData['vehicle']?['platNomor'] ?? '-'})
- Tujuan: ${bookingData['tujuan']}
- Keperluan: ${bookingData['keperluan']}

📅 *Jadwal:*
- Pinjam: $tglPinjam
- Kembali: $tglKembali

*Klik link untuk approve/reject:*


$approvalLink


*Link berlaku 24 jam*

---
_Pintra_
''';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── ROOM BOOKING NOTIFICATIONS ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<bool> sendRoomApprovalNotificationToManagerDivisi({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final divisi = bookingData['peminjam']?['divisi'] ?? bookingData['divisi'] ?? '';
      print('🔍 [Room] Mencari manager divisi: $divisi');

      final managerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .where('divisi', isEqualTo: divisi)
          .get();

      final managers = managerQuery.docs.where((doc) {
        final jabatan = (doc.data()['jabatan'] ?? '').toLowerCase();
        return jabatan.contains('manager');
      }).toList();

      if (managers.isEmpty) {
        print('❌ [Room] Manager Divisi tidak ditemukan untuk divisi: $divisi');
        return false;
      }

      final managerData = managers.first.data();
      final managerId = managers.first.id;
      final managerPhone = managerData['noTelp']?.toString() ?? '';

      if (managerPhone.isEmpty) {
        print('❌ [Room] Nomor WA Manager tidak ditemukan');
        return false;
      }

      final token = await generateApprovalToken(
        bookingId,
        managerId,
        bookingType: 'room',
      );
      final rawLink =
          'https://pintra-mobile.web.app/room-approval?bookingId=$bookingId&token=$token';
      final approvalLink = '<$rawLink>';

      final message = _buildRoomApprovalMessage(
        bookingData: bookingData,
        approvalLink: approvalLink,
        recipientName: managerData['nama'] ?? 'Manager',
        recipientRole: 'Manager Divisi',
      );

      final result = await _sendWhatsApp(managerPhone, message);
      print(result
          ? '✅ [Room] Notif WA terkirim ke Manager Divisi ${managerData['nama']}'
          : '❌ [Room] Gagal kirim WA ke Manager Divisi');
      return result;
    } catch (e, st) {
      print('❌ [Room] Error sendRoomApprovalNotificationToManagerDivisi: $e');
      print('📍 $st');
      return false;
    }
  }

  static Future<bool> sendRoomApprovalNotificationToOperator({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final operatorQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'operator')
          .get();

      final operatorDocs = operatorQuery.docs.where((doc) {
        final opType = doc.data()['operatorType'] as String?;
        return opType == null || opType == 'ruang_meeting';
      }).toList();

      if (operatorDocs.isEmpty) {
        print('❌ [Room] Operator tidak ditemukan');
        return false;
      }

      bool atLeastOneSuccess = false;

      for (final doc in operatorDocs) {
        final operatorData = doc.data();
        final operatorId = doc.id;
        final operatorPhone = operatorData['noTelp']?.toString() ?? '';

        if (operatorPhone.isEmpty) continue;

        final token = await generateApprovalToken(
          bookingId,
          operatorId,
          bookingType: 'room',
        );
        final rawLink =
            'https://pintra-mobile.web.app/room-approval?bookingId=$bookingId&token=$token';
        final approvalLink = '<$rawLink>';

        final message = _buildRoomApprovalMessage(
          bookingData: bookingData,
          approvalLink: approvalLink,
          recipientName: operatorData['nama'] ?? 'Operator',
          recipientRole: 'Operator',
        );

        final result = await _sendWhatsApp(operatorPhone, message);
        if (result) atLeastOneSuccess = true;

        print(result
            ? '✅ [Room] Notif WA terkirim ke Operator ${operatorData['nama']}'
            : '❌ [Room] Gagal kirim ke Operator ${operatorData['nama']}');

        await Future.delayed(const Duration(seconds: 5));
      }

      return atLeastOneSuccess;
    } catch (e) {
      print('Error [Room] sendRoomApprovalNotificationToOperator: $e');
      return false;
    }
  }

  static Future<bool> sendRoomApprovalNotificationToManagerUmum({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      if (adminQuery.docs.isEmpty) {
        print('❌ [Room] Admin/Manager Umum tidak ditemukan');
        return false;
      }

      bool atLeastOneSuccess = false;

      for (final doc in adminQuery.docs) {
        final adminData = doc.data();
        final adminId = doc.id;
        final adminPhone = adminData['noTelp']?.toString() ?? '';

        if (adminPhone.isEmpty) continue;

        final token = await generateApprovalToken(
          bookingId,
          adminId,
          bookingType: 'room',
        );
        final rawLink =
            'https://pintra-mobile.web.app/room-approval?bookingId=$bookingId&token=$token';
        final approvalLink = '<$rawLink>';

        final message = _buildRoomApprovalMessage(
          bookingData: bookingData,
          approvalLink: approvalLink,
          recipientName: adminData['nama'] ?? 'Manager Umum',
          recipientRole: 'Manager Umum',
        );

        final result = await _sendWhatsApp(adminPhone, message);
        if (result) atLeastOneSuccess = true;

        print(result
            ? '✅ [Room] Notif WA terkirim ke Manager Umum ${adminData['nama']}'
            : '❌ [Room] Gagal kirim ke Manager Umum ${adminData['nama']}');

        await Future.delayed(const Duration(seconds: 5));
      }

      return atLeastOneSuccess;
    } catch (e) {
      print('Error [Room] sendRoomApprovalNotificationToManagerUmum: $e');
      return false;
    }
  }

  static Future<bool> sendRoomApprovedNotificationToPeminjam({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final peminjam = bookingData['peminjam'] as Map<String, dynamic>? ?? {};
      final peminjamId = peminjam['userId'] ?? bookingData['peminjamId'];

      if (peminjamId == null) {
        print('❌ [Room] peminjamId tidak ditemukan');
        return false;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peminjamId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final peminjamPhone = userData['noTelp']?.toString() ?? '';
      final peminjamName = userData['nama'] ?? peminjam['nama'] ?? 'Peminjam';

      if (peminjamPhone.isEmpty) return false;

      final waktuMulai = bookingData['waktuMulai'] is Timestamp
          ? (bookingData['waktuMulai'] as Timestamp).toDate()
          : null;
      final waktuSelesai = bookingData['waktuSelesai'] is Timestamp
          ? (bookingData['waktuSelesai'] as Timestamp).toDate()
          : null;

      final tglMulai = waktuMulai != null
          ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuMulai)
          : '-';
      final tglSelesai = waktuSelesai != null
          ? DateFormat('HH:mm', 'id_ID').format(waktuSelesai)
          : '-';

      final namaRuang = bookingData['namaRuang'] ??
          bookingData['ruang']?['namaRuang'] ??
          'Ruang Meeting';

      final message = '''
*PEMINJAMAN RUANG MEETING DISETUJUI* ✅

Yth. $peminjamName,

Selamat! Pengajuan peminjaman ruang meeting Anda telah *DISETUJUI PENUH*.

*Detail Peminjaman:*
- ID: ${bookingData['id']}
- Kegiatan: ${bookingData['namaKegiatan'] ?? '-'}
- Ruang: $namaRuang
- Waktu: $tglMulai – $tglSelesai

*LANGKAH SELANJUTNYA:*
📍 Silakan ambil akses ruang di *Resepsionis / Ruang Divisi Umum*
📋 Pastikan ruang dikembalikan dalam kondisi rapi setelah selesai

---
_Pintra_
''';

      return await _sendWhatsApp(peminjamPhone, message);
    } catch (e) {
      print('❌ [Room] Error sendRoomApprovedNotificationToPeminjam: $e');
      return false;
    }
  }

  static Future<bool> sendRoomRejectedNotificationToPeminjam({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required String rejectedBy,
    required String reason,
  }) async {
    try {
      final peminjam = bookingData['peminjam'] as Map<String, dynamic>? ?? {};
      final peminjamId = peminjam['userId'] ?? bookingData['peminjamId'];
      if (peminjamId == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peminjamId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final peminjamPhone = userData['noTelp']?.toString() ?? '';
      final peminjamName = userData['nama'] ?? peminjam['nama'] ?? 'Peminjam';

      if (peminjamPhone.isEmpty) return false;

      final namaRuang = bookingData['namaRuang'] ??
          bookingData['ruang']?['namaRuang'] ??
          'Ruang Meeting';

      final message = '''
*PEMINJAMAN RUANG MEETING DITOLAK* ❌

Yth. $peminjamName,

Mohon maaf, pengajuan peminjaman ruang meeting Anda *DITOLAK*.

*Detail Peminjaman:*
- ID: ${bookingData['id']}
- Kegiatan: ${bookingData['namaKegiatan'] ?? '-'}
- Ruang: $namaRuang

*Ditolak oleh:* $rejectedBy
*Alasan:* $reason

Silakan ajukan peminjaman baru atau hubungi $rejectedBy untuk informasi lebih lanjut.

---
_Pintra_
''';

      return await _sendWhatsApp(peminjamPhone, message);
    } catch (e) {
      print('❌ [Room] Error sendRoomRejectedNotificationToPeminjam: $e');
      return false;
    }
  }

  static String _buildRoomApprovalMessage({
    required Map<String, dynamic> bookingData,
    required String approvalLink,
    required String recipientName,
    required String recipientRole,
  }) {
    final peminjam = bookingData['peminjam'] as Map<String, dynamic>? ?? {};

    final waktuMulai = bookingData['waktuMulai'] is Timestamp
        ? (bookingData['waktuMulai'] as Timestamp).toDate()
        : null;
    final waktuSelesai = bookingData['waktuSelesai'] is Timestamp
        ? (bookingData['waktuSelesai'] as Timestamp).toDate()
        : null;

    final tglMulai = waktuMulai != null
        ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuMulai)
        : '-';
    final tglSelesai = waktuSelesai != null
        ? DateFormat('HH:mm', 'id_ID').format(waktuSelesai)
        : '-';

    final namaRuang = bookingData['namaRuang'] ??
        bookingData['ruang']?['namaRuang'] ??
        'Ruang Meeting';
    final lokasiRuang = bookingData['lokasiRuang'] ??
        bookingData['ruang']?['lokasi'] ??
        '-';

    return '''
*APPROVAL PEMINJAMAN RUANG MEETING*

Yth. $recipientName ($recipientRole),

Terdapat pengajuan peminjaman ruang meeting yang memerlukan persetujuan Anda:

*Detail Peminjaman:*
- ID Pemesanan: ${bookingData['id'] ?? '-'}
- Nama: ${peminjam['nama'] ?? bookingData['namaPeminjam'] ?? '-'}
- Divisi: ${peminjam['divisi'] ?? bookingData['divisi'] ?? '-'}
- Jabatan: ${peminjam['jabatan'] ?? '-'}
- Ruang: $namaRuang
- Lokasi: $lokasiRuang
- Kegiatan: ${bookingData['namaKegiatan'] ?? '-'}
- Jenis Rapat: ${bookingData['jenisRapat'] ?? '-'}
- Peserta: ${bookingData['peserta'] ?? '-'} orang
- Konsumsi: ${(bookingData['konsumsi'] as List?)?.join(', ') ?? 'Tidak ada'}
${(bookingData['konsumsiNote'] ?? '').toString().isNotEmpty ? '- Catatan Konsumsi: ${bookingData['konsumsiNote']}' : ''}
- Layout Ruangan: ${(bookingData['layoutRuangan'] ?? '').toString().isNotEmpty ? bookingData['layoutRuangan'] : 'Tidak ada catatan'}

📅 *Jadwal:*
- Mulai: $tglMulai
- Selesai: $tglSelesai

*Klik link untuk approve/reject:*


$approvalLink


*Link berlaku 24 jam*

---
_Pintra_
''';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── VEHICLE: PEMINJAM NOTIFICATIONS ────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<bool> sendApprovedNotificationToPeminjam({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final peminjamId = bookingData['peminjamId'];
      if (peminjamId == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peminjamId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final peminjamPhone = userData['noTelp']?.toString() ?? '';
      final peminjamName = userData['nama'] ?? 'Peminjam';

      if (peminjamPhone.isEmpty) return false;

      final waktuPinjam = bookingData['waktuPinjam'] is Timestamp
          ? (bookingData['waktuPinjam'] as Timestamp).toDate()
          : null;
      final tglPinjam = waktuPinjam != null
          ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuPinjam)
          : '-';

      final message = '''
*PEMINJAMAN KENDARAAN DISETUJUI* ✅

Yth. $peminjamName,

Selamat! Pengajuan peminjaman kendaraan Anda telah *DISETUJUI PENUH*.

*Detail Peminjaman:*
- ID: ${bookingData['id']}
- Kendaraan: ${bookingData['vehicle']?['nama'] ?? '-'} (${bookingData['vehicle']?['platNomor'] ?? '-'})
- Waktu Pinjam: $tglPinjam
- Tujuan: ${bookingData['tujuan']}

*LANGKAH SELANJUTNYA:*
📍 Silakan ambil kunci kendaraan di *Ruang Divisi Umum*
📋 Jangan lupa isi form kondisi kendaraan awal sebelum menggunakan

---
_Pintra_
''';

      return await _sendWhatsApp(peminjamPhone, message);
    } catch (e) {
      print('❌ Error sending approved notification: $e');
      return false;
    }
  }

  static Future<bool> sendRejectedNotificationToPeminjam({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required String rejectedBy,
    required String reason,
  }) async {
    try {
      final peminjamId = bookingData['peminjamId'];
      if (peminjamId == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peminjamId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final peminjamPhone = userData['noTelp']?.toString() ?? '';
      final peminjamName = userData['nama'] ?? 'Peminjam';

      if (peminjamPhone.isEmpty) return false;

      final message = '''
*PEMINJAMAN KENDARAAN DITOLAK* ❌

Yth. $peminjamName,

Mohon maaf, pengajuan peminjaman kendaraan Anda *DITOLAK*.

*Detail Peminjaman:*
- ID: ${bookingData['id']}
- Kendaraan: ${bookingData['vehicle']?['nama'] ?? '-'}
- Tujuan: ${bookingData['tujuan']}

*Ditolak oleh:* $rejectedBy
*Alasan:* $reason

Silakan ajukan peminjaman baru atau hubungi $rejectedBy untuk informasi lebih lanjut.

---
_Pesan otomatis dari Sistem Peminjaman Kendaraan_
''';

      return await _sendWhatsApp(peminjamPhone, message);
    } catch (e) {
      print('❌ Error sending rejected notification: $e');
      return false;
    }
  }

  // ─── UPDATED: Reminder berulang dengan reminderCount ─────────────────────
  static Future<bool> sendReturnReminderToPeminjam({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    int reminderCount = 1, // 1 = pertama (5 menit sebelum), 2+ = berulang setelah terlambat
  }) async {
    try {
      print('🔔 === RETURN REMINDER #$reminderCount START ===');
      final peminjamId = bookingData['peminjamId'];
      if (peminjamId == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peminjamId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final peminjamPhone = userData['noTelp']?.toString() ?? '';
      final peminjamName = userData['nama'] ?? 'Peminjam';

      if (peminjamPhone.isEmpty) return false;

      final waktuKembali = bookingData['waktuKembali'] is Timestamp
          ? (bookingData['waktuKembali'] as Timestamp).toDate()
          : null;

      if (waktuKembali == null) return false;

      final tglKembali =
          DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuKembali);

      final now = DateTime.now();
      final isOverdue = now.isAfter(waktuKembali);
      final overdueMinutes =
          isOverdue ? now.difference(waktuKembali).inMinutes : 0;

      String message;

      if (reminderCount == 1 && !isOverdue) {
        // ── Reminder pertama: 5 menit sebelum waktu kembali ──
        message = '''
*REMINDER PENGEMBALIAN KENDARAAN* ⏰

Yth. $peminjamName,

*SEGERA KEMBALIKAN KENDARAAN!*

Waktu pengembalian tinggal *5 MENIT* lagi:
⏰ *$tglKembali*

*Detail Peminjaman:*
- Kendaraan: ${bookingData['vehicle']?['nama'] ?? '-'} (${bookingData['vehicle']?['platNomor'] ?? '-'})
- Tujuan: ${bookingData['tujuan']}

📍 Segera kembalikan ke *Ruang Divisi Umum*
📋 Jangan lupa isi form pengembalian kendaraan

---
_Pintra_
''';
      } else {
        // ── Reminder berulang: setelah waktu kembali terlewat ──
        final overdueText = overdueMinutes < 60
            ? '$overdueMinutes menit'
            : '${(overdueMinutes / 60).floor()} jam ${overdueMinutes % 60} menit';

        message = '''
*⚠️ KETERLAMBATAN PENGEMBALIAN KENDARAAN* 🚨

Yth. $peminjamName,

Kendaraan Anda *BELUM DIKEMBALIKAN* dan sudah melewati batas waktu.

⏰ *Batas waktu:* $tglKembali
🕐 *Keterlambatan:* $overdueText
🔔 *Pengingat ke-$reminderCount*

*Detail Peminjaman:*
- Kendaraan: ${bookingData['vehicle']?['nama'] ?? '-'} (${bookingData['vehicle']?['platNomor'] ?? '-'})
- Tujuan: ${bookingData['tujuan']}

*SEGERA kembalikan kendaraan ke Ruang Divisi Umum!*
📋 Jangan lupa isi form pengembalian kendaraan

Pengingat akan terus dikirim setiap 30 menit hingga kendaraan dikembalikan.

---
_Pintra_
''';
      }

      return await _sendWhatsApp(peminjamPhone, message);
    } catch (e, st) {
      print('❌ Error sending reminder #$reminderCount: $e\n$st');
      return false;
    }
  }

  static Future<bool> sendAutoCancelledNotificationToPeminjam({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final peminjamId = bookingData['peminjamId'];
      if (peminjamId == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peminjamId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final peminjamPhone = userData['noTelp']?.toString() ?? '';
      final peminjamName = userData['nama'] ?? 'Peminjam';

      if (peminjamPhone.isEmpty) return false;

      final waktuPinjam = bookingData['waktuPinjam'] is Timestamp
          ? (bookingData['waktuPinjam'] as Timestamp).toDate()
          : null;
      final tglPinjam = waktuPinjam != null
          ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuPinjam)
          : '-';

      final message = '''
*PEMINJAMAN DIBATALKAN OTOMATIS* ⚠️

Yth. $peminjamName,

Peminjaman kendaraan Anda telah *DIBATALKAN OTOMATIS* oleh sistem.

*Alasan:* Melewati batas waktu pengambilan kendaraan tanpa approval penuh

*Detail Peminjaman:*
- ID: ${bookingData['id']}
- Kendaraan: ${bookingData['vehicle']?['nama'] ?? '-'}
- Waktu Pinjam: $tglPinjam (sudah terlewat)
- Tujuan: ${bookingData['tujuan']}

Silakan ajukan peminjaman baru dengan waktu yang sesuai.

---
_Pintra_
''';

      return await _sendWhatsApp(peminjamPhone, message);
    } catch (e) {
      print('❌ Error sending auto-cancelled notification: $e');
      return false;
    }
  }

  static Future<bool> sendCancellationRequestToAdmin({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required String requestedBy,
    required String reason,
  }) async {
    try {
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      if (adminQuery.docs.isEmpty) return false;

      final waktuPinjam = bookingData['waktuPinjam'] is Timestamp
          ? (bookingData['waktuPinjam'] as Timestamp).toDate()
          : null;
      final tglPinjam = waktuPinjam != null
          ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuPinjam)
          : '-';

      bool atLeastOneSuccess = false;

      for (final doc in adminQuery.docs) {
        final adminData = doc.data();
        final adminId = doc.id;
        final adminPhone = adminData['noTelp']?.toString() ?? '';

        if (adminPhone.isEmpty) continue;

        final token = await generateApprovalToken(bookingId, adminId);
        final rawLink =
            'https://pintra-mobile.web.app/cancellation-approval?bookingId=$bookingId&token=$token&requestedBy=${Uri.encodeComponent(requestedBy)}&reason=${Uri.encodeComponent(reason)}';
        final approvalLink = '<$rawLink>';

        final message = '''
*REQUEST PEMBATALAN PEMINJAMAN* ⚠️

Yth. ${adminData['nama'] ?? 'Admin'},

Operator *$requestedBy* mengajukan request pembatalan untuk peminjaman yang sudah disetujui.

*Detail Peminjaman:*
- ID: ${bookingData['id']}
- Nama Peminjam: ${bookingData['namaPeminjam']}
- Divisi: ${bookingData['divisi']}
- Kendaraan: ${bookingData['vehicle']?['nama'] ?? '-'} (${bookingData['vehicle']?['platNomor'] ?? '-'})
- Waktu Pinjam: $tglPinjam
- Tujuan: ${bookingData['tujuan']}

*Alasan Pembatalan dari Operator:*
$reason

*Klik link untuk menyetujui/menolak pembatalan:*

$approvalLink

*Link berlaku 24 jam*

---
_Pintra_
''';

        final result = await _sendWhatsApp(adminPhone, message);
        if (result) atLeastOneSuccess = true;

        await Future.delayed(const Duration(seconds: 5));
      }

      return atLeastOneSuccess;
    } catch (e) {
      print('Error sending cancellation request to Admin: $e');
      return false;
    }
  }

  static Future<bool> sendUnilateralCancellationToPeminjam({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required String cancelledBy,
    required String cancelledByRole,
    required String reason,
  }) async {
    try {
      final peminjamId = bookingData['peminjamId'];
      if (peminjamId == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(peminjamId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final peminjamPhone = userData['noTelp']?.toString() ?? '';
      final peminjamName = userData['nama'] ?? 'Peminjam';

      if (peminjamPhone.isEmpty) return false;

      final roleName = cancelledByRole == 'admin' ? 'Admin' : 'Operator';

      final message = '''
*PEMINJAMAN DIBATALKAN SEPIHAK* ❌

Yth. $peminjamName,

Mohon maaf, peminjaman kendaraan Anda yang telah disetujui telah *DIBATALKAN* oleh $roleName.

*Detail Peminjaman:*
- ID: ${bookingData['id']}
- Kendaraan: ${bookingData['vehicle']?['nama'] ?? '-'} (${bookingData['vehicle']?['platNomor'] ?? '-'})
- Tujuan: ${bookingData['tujuan']}

*Dibatalkan oleh:* $cancelledBy ($roleName)
*Alasan:* $reason

Silakan hubungi $roleName untuk informasi lebih lanjut atau ajukan peminjaman baru.

---
_Pintra_
''';

      return await _sendWhatsApp(peminjamPhone, message);
    } catch (e) {
      print('Error sending unilateral cancellation notification: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── WHATSAPP SENDER ────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<bool> _sendWhatsApp(String phoneNumber, String message) async {
    try {
      String formattedPhone = phoneNumber;
      if (!formattedPhone.startsWith('62')) {
        if (formattedPhone.startsWith('0')) {
          formattedPhone = '62${formattedPhone.substring(1)}';
        } else {
          formattedPhone = '62$formattedPhone';
        }
      }

      final requestBody = {
        'api_key': WA_API_KEY,
        'number_key': WA_NUMBER_KEY,
        'phone_no': formattedPhone,
        'message': message,
      };

      final response = await http
          .post(
            Uri.parse(WA_API_URL),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $WA_API_KEY',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('WhatsApp API timeout');
            },
          );

      print('📤 WA Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final status = responseData['status'];
        final statusMessage = responseData['message']?.toString() ?? '';

        if (status is String && status.startsWith('1')) {
          print('❌ WhatsApp API Error: $statusMessage');
          return false;
        }

        if (status == true ||
            status == 'success' ||
            status == '200' ||
            statusMessage.toLowerCase().contains('delivered') ||
            statusMessage.toLowerCase().contains('sending') ||
            statusMessage.toLowerCase().contains('queued') ||
            statusMessage.toLowerCase().contains('success')) {
          return true;
        }

        print('⚠️ Unexpected WA response: $statusMessage (status: $status)');
        return false;
      }

      return false;
    } catch (e) {
      print('❌ Error sending WhatsApp: $e');
      return false;
    }
  }

  static Future<bool> sendRoomCancellationRequestToAdmin({
  required String bookingId,
  required Map<String, dynamic> bookingData,
  required String requestedBy,
  required String reason,
}) async {
  try {
    final adminQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    if (adminQuery.docs.isEmpty) return false;

    final peminjam = bookingData['peminjam'] as Map<String, dynamic>? ?? {};
    final waktuMulai = bookingData['waktuMulai'] is Timestamp
        ? (bookingData['waktuMulai'] as Timestamp).toDate()
        : null;
    final waktuSelesai = bookingData['waktuSelesai'] is Timestamp
        ? (bookingData['waktuSelesai'] as Timestamp).toDate()
        : null;

    final tglMulai = waktuMulai != null
        ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuMulai)
        : '-';
    final tglSelesai = waktuSelesai != null
        ? DateFormat('HH:mm', 'id_ID').format(waktuSelesai)
        : '-';

    final namaRuang = bookingData['namaRuang'] ??
        bookingData['ruang']?['namaRuang'] ??
        'Ruang Meeting';

    bool atLeastOneSuccess = false;

    for (final doc in adminQuery.docs) {
      final adminData = doc.data();
      final adminId = doc.id;
      final adminPhone = adminData['noTelp']?.toString() ?? '';

      if (adminPhone.isEmpty) continue;

      final token = await generateApprovalToken(
        bookingId,
        adminId,
        bookingType: 'room_cancellation',
      );

      final rawLink =
          'https://pintra-mobile.web.app/room-cancellation-approval?bookingId=$bookingId&token=$token&requestedBy=${Uri.encodeComponent(requestedBy)}&reason=${Uri.encodeComponent(reason)}';
      final approvalLink = '<$rawLink>';

      final message = '''
*REQUEST PEMBATALAN RUANG MEETING* ⚠️

Yth. ${adminData['nama'] ?? 'Admin'},

Operator *$requestedBy* mengajukan request pembatalan untuk peminjaman ruang meeting yang sudah disetujui.

*Detail Peminjaman:*
- ID: ${bookingData['id'] ?? '-'}
- Nama: ${peminjam['nama'] ?? bookingData['namaPeminjam'] ?? '-'}
- Divisi: ${peminjam['divisi'] ?? '-'}
- Ruang: $namaRuang
- Kegiatan: ${bookingData['namaKegiatan'] ?? '-'}

📅 *Jadwal:*
- Mulai: $tglMulai
- Selesai: $tglSelesai

*Alasan Pembatalan dari Operator:*
$reason

*Klik link untuk menyetujui/menolak pembatalan:*

$approvalLink

*Link berlaku 24 jam*

---
_Pintra_
''';

      final result = await _sendWhatsApp(adminPhone, message);
      if (result) atLeastOneSuccess = true;

      print(result
          ? '✅ [Room] Notif pembatalan terkirim ke Admin ${adminData['nama']}'
          : '❌ [Room] Gagal kirim notif pembatalan ke Admin ${adminData['nama']}');

      await Future.delayed(const Duration(seconds: 5));
    }

    return atLeastOneSuccess;
  } catch (e) {
    print('❌ [Room] Error sendRoomCancellationRequestToAdmin: $e');
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ─── GYM BOOKING NOTIFICATIONS ──────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

static Future<bool> sendGymApprovalNotificationToOperator({
  required String bookingId,
  required Map<String, dynamic> bookingData,
}) async {
  try {
    final operatorQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'operator')
        .get();

    final operatorDocs = operatorQuery.docs.where((doc) {
      final opType = doc.data()['operatorType'] as String?;
      return opType == null || opType == 'ruang_meeting';
    }).toList();

    if (operatorDocs.isEmpty) {
      print('❌ [Gym] Operator tidak ditemukan');
      return false;
    }

    bool atLeastOneSuccess = false;

    for (final doc in operatorDocs) {
      final operatorData = doc.data();
      final operatorId = doc.id;
      final operatorPhone = operatorData['noTelp']?.toString() ?? '';

      if (operatorPhone.isEmpty) continue;

      final token = await generateApprovalToken(
        bookingId,
        operatorId,
        bookingType: 'gym',
      );
      final rawLink =
          'https://pintra-mobile.web.app/gym-approval?bookingId=$bookingId&token=$token';
      final approvalLink = '<$rawLink>';

      final message = _buildGymApprovalMessage(
        bookingData: bookingData,
        approvalLink: approvalLink,
        recipientName: operatorData['nama'] ?? 'Operator',
      );

      final result = await _sendWhatsApp(operatorPhone, message);
      if (result) atLeastOneSuccess = true;

      print(result
          ? '✅ [Gym] Notif WA terkirim ke Operator ${operatorData['nama']}'
          : '❌ [Gym] Gagal kirim ke Operator ${operatorData['nama']}');

      await Future.delayed(const Duration(seconds: 5));
    }

    return atLeastOneSuccess;
  } catch (e) {
    print('❌ [Gym] Error sendGymApprovalNotificationToOperator: $e');
    return false;
  }
}

static Future<bool> sendGymApprovedNotificationToPeminjam({
  required String bookingId,
  required Map<String, dynamic> bookingData,
}) async {
  try {
    final peminjam = bookingData['peminjam'] as Map<String, dynamic>? ?? {};
    final peminjamId = peminjam['userId'] ?? bookingData['peminjamId'];

    if (peminjamId == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(peminjamId)
        .get();

    if (!userDoc.exists) return false;

    final userData = userDoc.data()!;
    final peminjamPhone = userData['noTelp']?.toString() ?? '';
    final peminjamName = userData['nama'] ?? peminjam['nama'] ?? 'Peminjam';

    if (peminjamPhone.isEmpty) return false;

    final waktuMulai = bookingData['waktuMulai'] is Timestamp
        ? (bookingData['waktuMulai'] as Timestamp).toDate()
        : null;
    final waktuSelesai = bookingData['waktuSelesai'] is Timestamp
        ? (bookingData['waktuSelesai'] as Timestamp).toDate()
        : null;

    final tglMulai = waktuMulai != null
        ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuMulai)
        : '-';
    final tglSelesai = waktuSelesai != null
        ? DateFormat('HH:mm', 'id_ID').format(waktuSelesai)
        : '-';

    final message = '''
*PEMINJAMAN RUANG GYM DISETUJUI* ✅

Yth. $peminjamName,

Selamat! Pengajuan peminjaman ruang gym Anda telah *DISETUJUI*.

*Detail Peminjaman:*
- ID: ${bookingData['id'] ?? bookingId}
- Waktu: $tglMulai – $tglSelesai
${(bookingData['catatan'] ?? '').toString().isNotEmpty ? '- Catatan: ${bookingData['catatan']}' : ''}

*LANGKAH SELANJUTNYA:*
📍 Silakan akses ruang gym sesuai jadwal yang telah disetujui
📋 Pastikan ruang gym dikembalikan dalam kondisi rapi setelah selesai

---
_Pintra_
''';

    return await _sendWhatsApp(peminjamPhone, message);
  } catch (e) {
    print('❌ [Gym] Error sendGymApprovedNotificationToPeminjam: $e');
    return false;
  }
}

static Future<bool> sendGymRejectedNotificationToPeminjam({
  required String bookingId,
  required Map<String, dynamic> bookingData,
  required String rejectedBy,
  required String reason,
}) async {
  try {
    final peminjam = bookingData['peminjam'] as Map<String, dynamic>? ?? {};
    final peminjamId = peminjam['userId'] ?? bookingData['peminjamId'];
    if (peminjamId == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(peminjamId)
        .get();

    if (!userDoc.exists) return false;

    final userData = userDoc.data()!;
    final peminjamPhone = userData['noTelp']?.toString() ?? '';
    final peminjamName = userData['nama'] ?? peminjam['nama'] ?? 'Peminjam';

    if (peminjamPhone.isEmpty) return false;

    final message = '''
*PEMINJAMAN RUANG GYM DITOLAK* ❌

Yth. $peminjamName,

Mohon maaf, pengajuan peminjaman ruang gym Anda *DITOLAK*.

*Detail Peminjaman:*
- ID: ${bookingData['id'] ?? bookingId}

*Ditolak oleh:* $rejectedBy
*Alasan:* $reason

Silakan ajukan peminjaman baru atau hubungi $rejectedBy untuk informasi lebih lanjut.

---
_Pintra_
''';

    return await _sendWhatsApp(peminjamPhone, message);
  } catch (e) {
    print('❌ [Gym] Error sendGymRejectedNotificationToPeminjam: $e');
    return false;
  }
}

static String _buildGymApprovalMessage({
  required Map<String, dynamic> bookingData,
  required String approvalLink,
  required String recipientName,
}) {
  final peminjam = bookingData['peminjam'] as Map<String, dynamic>? ?? {};

  final waktuMulai = bookingData['waktuMulai'] is Timestamp
      ? (bookingData['waktuMulai'] as Timestamp).toDate()
      : null;
  final waktuSelesai = bookingData['waktuSelesai'] is Timestamp
      ? (bookingData['waktuSelesai'] as Timestamp).toDate()
      : null;

  final tglMulai = waktuMulai != null
      ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(waktuMulai)
      : '-';
  final tglSelesai = waktuSelesai != null
      ? DateFormat('HH:mm', 'id_ID').format(waktuSelesai)
      : '-';

  return '''
*APPROVAL PEMINJAMAN RUANG GYM*

Yth. $recipientName (Operator),

Terdapat pengajuan peminjaman ruang gym yang memerlukan persetujuan Anda:

*Detail Peminjaman:*
- ID Pemesanan: ${bookingData['id'] ?? '-'}
- Nama: ${peminjam['nama'] ?? '-'}
- NIPP: ${peminjam['nipp'] ?? '-'}
- Divisi: ${peminjam['divisi'] ?? '-'}
- Jabatan: ${peminjam['jabatan'] ?? '-'}
${(bookingData['catatan'] ?? '').toString().isNotEmpty ? '- Catatan: ${bookingData['catatan']}' : ''}

📅 *Jadwal:*
- Mulai: $tglMulai
- Selesai: $tglSelesai

*Klik link untuk approve/reject:*


$approvalLink


*Link berlaku 24 jam*

---
_Pintra_
''';
}
}