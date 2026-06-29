import 'package:cloud_firestore/cloud_firestore.dart';
import 'approval_notification_service.dart';

class AutoCancelService {
  // ═══════════════════════════════════════════════════════════════════════════
  // AUTO CANCEL EXPIRED BOOKINGS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> checkAndCancelExpiredBookings() async {
    try {
      print('🔍 Checking expired bookings...');

      final now = Timestamp.now();

      final expiredBookings = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', whereIn: ['SUBMITTED', 'APPROVAL_1'])
          .where('waktuPinjam', isLessThanOrEqualTo: now)
          .get();

      if (expiredBookings.docs.isEmpty) {
        print('✅ No expired bookings found');
        return;
      }

      print('📋 Found ${expiredBookings.docs.length} expired bookings');

      for (var doc in expiredBookings.docs) {
        final booking = doc.data();
        final bookingId = doc.id;

        print('❌ Cancelling booking: $bookingId');

        await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .doc(bookingId)
            .update({
          'status': 'CANCELLED',
          'cancellationReason':
              'Dibatalkan otomatis oleh sistem karena melewati batas waktu peminjaman',
          'cancelledBy': 'SYSTEM',
          'cancelledByRole': 'system',
          'cancelledAt': now,
          'updatedAt': now,
        });

        await FirebaseFirestore.instance
            .collection('vehicle_bookings')
            .doc(bookingId)
            .collection('approval_history')
            .add({
          'action': 'AUTO_CANCELLED',
          'oldStatus': booking['status'],
          'newStatus': 'CANCELLED',
          'actionBy': 'Sistem',
          'actionRole': 'system',
          'userId': 'system',
          'timestamp': now,
          'note':
              'Dibatalkan otomatis karena melewati batas waktu peminjaman. status terakhir ${booking['status']}',
          'reason': 'Melewati waktu peminjaman tanpa approval',
        });

        print('📨 Mengirim notifikasi WA auto-cancel ke peminjam...');
        final notifSuccess =
            await ApprovalNotificationService.sendAutoCancelledNotificationToPeminjam(
          bookingId: bookingId,
          bookingData: {'id': bookingId, ...booking},
        );

        print(notifSuccess
            ? '✅ Notifikasi WA berhasil dikirim'
            : '❌ Gagal mengirim notifikasi WA');

        print('✅ Booking $bookingId cancelled successfully');
      }

      print(
          '✅ Auto-cancel completed: ${expiredBookings.docs.length} bookings cancelled');
    } catch (e) {
      print('❌ Error auto-cancelling bookings: $e');
    }
  }

  static Future<bool> checkAndCancelSingleBooking(String bookingId) async {
    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) return false;

      final booking = bookingDoc.data()!;
      final status = booking['status'];

      if (status == 'SUBMITTED' || status == 'APPROVAL_1') {
        final waktuPinjam = (booking['waktuPinjam'] as Timestamp).toDate();
        final now = DateTime.now();

        if (now.isAfter(waktuPinjam)) {
          print('❌ Booking $bookingId is expired, cancelling...');

          await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .doc(bookingId)
              .update({
            'status': 'CANCELLED',
            'cancellationReason':
                'Dibatalkan otomatis karena melewati waktu peminjaman',
            'cancelledBy': 'SYSTEM',
            'cancelledByRole': 'system',
            'cancelledAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });

          await FirebaseFirestore.instance
              .collection('vehicle_bookings')
              .doc(bookingId)
              .collection('approval_history')
              .add({
            'action': 'AUTO_CANCELLED',
            'oldStatus': status,
            'newStatus': 'CANCELLED',
            'actionBy': 'Sistem',
            'actionRole': 'system',
            'userId': 'system',
            'timestamp': Timestamp.now(),
            'note':
                'Dibatalkan otomatis karena melewati batas waktu peminjaman',
            'reason': 'Melewati waktu peminjaman tanpa approval',
          });

          print('📨 Mengirim notifikasi WA auto-cancel...');
          await ApprovalNotificationService.sendAutoCancelledNotificationToPeminjam(
            bookingId: bookingId,
            bookingData: {'id': bookingId, ...booking},
          );

          print('✅ Booking $bookingId cancelled successfully');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error checking booking $bookingId: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RETURN REMINDERS — kirim berulang setiap 30 menit setelah waktu kembali
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Logika field di Firestore:
  //   returnReminderSent      : bool  — apakah reminder pertama (5 menit sebelum) sudah dikirim
  //   returnReminderCount     : int   — jumlah total reminder yang sudah dikirim (termasuk yang pertama)
  //   lastReturnReminderAt    : Timestamp — kapan reminder terakhir dikirim
  //
  // Alur:
  //   1. 5 menit sebelum waktuKembali  → kirim reminder pertama  (count = 1)
  //   2. Setelah waktuKembali terlewat → kirim setiap 30 menit   (count 2, 3, 4, …)
  //   3. Berhenti saat status == 'DONE' atau 'CANCELLED'
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> checkAndSendReturnReminders() async {
    try {
      print('🔍 Checking bookings needing return reminders...');

      final now = DateTime.now();
      final fiveMinutesLater = now.add(const Duration(minutes: 5));

      final ongoingBookings = await FirebaseFirestore.instance
          .collection('vehicle_bookings')
          .where('status', isEqualTo: 'ON_GOING')
          .get();

      for (var doc in ongoingBookings.docs) {
        final booking = doc.data();
        final bookingId = doc.id;

        final waktuKembaliRaw = booking['waktuKembali'];
        if (waktuKembaliRaw == null) continue;
        final waktuKembali = (waktuKembaliRaw as Timestamp).toDate();

        final reminderSent = booking['returnReminderSent'] ?? false;
        final reminderCount = (booking['returnReminderCount'] ?? 0) as int;
        final lastReminderRaw = booking['lastReturnReminderAt'];
        final DateTime? lastReminderAt = lastReminderRaw != null
            ? (lastReminderRaw as Timestamp).toDate()
            : null;

        // ── FASE 1: Reminder pertama — 5 menit sebelum waktuKembali ──────
        if (!reminderSent &&
            waktuKembali.isAfter(now) &&
            waktuKembali.isBefore(fiveMinutesLater)) {
          print(
              '📨 [Reminder #1] Kirim reminder pertama untuk booking $bookingId');

          final success =
              await ApprovalNotificationService.sendReturnReminderToPeminjam(
            bookingId: bookingId,
            bookingData: {'id': bookingId, ...booking},
            reminderCount: 1,
          );

          if (success) {
            await FirebaseFirestore.instance
                .collection('vehicle_bookings')
                .doc(bookingId)
                .update({
              'returnReminderSent': true,
              'returnReminderCount': 1,
              'lastReturnReminderAt': Timestamp.now(),
            });
            print('✅ Reminder #1 berhasil dikirim untuk booking $bookingId');
          }
          continue;
        }

        // ── FASE 2: Reminder berulang — setiap 30 menit setelah waktuKembali ──
        // Syarat: waktu kembali sudah terlewat DAN kendaraan belum dikembalikan
        if (waktuKembali.isBefore(now)) {
          // Tentukan apakah sudah saatnya kirim reminder berikutnya
          bool shouldSendNow = false;

          if (lastReminderAt == null) {
            // Belum pernah kirim sama sekali (edge case: reminder pertama terlewat)
            shouldSendNow = true;
          } else {
            final minutesSinceLast =
                now.difference(lastReminderAt).inMinutes;
            // Kirim lagi jika sudah 30 menit sejak reminder terakhir
            shouldSendNow = minutesSinceLast >= 30;
          }

          if (!shouldSendNow) continue;

          final nextCount = reminderCount + 1;
          print(
              '📨 [Reminder #$nextCount] Kirim reminder ke-$nextCount untuk booking $bookingId '
              '(${now.difference(waktuKembali).inMinutes} menit terlambat)');

          final success =
              await ApprovalNotificationService.sendReturnReminderToPeminjam(
            bookingId: bookingId,
            bookingData: {'id': bookingId, ...booking},
            reminderCount: nextCount,
          );

          if (success) {
            await FirebaseFirestore.instance
                .collection('vehicle_bookings')
                .doc(bookingId)
                .update({
              'returnReminderSent': true,
              'returnReminderCount': nextCount,
              'lastReturnReminderAt': Timestamp.now(),
            });
            print(
                '✅ Reminder #$nextCount berhasil dikirim untuk booking $bookingId');
          }
        }
      }

      print('✅ Return reminder check completed');
    } catch (e) {
      print('❌ Error checking return reminders: $e');
    }
  }
}