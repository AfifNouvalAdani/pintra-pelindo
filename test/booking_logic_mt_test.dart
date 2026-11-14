// Lokasi: test/booking_logic_mt_test.dart
//
// Test suite Metamorphic Testing (MT) untuk modul peminjaman kendaraan
// operasional PINTRA. Berisi tepat 11 Metamorphic Relation (MR-1 s.d. MR-11)
// pada 7 fungsi yang diuji (Tabel 3.1 proposal):
//   isTimeConflict, availableVehicleIds, classifyVehicles, swapVehicles,
//   approveTransition, isFormAvailable, calculateCompleteness.
//
// Setiap MR terdiri atas: source test case -> transformasi -> follow-up test
// case -> pemeriksaan relasi output. Data uji dibangkitkan berulang (iterasi)
// dengan seed tetap per MR (deterministik dan tidak bergantung urutan test),
// ditambah kasus nilai batas (boundary values) yang relevan.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintra/utils/booking_logic.dart';

final baseTime = DateTime(2026, 9, 1, 0, 0);
const allStatuses = ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'ON_GOING'];
const softStatuses = ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3'];
final vehicles = List.generate(5, (i) => 'v$i');

/// Membangkitkan satu jadwal peminjaman acak.
BookingSlot randomSlot(Random rnd, int i, {List<String> statuses = allStatuses}) {
  final s = rnd.nextInt(72);
  final len = 1 + rnd.nextInt(6);
  return BookingSlot(
    id: 'b$i',
    vehicleId: vehicles[rnd.nextInt(vehicles.length)],
    status: statuses[rnd.nextInt(statuses.length)],
    start: baseTime.add(Duration(hours: s)),
    end: baseTime.add(Duration(hours: s + len)),
  );
}

/// Membangkitkan rentang waktu acak [start, end) dengan durasi >= 1 jam.
(DateTime, DateTime) randomRange(Random rnd, {int maxStart = 50, int maxLen = 10}) {
  final start = baseTime.add(Duration(hours: rnd.nextInt(maxStart)));
  return (start, start.add(Duration(hours: 1 + rnd.nextInt(maxLen))));
}

