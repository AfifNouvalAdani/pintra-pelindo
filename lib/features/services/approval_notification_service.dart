import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

class ApprovalNotificationService {
  // ✅ WatZap API Configuration
  static const String WA_API_URL = 'https://api.watzap.id/v1/send_message';
  static const String WA_API_KEY = 'V3ELWOCBWBWHDEMX'; // API Key untuk autentikasi
  static const String WA_NUMBER_KEY = 'VcgcGA4Tq9FkpwMJ'; // Device/Number Key (nomor WA pengirim)
  
  // ✅ Generate One-Time Token
  static Future<String> generateApprovalToken(String bookingId, String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomString = DateTime.now().microsecondsSinceEpoch.toString();
    final data = '$bookingId|$userId|$timestamp|$randomString';
    
    // Hash dengan SHA256
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes).toString();
    
    // Simpan token ke Firestore dengan expiry 24 jam
    await FirebaseFirestore.instance
        .collection('approval_tokens')
        .doc(hash)
        .set({
      'bookingId': bookingId,
      'userId': userId,
      'token': hash,
      'createdAt': Timestamp.now(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
      'used': false,
    });
    
    return hash;
  }
  
  // ✅ Validate Token
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
      
      // Cek apakah token sudah expired atau sudah dipakai
      if (DateTime.now().isAfter(expiresAt) || used) {
        return null;
      }
      
      return data;
    } catch (e) {
      print('Error validating token: $e');
      return null;
    }
  }
  
  // ✅ Mark Token as Used
  static Future<void> markTokenAsUsed(String token) async {
    await FirebaseFirestore.instance
        .collection('approval_tokens')
        .doc(token)
        .update({'used': true, 'usedAt': Timestamp.now()});
  }
  
  // ✅ Send WhatsApp Notification untuk Manager Divisi (APPROVAL_1)
  static Future<bool> sendApprovalNotificationToManagerDivisi({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      // 1. Cari Manager Divisi berdasarkan divisi peminjam
      final divisi = bookingData['divisi'];
      
      final managerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .where('divisi', isEqualTo: divisi)
          .get();
      
      // Cari yang jabatannya mengandung 'manager'
      final managers = managerQuery.docs.where((doc) {
        final jabatan = (doc.data()['jabatan'] ?? '').toLowerCase();
        return jabatan.contains('manager');
      }).toList();
      
      if (managers.isEmpty) {
        print('Manager Divisi tidak ditemukan untuk divisi: $divisi');
        return false;
      }
      
      // Ambil manager pertama
      final managerData = managers.first.data();
      final managerId = managers.first.id;
      final managerPhone = managerData['noTelp']?.toString() ?? '';
      
      if (managerPhone.isEmpty) {
        print('Nomor WA Manager tidak ditemukan');
        return false;
      }
      
      // 2. Generate Token
      final token = await generateApprovalToken(bookingId, managerId);
      
      // 3. Generate Deep Link
      final rawLink = 'https://pintra-mobile.web.app/approval?bookingId=$bookingId&token=$token';
      final approvalLink = '<$rawLink>';

      
      // 4. Format Message
      final message = _buildApprovalMessage(
        bookingData: bookingData,
        approvalLink: approvalLink,
        managerName: managerData['nama'] ?? 'Manager',
      );
      
      // 5. Send WhatsApp
      return await _sendWhatsApp(managerPhone, message);
      
    } catch (e) {
      print('Error sending notification to Manager Divisi: $e');
      return false;
    }
  }
  
  // ✅ Send WhatsApp Notification untuk Manager Umum (APPROVAL_3)
  static Future<bool> sendApprovalNotificationToManagerUmum({
    required String bookingId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      // 1. Cari Manager Umum (role: admin atau manager_umum)
      final managerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'manager_umum'])
          .limit(1)
          .get();
      
      if (managerQuery.docs.isEmpty) {
        print('Manager Umum tidak ditemukan');
        return false;
      }
      
      final managerData = managerQuery.docs.first.data();
      final managerId = managerQuery.docs.first.id;
      final managerPhone = managerData['noTelp']?.toString() ?? '';
      
      if (managerPhone.isEmpty) {
        print('Nomor WA Manager Umum tidak ditemukan');
        return false;
      }
      
      // 2. Generate Token
      final token = await generateApprovalToken(bookingId, managerId);
      
      // 3. Generate Deep Link
      final rawLink = 'https://pintra-mobile.web.app/approval?bookingId=$bookingId&token=$token';
      final approvalLink = '<$rawLink>';
      
      // 4. Format Message
      final message = _buildApprovalMessage(
        bookingData: bookingData,
        approvalLink: approvalLink,
        managerName: managerData['nama'] ?? 'Manager',
      );
      
      // 5. Send WhatsApp
      return await _sendWhatsApp(managerPhone, message);
      
    } catch (e) {
      print('Error sending notification to Manager Umum: $e');
      return false;
    }
  }

