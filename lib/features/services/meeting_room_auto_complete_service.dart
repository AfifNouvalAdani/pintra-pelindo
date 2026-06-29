import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingRoomAutoCompleteService {
  static const Duration _cleaningBuffer = Duration(minutes: 90); 

  static Future<void> checkAndCompleteExpiredBookings() async {
    try {
      final now = Timestamp.now();

      final snapshot = await FirebaseFirestore.instance
          .collection('room_bookings')
          .where('status', isEqualTo: 'APPROVAL_3')
          .where('waktuSelesai', isLessThan: now)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'DONE',
          'completedAt': now,
          'completedBy': 'system',
          'updatedAt': now,
        });

        // Tulis ke approval_history supaya timeline tercatat
        final histRef = doc.reference.collection('approval_history').doc();
        batch.set(histRef, {
          'action': 'COMPLETED',
          'oldStatus': 'APPROVAL_3',
          'newStatus': 'DONE',
          'actionBy': 'System',
          'actionRole': 'system',
          'userId': 'system',
          'timestamp': now,
          'note': 'Peminjaman selesai otomatis oleh sistem',
        });
      }

      await batch.commit();
      print(
          '✅ [MeetingRoom] Auto-complete: ${snapshot.docs.length} booking diselesaikan');
    } catch (e) {
      print('❌ [MeetingRoom] Auto-complete error: $e');
    }
  }


  static DateTime effectiveEndTime(DateTime waktuSelesai) {
    return waktuSelesai.add(_cleaningBuffer);
  }


  static Future<RoomConflictResult> checkRoomConflict({
    required String roomId,
    required DateTime waktuMulai,
    required DateTime waktuSelesai,
    String? bookingIdToIgnore,
  }) async {
    try {
      // Status yang dianggap "memblokir" ruang
      final activeStatuses = [
        'SUBMITTED',
        'APPROVAL_1',
        'APPROVAL_2',
        'APPROVAL_3',
      ];

      final snapshot = await FirebaseFirestore.instance
          .collection('room_bookings')
          .where('ruang.roomId', isEqualTo: roomId)
          .where('status', whereIn: activeStatuses)
          .get();

      for (final doc in snapshot.docs) {
        // Skip booking yang sedang diedit
        if (bookingIdToIgnore != null && doc.id == bookingIdToIgnore) {
          continue;
        }

        final data = doc.data();
        final bookingMulai =
            (data['waktuMulai'] as Timestamp?)?.toDate();
        final bookingSelesaiRaw =
            (data['waktuSelesai'] as Timestamp?)?.toDate();

        if (bookingMulai == null || bookingSelesaiRaw == null) continue;

        // Waktu efektif akhir = waktuSelesai + 1,5 jam cleaning
        final bookingSelesaiEfektif =
            effectiveEndTime(bookingSelesaiRaw);

        // Overlap check:
        // Request mulai sebelum booking efektif selesai
        // DAN request selesai setelah booking mulai
        final isConflict = waktuMulai.isBefore(bookingSelesaiEfektif) &&
            waktuSelesai.isAfter(bookingMulai);

        if (isConflict) {
          // Tentukan apakah konflik dengan waktu rapat itu sendiri
          // atau dengan waktu cleaning-nya
          final isCleaningConflict =
              waktuMulai.isAfter(bookingSelesaiRaw) ||
                  waktuMulai.isAtSameMomentAs(bookingSelesaiRaw);

          final peminjam =
              data['peminjam'] as Map<String, dynamic>? ?? {};

          return RoomConflictResult(
            hasConflict: true,
            conflictType: isCleaningConflict
                ? ConflictType.cleaning
                : ConflictType.booking,
            conflictingBookingId: doc.id,
            conflictingPeminjam: peminjam['nama'] ?? '-',
            conflictingWaktuMulai: bookingMulai,
            conflictingWaktuSelesai: bookingSelesaiRaw,
            cleaningEndsAt: bookingSelesaiEfektif,
          );
        }
      }

      return RoomConflictResult(hasConflict: false);
    } catch (e) {
      print('❌ [MeetingRoom] Conflict check error: $e');
      // Jika error, anggap tidak ada konflik supaya tidak memblokir user
      return RoomConflictResult(hasConflict: false);
    }
  }


  static Future<Map<String, RoomConflictResult>> checkAllRoomsConflict({
    required List<String> roomIds,
    required DateTime waktuMulai,
    required DateTime waktuSelesai,
    String? bookingIdToIgnore,
  }) async {
    final results = <String, RoomConflictResult>{};

    await Future.wait(roomIds.map((roomId) async {
      final result = await checkRoomConflict(
        roomId: roomId,
        waktuMulai: waktuMulai,
        waktuSelesai: waktuSelesai,
        bookingIdToIgnore: bookingIdToIgnore,
      );
      results[roomId] = result;
    }));

    return results;
  }
}


enum ConflictType { booking, cleaning }

class RoomConflictResult {
  final bool hasConflict;
  final ConflictType? conflictType;
  final String? conflictingBookingId;
  final String? conflictingPeminjam;
  final DateTime? conflictingWaktuMulai;
  final DateTime? conflictingWaktuSelesai;
  final DateTime? cleaningEndsAt;

  const RoomConflictResult({
    required this.hasConflict,
    this.conflictType,
    this.conflictingBookingId,
    this.conflictingPeminjam,
    this.conflictingWaktuMulai,
    this.conflictingWaktuSelesai,
    this.cleaningEndsAt,
  });

  /// Pesan yang ditampilkan ke user saat ada konflik
  String get conflictMessage {
    if (!hasConflict) return '';

    if (conflictType == ConflictType.cleaning) {
      final cleaningEnd = cleaningEndsAt != null
          ? '${cleaningEndsAt!.hour.toString().padLeft(2, '0')}:${cleaningEndsAt!.minute.toString().padLeft(2, '0')}'
          : '-';
      final selesai = conflictingWaktuSelesai != null
          ? '${conflictingWaktuSelesai!.hour.toString().padLeft(2, '0')}:${conflictingWaktuSelesai!.minute.toString().padLeft(2, '0')}'
          : '-';
      return 'Ruang sedang dalam proses pembersihan setelah rapat sebelumnya '
          '(selesai pukul $selesai). '
          'Ruang baru tersedia mulai pukul $cleaningEnd.';
    } else {
      final mulai = conflictingWaktuMulai != null
          ? '${conflictingWaktuMulai!.hour.toString().padLeft(2, '0')}:${conflictingWaktuMulai!.minute.toString().padLeft(2, '0')}'
          : '-';
      final selesai = conflictingWaktuSelesai != null
          ? '${conflictingWaktuSelesai!.hour.toString().padLeft(2, '0')}:${conflictingWaktuSelesai!.minute.toString().padLeft(2, '0')}'
          : '-';
      return 'Ruang sudah dipesan oleh ${conflictingPeminjam ?? "-"} '
          'pada pukul $mulai–$selesai.';
    }
  }
}