void main() {
  group('Metamorphic Tests untuk BookingLogic', () {
    // ===================================================================
    // MR-1 (Simetri) - isTimeConflict
    // ===================================================================
    test('MR-1 (Simetri): isTimeConflict(A, B) == isTimeConflict(B, A)', () {
      final rnd = Random(1);
      final pairs = <List<DateTime>>[];

      // Iterasi acak
      for (var i = 0; i < 200; i++) {
        final (s1, e1) = randomRange(rnd);
        final (s2, e2) = randomRange(rnd);
        pairs.add([s1, e1, s2, e2]);
      }

      // Nilai batas
      final t0 = baseTime;
      final t1 = baseTime.add(const Duration(hours: 1));
      final t2 = baseTime.add(const Duration(hours: 2));
      final t3 = baseTime.add(const Duration(hours: 3));
      final m = const Duration(minutes: 1);
      pairs.addAll([
        [t0, t1, t1, t2], // bersentuhan tepat di ujung (tidak bentrok)
        [t0, t1.add(m), t1, t2], // irisan 1 menit
        [t0, t2, t0, t2], // rentang identik
        [t0, t3, t1, t2], // A memuat B
        [t0, t1, t2, t3], // terpisah
      ]);

      for (final p in pairs) {
        final source = BookingLogic.isTimeConflict(p[0], p[1], p[2], p[3]);
        final followUp = BookingLogic.isTimeConflict(p[2], p[3], p[0], p[1]);
        expect(followUp, equals(source), reason: 'A=${p[0]}-${p[1]}, B=${p[2]}-${p[3]}');
      }
    });

    // ===================================================================
    // MR-2 (Monotonisitas) - calculateCompleteness
    // ===================================================================
    test('MR-2 (Monotonisitas): mengubah item false menjadi true menaikkan persentase', () {
      final rnd = Random(2);
      final sources = <List<bool>>[];

      // Iterasi acak: panjang 1..20, minimal satu item false
      for (var i = 0; i < 200; i++) {
        final len = 1 + rnd.nextInt(20);
        final items = List.generate(len, (_) => rnd.nextBool());
        items[rnd.nextInt(len)] = false;
        sources.add(items);
      }

      // Nilai batas
      sources.addAll([
        [false], // satu item
        [false, false, false, false, false], // semua false (0%)
        [true, true, true, true, false], // tinggal satu false
      ]);

      for (final source in sources) {
        final sourceScore = BookingLogic.calculateCompleteness(source);

        // Transformasi: ubah satu atau beberapa item false menjadi true
        final falseIdx = [for (var i = 0; i < source.length; i++) if (!source[i]) i];
        final flipCount = 1 + rnd.nextInt(falseIdx.length);
        final followUp = List<bool>.from(source);
        for (final idx in (falseIdx..shuffle(rnd)).take(flipCount)) {
          followUp[idx] = true;
        }
        final followUpScore = BookingLogic.calculateCompleteness(followUp);

        expect(followUpScore, greaterThan(sourceScore), reason: 'source=$source, followUp=$followUp');
      }
    });

    // ===================================================================
    // MR-3 (Translasi Waktu) - isFormAvailable
    // ===================================================================
    test('MR-3 (Translasi Waktu): menggeser waktu pinjam dan now dengan konstanta sama tidak mengubah hasil', () {
      final rnd = Random(3);

      // Selisih (now - waktuPinjam) dalam menit, termasuk nilai batas di sekitar H-1 jam
      final offsets = <int>[
        -61, -60, -59, // tepat di sekitar batas H-1 jam
        -24 * 60, -120, -1, 0, 1, 60, 24 * 60,
        for (var i = 0; i < 100; i++) rnd.nextInt(10 * 60) - 5 * 60,
      ];
      final shifts = <Duration>[
        const Duration(hours: 24),
        const Duration(hours: -24),
        const Duration(minutes: 1),
        const Duration(days: 30),
      ];

      for (final off in offsets) {
        final waktuPinjam = baseTime.add(Duration(hours: 10 + rnd.nextInt(100)));
        final now = waktuPinjam.add(Duration(minutes: off));
        final source = BookingLogic.isFormAvailable(waktuPinjam, now);

        for (final shift in [...shifts, Duration(minutes: rnd.nextInt(100000))]) {
          final followUp = BookingLogic.isFormAvailable(waktuPinjam.add(shift), now.add(shift));
          expect(followUp, equals(source), reason: 'offset=${off}m, shift=$shift');
        }
      }
    });

    // ===================================================================
    // MR-4 (Subset Ketersediaan) - availableVehicleIds
    // ===================================================================
    test('MR-4 (Subset Ketersediaan): mempersempit rentang tidak mengurangi kendaraan tersedia', () {
      final rnd = Random(4);

      void checkMR4(List<BookingSlot> bookings, DateTime startLuas, DateTime endLuas) {
        final hasilLuas = BookingLogic.availableVehicleIds(vehicles, bookings, startLuas, endLuas);

        // Transformasi: start +2 jam, end -2 jam
        final startSempit = startLuas.add(const Duration(hours: 2));
        final endSempit = endLuas.subtract(const Duration(hours: 2));
        final hasilSempit = BookingLogic.availableVehicleIds(vehicles, bookings, startSempit, endSempit);

        expect(hasilSempit.toSet().containsAll(hasilLuas), isTrue,
            reason: 'luas=$hasilLuas, sempit=$hasilSempit');
      }

      // Iterasi acak
      for (var n = 0; n < 100; n++) {
        final bookings = List.generate(10, (i) => randomSlot(rnd, i));
        final startLuas = baseTime.add(Duration(hours: 10 + rnd.nextInt(20)));
        final endLuas = startLuas.add(Duration(hours: 10 + rnd.nextInt(5)));
        checkMR4(bookings, startLuas, endLuas);
      }

      // Nilai batas: jadwal pemblokir yang bersentuhan/beririsan tepat di tepi rentang
      final startLuas = baseTime.add(const Duration(hours: 10));
      final endLuas = baseTime.add(const Duration(hours: 20));
      final edge = [
        BookingSlot(id: 'e1', vehicleId: 'v0', status: 'ON_GOING', start: baseTime, end: startLuas), // bersentuhan di awal
        BookingSlot(id: 'e2', vehicleId: 'v1', status: 'APPROVAL_2', start: endLuas, end: endLuas.add(const Duration(hours: 1))), // bersentuhan di akhir
        BookingSlot(id: 'e3', vehicleId: 'v2', status: 'APPROVAL_3', start: baseTime, end: startLuas.add(const Duration(hours: 1))), // irisan hanya di bagian luas
        BookingSlot(id: 'e4', vehicleId: 'v3', status: 'ON_GOING', start: startLuas.add(const Duration(hours: 2)), end: endLuas.subtract(const Duration(hours: 2))), // tepat sama dengan rentang sempit
      ];
      checkMR4(edge, startLuas, endLuas);
    });

    // ===================================================================
    // MR-5 (Permutasi Daftar Jadwal) - availableVehicleIds
    // ===================================================================
    test('MR-5 (Permutasi Daftar Jadwal): availableVehicleIds invarian terhadap urutan booking', () {
      final rnd = Random(5);
      for (var n = 0; n < 100; n++) {
        final bookings = List.generate(1 + rnd.nextInt(15), (i) => randomSlot(rnd, i));
        final (start, end) = randomRange(rnd, maxStart: 72, maxLen: 8);

        final hasilAsli = BookingLogic.availableVehicleIds(vehicles, bookings, start, end);

        final shuffled = List<BookingSlot>.from(bookings)..shuffle(rnd);
        final hasilAcak = BookingLogic.availableVehicleIds(vehicles, shuffled, start, end);

        expect(hasilAcak, equals(hasilAsli));
      }
    });

    // ===================================================================
    // MR-6 (Permutasi Kategori) - classifyVehicles
    // ===================================================================
    test('MR-6 (Permutasi Kategori): classifyVehicles invarian terhadap urutan booking', () {
      final rnd = Random(6);
      for (var n = 0; n < 100; n++) {
        final bookings = List.generate(1 + rnd.nextInt(15), (i) => randomSlot(rnd, i));
        final currentBookingId = 'b${rnd.nextInt(bookings.length)}';
        final String? currentVehicleId = rnd.nextBool() ? vehicles[rnd.nextInt(vehicles.length)] : null;

        final hasilAsli = BookingLogic.classifyVehicles(
          vehicleIds: vehicles,
          bookings: bookings,
          currentBookingId: currentBookingId,
          currentVehicleId: currentVehicleId,
        );

        final shuffled = List<BookingSlot>.from(bookings)..shuffle(rnd);
        final hasilAcak = BookingLogic.classifyVehicles(
          vehicleIds: vehicles,
          bookings: shuffled,
          currentBookingId: currentBookingId,
          currentVehicleId: currentVehicleId,
        );

        // Kategori dan urutan hasil klasifikasi harus sama persis
        expect(hasilAcak.length, equals(hasilAsli.length));
        for (var i = 0; i < hasilAsli.length; i++) {
          expect(hasilAcak[i].vehicleId, equals(hasilAsli[i].vehicleId));
          expect(hasilAcak[i].category, equals(hasilAsli[i].category));
        }
      }
    });

    // ===================================================================
    // MR-7 (Involusi) - swapVehicles
    // ===================================================================
    test('MR-7 (Involusi): swap(swap(A, B)) mengembalikan kendaraan ke dokumen asal', () {
      final rnd = Random(7);
      for (var n = 0; n < 100; n++) {
        final a = randomSlot(rnd, 1);
        var b = randomSlot(rnd, 2);
        // Prasyarat MR-7: kendaraan A dan B berbeda
        while (b.vehicleId == a.vehicleId) {
          b = randomSlot(rnd, 2);
        }
        expect(a.vehicleId, isNot(equals(b.vehicleId)));

        final swap1 = BookingLogic.swapVehicles(a, b);
        final swap2 = BookingLogic.swapVehicles(swap1[0], swap1[1]);

        // Kendaraan kembali ke pemilik asal, atribut lain tetap
        for (final (orig, after) in [(a, swap2[0]), (b, swap2[1])]) {
          expect(after.vehicleId, equals(orig.vehicleId));
          expect(after.id, equals(orig.id));
          expect(after.status, equals(orig.status));
          expect(after.start, equals(orig.start));
          expect(after.end, equals(orig.end));
        }
      }
    });

    // ===================================================================
    // MR-8 (Peralihan Bentrok) - approveTransition
    // ===================================================================
    test('MR-8 (Peralihan Bentrok): hasConflict false -> true mengubah persetujuan menjadi penolakan', () {
      // Variasi atribut yang dipertahankan sama antara source dan follow-up
      const jabatanList = ['staf', 'Staff', 'supervisor', 'manager divisi', ''];
      const operatorTypes = <String?>[null, 'kendaraan'];

      for (final jabatan in jabatanList) {
        for (final opType in operatorTypes) {
          final source = BookingLogic.approveTransition(
            role: 'operator',
            jabatan: jabatan,
            currentStatus: 'APPROVAL_1',
            operatorType: opType,
            hasConflict: false,
          );
          final followUp = BookingLogic.approveTransition(
            role: 'operator',
            jabatan: jabatan,
            currentStatus: 'APPROVAL_1',
            operatorType: opType,
            hasConflict: true,
          );

          final ctx = 'jabatan="$jabatan", operatorType=$opType';
          expect(source.newStatus, equals('APPROVAL_2'), reason: ctx);
          expect(source.error, isNull, reason: ctx);
          expect(followUp.newStatus, isNull, reason: ctx);
          expect(followUp.error, equals('Kendaraan bentrok'), reason: ctx);
        }
      }
    });

    // ===================================================================
    // MR-9 (Elevasi Role) - approveTransition
    // ===================================================================
    test('MR-9 (Elevasi Role): level status hasil admin (APPROVAL_2) > hasil operator (APPROVAL_1)', () {
      int level(String status) => int.parse(status.split('_')[1]);
      const jabatanList = ['staf', 'Staff', 'supervisor', 'manager divisi', ''];

      for (final jabatan in jabatanList) {
        // Source: operator pada tahap kewenangannya (APPROVAL_1)
        final resOperator = BookingLogic.approveTransition(
          role: 'operator',
          jabatan: jabatan,
          currentStatus: 'APPROVAL_1',
          hasConflict: false,
        );
        // Follow-up: role admin pada tahap berikutnya (APPROVAL_2); jabatan & hasConflict tetap
        final resAdmin = BookingLogic.approveTransition(
          role: 'admin',
          jabatan: jabatan,
          currentStatus: 'APPROVAL_2',
          hasConflict: false,
        );

        final ctx = 'jabatan="$jabatan"';
        expect(resOperator.newStatus, isNotNull, reason: ctx);
        expect(resAdmin.newStatus, isNotNull, reason: ctx);
        expect(level(resAdmin.newStatus!), greaterThan(level(resOperator.newStatus!)), reason: ctx);
      }
    });

    // ===================================================================
    // MR-10 (Restriksi Status) - availableVehicleIds
    // ===================================================================
    test('MR-10 (Restriksi Status): SUBMITTED -> ON_GOING mengurangi jumlah kendaraan tersedia', () {
      final rnd = Random(10);

      void checkMR10(String target, DateTime qStart, DateTime qEnd, DateTime bStart, DateTime bEnd) {
        // Source: satu jadwal SUBMITTED (tidak memblokir) yang beririsan dengan rentang query
        final source = [BookingSlot(id: 'b1', vehicleId: target, status: 'SUBMITTED', start: bStart, end: bEnd)];
        final sourceAvail = BookingLogic.availableVehicleIds(vehicles, source, qStart, qEnd);
        expect(sourceAvail.contains(target), isTrue); // prasyarat

        // Follow-up: status diubah menjadi ON_GOING; vehicleId & waktu tetap
        final followUp = [BookingSlot(id: 'b1', vehicleId: target, status: 'ON_GOING', start: bStart, end: bEnd)];
        final followUpAvail = BookingLogic.availableVehicleIds(vehicles, followUp, qStart, qEnd);

        expect(followUpAvail.length, lessThan(sourceAvail.length),
            reason: 'target=$target, query=$qStart-$qEnd, booking=$bStart-$bEnd');
      }

      // Iterasi: setiap kendaraan, rentang beririsan acak
      for (var n = 0; n < 100; n++) {
        final target = vehicles[n % vehicles.length];
        final (qStart, qEnd) = randomRange(rnd);
        // Booking dipastikan beririsan: mulai sebelum qEnd, selesai setelah qStart
        final bStart = qStart.subtract(Duration(hours: rnd.nextInt(5), minutes: rnd.nextInt(30)));
        final bEnd = qStart.add(Duration(minutes: 1 + rnd.nextInt(qEnd.difference(qStart).inMinutes + 120)));
        checkMR10(target, qStart, qEnd, bStart, bEnd);
      }

      // Nilai batas: irisan hanya 1 menit di awal dan di akhir rentang query
      final qStart = baseTime.add(const Duration(hours: 10));
      final qEnd = baseTime.add(const Duration(hours: 12));
      const m = Duration(minutes: 1);
      checkMR10('v1', qStart, qEnd, baseTime, qStart.add(m));
      checkMR10('v2', qStart, qEnd, qEnd.subtract(m), qEnd.add(const Duration(hours: 3)));
      checkMR10('v3', qStart, qEnd, qStart, qEnd); // rentang identik
    });

    // ===================================================================
    // MR-11 (Pergeseran Kategori) - classifyVehicles
    // ===================================================================
    group('MR-11 (Pergeseran Kategori)', () {
      VehicleCategory categoryOf(List<VehicleClass> res, String id) =>
          res.firstWhere((v) => v.vehicleId == id).category;

      test('MR-11 skenario (a): free -> hard-unavailable setelah menambah jadwal ON_GOING', () {
        final rnd = Random(111);
        for (var n = 0; n < 100; n++) {
          final target = vehicles[n % vehicles.length];
          // Jadwal latar acak pada kendaraan lain (target dipastikan free)
          final background = List.generate(rnd.nextInt(8), (i) => randomSlot(rnd, i + 1))
              .where((b) => b.vehicleId != target)
              .toList();

          final source = BookingLogic.classifyVehicles(
            vehicleIds: vehicles, bookings: background,
            currentBookingId: 'b0', currentVehicleId: null,
          );
          expect(categoryOf(source, target), equals(VehicleCategory.free)); // prasyarat

          final followUpBookings = [
            ...background,
            BookingSlot(id: 'new', vehicleId: target, status: 'ON_GOING', start: baseTime, end: baseTime.add(const Duration(hours: 2))),
          ];
          final followUp = BookingLogic.classifyVehicles(
            vehicleIds: vehicles, bookings: followUpBookings,
            currentBookingId: 'b0', currentVehicleId: null,
          );
          expect(categoryOf(followUp, target), equals(VehicleCategory.hardUnavailable));
        }
      });

      test('MR-11 skenario (b): soft-booked -> hard-unavailable setelah status jadwal diubah ke ON_GOING', () {
        final rnd = Random(112);
        for (var n = 0; n < 100; n++) {
          final target = vehicles[n % vehicles.length];
          final softStatus = softStatuses[n % softStatuses.length]; // semua status soft
          final background = List.generate(rnd.nextInt(8), (i) => randomSlot(rnd, i + 1))
              .where((b) => b.vehicleId != target)
              .toList();
          final targetSlot = BookingSlot(
            id: 'tgt', vehicleId: target, status: softStatus,
            start: baseTime, end: baseTime.add(const Duration(hours: 2)),
          );

          final source = BookingLogic.classifyVehicles(
            vehicleIds: vehicles, bookings: [...background, targetSlot],
            currentBookingId: 'b0', currentVehicleId: null,
          );
          expect(categoryOf(source, target), equals(VehicleCategory.softBooked)); // prasyarat

          // Follow-up: status jadwal yang sama diubah menjadi ON_GOING (tanpa menambah jadwal)
          final changed = BookingSlot(
            id: targetSlot.id, vehicleId: target, status: 'ON_GOING',
            start: targetSlot.start, end: targetSlot.end,
          );
          final followUp = BookingLogic.classifyVehicles(
            vehicleIds: vehicles, bookings: [...background, changed],
            currentBookingId: 'b0', currentVehicleId: null,
          );
          expect(categoryOf(followUp, target), equals(VehicleCategory.hardUnavailable));
        }
      });
    });
  });
}
