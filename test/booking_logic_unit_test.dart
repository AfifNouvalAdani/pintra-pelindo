// Lokasi: test/booking_logic_unit_test.dart
// Unit test konvensional (berbasis oracle / expected output eksplisit).
// BUKAN bagian dari 11 Metamorphic Relation dan TIDAK dipakai pada mutation analysis.

import 'package:flutter_test/flutter_test.dart';
import 'package:pintra/utils/booking_logic.dart'; // Sesuaikan path jika berbeda

void main() {
    group('UT 1: Time Conflict - Subset & Superset', () {
      final existingStart = DateTime(2026, 8, 30, 9, 0);
      final existingEnd = DateTime(2026, 8, 30, 11, 0);

      test('UT 1a: Waktu sempit yang overlap -> harus TRUE, superset-nya juga harus TRUE', () {
        final sourceStart = DateTime(2026, 8, 30, 10, 0);
        final sourceEnd = DateTime(2026, 8, 30, 10, 30);
        final sourceResult = BookingLogic.isTimeConflict(sourceStart, sourceEnd, existingStart, existingEnd);

        // Assert eksplisit di source, bukan cuma dipakai sebagai syarat if
        expect(sourceResult, isTrue);

        final followUpStart = DateTime(2026, 8, 30, 8, 0);
        final followUpEnd = DateTime(2026, 8, 30, 12, 0);
        final followUpResult = BookingLogic.isTimeConflict(followUpStart, followUpEnd, existingStart, existingEnd);

        expect(followUpResult, isTrue);
      });

      test('UT 1b: Waktu yang benar-benar tidak overlap -> harus FALSE', () {
        final sourceStart = DateTime(2026, 8, 30, 12, 0);
        final sourceEnd = DateTime(2026, 8, 30, 13, 0);
        final result = BookingLogic.isTimeConflict(sourceStart, sourceEnd, existingStart, existingEnd);

        expect(result, isFalse);
      });

      test('UT 1c: Boundary - waktu baru berakhir tepat saat waktu lama mulai -> harus FALSE (strict inequality)', () {
        final sourceStart = DateTime(2026, 8, 30, 8, 0);
        final sourceEnd = existingStart; // tepat 09:00
        final result = BookingLogic.isTimeConflict(sourceStart, sourceEnd, existingStart, existingEnd);

        expect(result, isFalse);
      });

    // =================================================================
    // UT 2: Translation (Pergeseran Konstan) pada Validasi Waktu
    // =================================================================
    final now = DateTime(2026, 8, 30, 10, 0);

    test('UT 2a: Waktu kembali sebelum waktu pinjam -> harus error, dan translasi +24 jam harus identik', () {
      final sourceStart = DateTime(2026, 8, 30, 11, 0);
      final sourceEnd = DateTime(2026, 8, 30, 9, 0);
      final sourceError = BookingLogic.validateBookingTime(sourceStart, sourceEnd, now);

      expect(sourceError, isNotNull);
      expect(sourceError, equals('Waktu kembali harus setelah waktu pinjam'));

      final followUpStart = sourceStart.add(const Duration(hours: 24));
      final followUpEnd = sourceEnd.add(const Duration(hours: 24));
      final followUpNow = now.add(const Duration(hours: 24));
      final followUpError = BookingLogic.validateBookingTime(followUpStart, followUpEnd, followUpNow);

      expect(followUpError, equals(sourceError));
    });

  test('UT 2b: Waktu pinjam di masa lalu -> harus error spesifik', () {
    final pastStart = now.subtract(const Duration(hours: 1));
    final pastEnd = now.add(const Duration(hours: 1));
    final error = BookingLogic.validateBookingTime(pastStart, pastEnd, now);

    expect(error, equals('Waktu pinjam tidak boleh di masa lalu'));
  });

  test('UT 2c: Waktu valid (pinjam di masa depan, kembali setelah pinjam) -> harus null', () {
    final validStart = now.add(const Duration(hours: 1));
    final validEnd = now.add(const Duration(hours: 2));
    final error = BookingLogic.validateBookingTime(validStart, validEnd, now);

    expect(error, isNull);
  });

  test('UT 2d: Translasi waktu pada kasus valid juga harus tetap null', () {
    final validStart = now.add(const Duration(hours: 1));
    final validEnd = now.add(const Duration(hours: 2));

    final shiftedStart = validStart.add(const Duration(hours: 48));
    final shiftedEnd = validEnd.add(const Duration(hours: 48));
    final shiftedNow = now.add(const Duration(hours: 48));

    final error = BookingLogic.validateBookingTime(shiftedStart, shiftedEnd, shiftedNow);
    expect(error, isNull);
  });

    // =================================================================
    // UT 3: Additive (Penambahan Konstanta) pada Odometer
    // =================================================================
    test('UT 3a: Additive constant pada kasus normal -> distance & validasi tetap sama', () {
      const sourceOdoAwal = 1000;
      const sourceOdoAkhir = 1050;
      final sourceDistance = BookingLogic.calculateDistance(sourceOdoAwal, sourceOdoAkhir);
      final sourceValidasi = BookingLogic.validateOdometer(sourceOdoAwal, sourceOdoAkhir);

      expect(sourceDistance, equals(50));
      expect(sourceValidasi, isNull);

      const int C = 50000;
      const followUpOdoAwal = sourceOdoAwal + C;
      const followUpOdoAkhir = sourceOdoAkhir + C;
      final followUpDistance = BookingLogic.calculateDistance(followUpOdoAwal, followUpOdoAkhir);
      final followUpValidasi = BookingLogic.validateOdometer(followUpOdoAwal, followUpOdoAkhir);

      expect(followUpDistance, equals(sourceDistance));
      expect(followUpValidasi, equals(sourceValidasi));
    });

    test('UT 3b: Odometer akhir < awal -> harus error spesifik', () {
      final error = BookingLogic.validateOdometer(1050, 1000);
      expect(error, equals('Odometer akhir tidak boleh kurang dari odometer awal'));
    });

    test('UT 3c: Odometer akhir == awal -> harus error spesifik (beda pesan dari 3b)', () {
      final error = BookingLogic.validateOdometer(1000, 1000);
      expect(error, equals('Odometer akhir tidak boleh sama dengan odometer awal. Minimal bertambah 1 km'));
    });

    test('UT 3d: Boundary - akhir = awal + 1 -> harus valid (null), distance = 1', () {
      final error = BookingLogic.validateOdometer(1000, 1001);
      final distance = BookingLogic.calculateDistance(1000, 1001);

      expect(error, isNull);
      expect(distance, equals(1));
    });

    test('UT 3e: calculateDistance harus benar-benar selisih, bukan penjumlahan', () {
      final distance = BookingLogic.calculateDistance(1000, 1500);
      expect(distance, equals(500));
      expect(distance, isNot(equals(2500))); // jaga-jaga kalau mutant ubah - jadi +
    });

    // =================================================================
    // UT 4: Permutative (Acak Urutan) pada Kelengkapan Kendaraan
    // =================================================================
    test('UT 4a: Nilai eksak untuk kombinasi tertentu (2 dari 5 true)', () {
      final items = [true, true, false, false, false];
      final completeness = BookingLogic.calculateCompleteness(items);
      expect(completeness, equals(0.4));
    });

    test('UT 4b: Semua true -> harus 1.0 (100%)', () {
      final items = [true, true, true, true, true];
      expect(BookingLogic.calculateCompleteness(items), equals(1.0));
    });

    test('UT 4c: Semua false -> harus 0.0 (0%)', () {
      final items = [false, false, false, false, false];
      expect(BookingLogic.calculateCompleteness(items), equals(0.0));
    });

    test('UT 4d: List kosong -> harus 0.0 (edge case)', () {
      final items = <bool>[];
      expect(BookingLogic.calculateCompleteness(items), equals(0.0));
    });

    test('UT 4e: Permutasi urutan tidak boleh mengubah hasil (dengan nilai eksak)', () {
      final sourceItems = [true, true, false, false, false];
      final sourceCompleteness = BookingLogic.calculateCompleteness(sourceItems);
      expect(sourceCompleteness, equals(0.4));

      final followUpItems = List<bool>.from(sourceItems)..shuffle();
      final followUpCompleteness = BookingLogic.calculateCompleteness(followUpItems);

      expect(followUpCompleteness, equals(sourceCompleteness));
    });

    test('UT 4f: Satu item true dari 4 -> harus 0.25', () {
      final items = [true, false, false, false];
      expect(BookingLogic.calculateCompleteness(items), equals(0.25));
    });

    // =================================================================
    // UT 5: Hierarchical (Tingkatan) pada Status Peminjaman
    // =================================================================
  test('UT 5a: role admin -> APPROVAL_3', () {
    expect(BookingLogic.determineInitialStatus('admin', 'staff'), equals('APPROVAL_3'));
  });

  test('UT 5b: role manager_umum -> APPROVAL_3', () {
    expect(BookingLogic.determineInitialStatus('manager_umum', 'staff'), equals('APPROVAL_3'));
  });

  test('UT 5c: role operator -> APPROVAL_2', () {
    expect(BookingLogic.determineInitialStatus('operator', 'staff'), equals('APPROVAL_2'));
  });

  test('UT 5d: role user dengan jabatan mengandung "manager" -> APPROVAL_1', () {
    expect(BookingLogic.determineInitialStatus('user', 'manager divisi'), equals('APPROVAL_1'));
  });

  test('UT 5e: role user dengan jabatan tidak mengandung "manager" -> SUBMITTED', () {
    expect(BookingLogic.determineInitialStatus('user', 'staff'), equals('SUBMITTED'));
  });

  test('UT 5f: jabatan case-insensitive - "MANAGER" huruf besar tetap harus APPROVAL_1', () {
    expect(BookingLogic.determineInitialStatus('user', 'MANAGER Divisi'), equals('APPROVAL_1'));
  });

  test('UT 5g: Hierarchical - role lebih tinggi harus level >= role lebih rendah', () {
    int getStatusLevel(String status) {
      switch (status) {
        case 'SUBMITTED': return 0;
        case 'APPROVAL_1': return 1;
        case 'APPROVAL_2': return 2;
        case 'APPROVAL_3': return 3;
        default: return -1;
      }
    }

    final sourceStatus = BookingLogic.determineInitialStatus('user', 'staff');
    final sourceLevel = getStatusLevel(sourceStatus);
    expect(sourceStatus, equals('SUBMITTED'));

    final followUpStatus = BookingLogic.determineInitialStatus('admin', 'staff');
    final followUpLevel = getStatusLevel(followUpStatus);

    expect(followUpLevel, greaterThanOrEqualTo(sourceLevel));
  });

  });

  // Dipindahkan dari booking_logic_mt_test.dart: uji batas approveTransition
  // (bukan Metamorphic Relation, sehingga tidak termasuk suite MT).
  group('UT 6: approveTransition - penolakan di luar kewenangan', () {
    test('UT 6a: role user (manager divisi) pada status selain SUBMITTED ditolak', () {
      final res = BookingLogic.approveTransition(
        role: 'user',
        jabatan: 'manager divisi',
        currentStatus: 'APPROVAL_1',
      );
      expect(res.error, equals('Hanya dapat menyetujui status SUBMITTED'));
    });

    test('UT 6b: role admin pada status selain APPROVAL_2 ditolak', () {
      final res = BookingLogic.approveTransition(
        role: 'admin',
        jabatan: 'manager_umum',
        currentStatus: 'SUBMITTED',
      );
      expect(res.error, equals('Hanya dapat menyetujui status APPROVAL_2'));
    });
  });
}