// ✅ TAMBAHKAN FUNGSI INI (kirim WA setelah Manager Divisi approve)
static Future<bool> sendApprovalNotificationToOperator({
  required String bookingId,
  required Map<String, dynamic> bookingData,
}) async {
  try {
    // 1. Cari Operator (role: operator)
    final operatorQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'operator')
        .limit(1)
        .get();
    
    if (operatorQuery.docs.isEmpty) {
      print('Operator tidak ditemukan');
      return false;
    }
    
    final operatorData = operatorQuery.docs.first.data();
    final operatorId = operatorQuery.docs.first.id;
    final operatorPhone = operatorData['noTelp']?.toString() ?? '';
    
    if (operatorPhone.isEmpty) {
      print('Nomor WA Operator tidak ditemukan');
      return false;
    }
    
    // 2. Generate Token
    final token = await generateApprovalToken(bookingId, operatorId);
    
    // 3. Generate Deep Link
    final rawLink = 'https://pintra-mobile.web.app/approval?bookingId=$bookingId&token=$token';
    final approvalLink = '<$rawLink>';
    
    // 4. Format Message
    final message = _buildApprovalMessage(
      bookingData: bookingData,
      approvalLink: approvalLink,
      managerName: operatorData['nama'] ?? 'Operator',
    );
    
    // 5. Send WhatsApp
    return await _sendWhatsApp(operatorPhone, message);
    
  } catch (e) {
    print('Error sending notification to Operator: $e');
    return false;
  }
}
  
static String _buildApprovalMessage({
  required Map<String, dynamic> bookingData,
  required String approvalLink,
  required String managerName,
}) {
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
  
  return '''
*APPROVAL PEMINJAMAN KENDARAAN*

Yth. $managerName,

Terdapat pengajuan peminjaman kendaraan yang memerlukan persetujuan Anda:

*Detail Peminjaman:*
- ID Pemesanan: ${bookingData['id']}
- Nama: ${bookingData['namaPeminjam']}
- NIPP: ${bookingData['nipp'] ?? '-'}
- Divisi: ${bookingData['divisi']}
- Kendaraan: ${bookingData['vehicle']?['nama'] ?? '-'} (${bookingData['vehicle']?['platNomor'] ?? '-'})
- Tujuan: ${bookingData['tujuan']}
- Keperluan: ${bookingData['keperluan']}

📅 *Jadwal:*
- Pinjam: $tglPinjam
- Kembali: $tglKembali

*Klik link untuk approve/reject:*


$approvalLink


⏰ Link berlaku 24 jam

---
_Pesan otomatis dari Sistem Peminjaman Kendaraan_
''';
}
  
  // ✅ Send WhatsApp via WatZap API
static Future<bool> _sendWhatsApp(String phoneNumber, String message) async {
  try {
    // Format nomor (pastikan format internasional, contoh: 6282111882525)
    String formattedPhone = phoneNumber;
    if (!formattedPhone.startsWith('62')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '62${formattedPhone.substring(1)}';
      } else {
        formattedPhone = '62$formattedPhone';
      }
    }
    
    final response = await http.post(
      Uri.parse(WA_API_URL),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $WA_API_KEY',
      },
      body: jsonEncode({
        'api_key': WA_API_KEY,
        'number_key': WA_NUMBER_KEY,
        'phone_no': formattedPhone,
        'message': message,
      }),
    );
    
    print('📤 WA API Response Status: ${response.statusCode}');
    print('📤 WA API Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      
      // ✅ PERBAIKAN: Terima berbagai response sukses
      final status = responseData['status'];
      final message = responseData['message']?.toString().toLowerCase() ?? '';
      
      // Cek berbagai kondisi sukses
      if (status == true || 
          status == 'success' || 
          message.contains('delivered') ||
          message.contains('sending') ||
          message.contains('queued')) {
        print('✅ WhatsApp sent successfully to $formattedPhone');
        return true;
      } else {
        print('⚠️ Unexpected response: ${responseData['message']}');
        // Tetap return true jika status 200 (anggap sukses)
        return true;
      }
    } else {
      print('❌ Failed to send WhatsApp: ${response.statusCode} - ${response.body}');
      return false;
    }
  } catch (e) {
    print('❌ Error sending WhatsApp: $e');
    return false;
  }
}
}