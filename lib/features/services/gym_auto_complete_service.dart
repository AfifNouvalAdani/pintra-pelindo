import 'package:cloud_firestore/cloud_firestore.dart';

class GymAutoCompleteService {
  /// Dipanggil saat dashboard dibuka.
  /// Mengecek semua gym_bookings dengan status 'APPROVED' yang
  /// waktuSelesai-nya sudah lewat, lalu otomatis mengubahnya ke 'DONE'.
  static Future<void> checkAndCompleteExpiredBookings() async {
    try {
      final now = Timestamp.now();

      // Ambil semua booking gym yang sudah disetujui
      // dan waktu selesainya sudah lewat
      final snapshot = await FirebaseFirestore.instance
          .collection('gym_bookings')
          .where('status', isEqualTo: 'APPROVED')
          .where('waktuSelesai', isLessThan: now)
          .get();

      if (snapshot.docs.isEmpty) return;

      // Proses setiap booking yang expired secara paralel
      await Future.wait(snapshot.docs.map((doc) async {
        try {
          await FirebaseFirestore.instance
              .collection('gym_bookings')
              .doc(doc.id)
              .update({
            'status': 'DONE',
            'completedAt': now,
            'updatedAt': now,
            'completedBy': 'system',
            'completedByRole': 'system',
          });

          await FirebaseFirestore.instance
              .collection('gym_bookings')
              .doc(doc.id)
              .collection('approval_history')
              .add({
            'action': 'COMPLETED',
            'oldStatus': 'APPROVED',
            'newStatus': 'DONE',
            'actionBy': 'System',
            'actionRole': 'system',
            'userId': 'system',
            'timestamp': now,
            'note': 'Peminjaman gym otomatis diselesaikan oleh sistem '
                'karena waktu pemakaian telah berakhir',
          });
        } catch (e) {
          // Satu booking gagal tidak menghentikan proses booking lain
          print('[GymAutoCompleteService] Gagal complete booking ${doc.id}: $e');
        }
      }));

      print('[GymAutoCompleteService] '
          'Selesai: ${snapshot.docs.length} booking gym di-complete otomatis');
    } catch (e) {
      print('[GymAutoCompleteService] Error: $e');
    }
  }
}