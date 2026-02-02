import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../vehicle/detail_peminjaman_page.dart';
import '../services/approval_notification_service.dart';

class DeepLinkApprovalHandler extends StatefulWidget {
  final String bookingId;
  final String token;
  
  const DeepLinkApprovalHandler({
    super.key,
    required this.bookingId,
    required this.token,
  });

  @override
  State<DeepLinkApprovalHandler> createState() => _DeepLinkApprovalHandlerState();
}

class _DeepLinkApprovalHandlerState extends State<DeepLinkApprovalHandler> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleDeepLink();
  }

Future<void> _handleDeepLink() async {
  try {
    // 1. Validasi token
    final tokenData = await ApprovalNotificationService.validateToken(widget.token);

    if (tokenData == null) {
      setState(() {
        _error = 'Link tidak valid atau sudah kadaluarsa';
        _isLoading = false;
      });
      return;
    }

    // 2. Ambil data booking
    final bookingDoc = await FirebaseFirestore.instance
        .collection('vehicle_bookings')
        .doc(widget.bookingId)
        .get();

    if (!bookingDoc.exists) {
      setState(() {
        _error = 'Data peminjaman tidak ditemukan';
        _isLoading = false;
      });
      return;
    }

    final bookingData = {
      'id': bookingDoc.id,
      ...bookingDoc.data()!,
    };

    // ❌ JANGAN mark token used di sini
    // token baru dianggap dipakai setelah approve/reject

    // 3. Langsung buka halaman detail dalam mode approval
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPeminjamanPage(
            data: bookingData,
            approvalStep: 1,
            role: tokenData['role'] ?? 'manager',
            userName: tokenData['name'] ?? 'Manager',
            userId: tokenData['phone'] ?? '',
            userDivision: bookingData['divisi'] ?? '',
            isApprovalMode: true,
          ),
        ),
      );
    }
  } catch (e) {
    setState(() {
      _error = 'Terjadi kesalahan: $e';
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Memproses Approval',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Memvalidasi link approval...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 80,
                      color: Colors.red.shade400,
                    ),
                    SizedBox(height: 24),
                    Text(
                      _error ?? 'Terjadi kesalahan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                      ),
                      child: Text('Kembali'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}