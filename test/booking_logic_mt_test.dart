import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pintra/utils/booking_logic.dart';

// Helper untuk membuat data booking acak
final rnd = Random(42); // Seed tetap agar hasil deterministik
final baseTime = DateTime(2026, 9, 1, 0, 0);

BookingSlot randomSlot(int i) {
  final s = rnd.nextInt(72);
  final len = 1 + rnd.nextInt(6);
  return BookingSlot(
    id: 'b$i',
    vehicleId: 'v${rnd.nextInt(5)}',
    status: ['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3', 'ON_GOING'][rnd.nextInt(5)],
    start: baseTime.add(Duration(hours: s)),
    end: baseTime.add(Duration(hours: s + len)),
  );
}

void main() {
  group('Metamorphic Tests untuk BookingLogic', () {
    
    // 1. Uji isTimeConflict
    test('MR 1 (Simetri): isTimeConflict(A, B) == isTimeConflict(B, A)', () {
      for (var i = 0; i < 100; i++) {
        final start1 = baseTime.add(Duration(hours: rnd.nextInt(50)));
        final end1 = start1.add(Duration(hours: 1 + rnd.nextInt(10)));
        
        final start2 = baseTime.add(Duration(hours: rnd.nextInt(50)));
        final end2 = start2.add(Duration(hours: 1 + rnd.nextInt(10)));

        final result1 = BookingLogic.isTimeConflict(start1, end1, start2, end2);
        final result2 = BookingLogic.isTimeConflict(start2, end2, start1, end1);

        expect(result1, equals(result2));
      }
    });

    // 2. Uji calculateCompleteness
    test('MR 2 (Monotonisitas): calculateCompleteness bertambah jika item true ditambah', () {
      final baseItems = [true, false, false, false, false];
      final baseScore = BookingLogic.calculateCompleteness(baseItems);

      // Ubah satu false menjadi true
      final improvedItems = [true, true, false, false, false];
      final improvedScore = BookingLogic.calculateCompleteness(improvedItems);

      expect(improvedScore > baseScore, isTrue);
    });

    // 3. Uji isFormAvailable
    test('MR 3 (Translasi Waktu): isFormAvailable tidak berubah jika kedua waktu digeser konstan', () {
      final waktuPinjam = baseTime.add(const Duration(hours: 10));
      final now = baseTime.add(const Duration(hours: 8)); // Belum tersedia (H-2)

      final originalResult = BookingLogic.isFormAvailable(waktuPinjam, now);

      // Geser keduanya +24 jam
      const shift = Duration(hours: 24);
      final shiftedResult = BookingLogic.isFormAvailable(
        waktuPinjam.add(shift), 
        now.add(shift)
      );

      expect(shiftedResult, equals(originalResult));
    });

    // 4. Uji availableVehicleIds
    test('MR 4 (Subset Ketersediaan): Mempersempit rentang waktu tidak boleh mengurangi kendaraan tersedia', () {
      final vehicles = List.generate(5, (i) => 'v$i');
      
      for (var n = 0; n < 50; n++) {
        final bookings = List.generate(10, randomSlot);
        
        final startLuas = baseTime.add(Duration(hours: 10 + rnd.nextInt(20)));
        final endLuas = startLuas.add(Duration(hours: 10 + rnd.nextInt(5)));

        final hasilLuas = BookingLogic.availableVehicleIds(vehicles, bookings, startLuas, endLuas);
        
        // Persempit rentang: start digeser 2 jam lebih akhir, end digeser 2 jam lebih awal
        final startSempit = startLuas.add(const Duration(hours: 2));
        final endSempit = endLuas.subtract(const Duration(hours: 2));
        
        final hasilSempit = BookingLogic.availableVehicleIds(vehicles, bookings, startSempit, endSempit);

        // Jumlah kendaraan di rentang sempit harus >= rentang luas
        expect(hasilSempit.length >= hasilLuas.length, isTrue);
        // Semua kendaraan di rentang luas harus tetap ada di rentang sempit
        expect(hasilSempit.toSet().containsAll(hasilLuas), isTrue);
      }
    });

    test('MR 5 (Permutasi Daftar Jadwal): availableVehicleIds invarian terhadap acakan urutan booking', () {
      final vehicles = List.generate(5, (i) => 'v$i');
      for (var n = 0; n < 50; n++) {
        final bookings = List.generate(10, randomSlot);
        final start = baseTime.add(const Duration(hours: 10));
        final end = start.add(const Duration(hours: 5));

        final hasilAsli = BookingLogic.availableVehicleIds(vehicles, bookings, start, end).toSet();
        
        final shuffledBookings = List<BookingSlot>.from(bookings)..shuffle(Random(n));
        final hasilAcak = BookingLogic.availableVehicleIds(vehicles, shuffledBookings, start, end).toSet();

        expect(hasilAcak, equals(hasilAsli));
      }
    });

    // 5. Uji classifyVehicles
    test('MR 6 (Permutasi Kategori): classifyVehicles invarian terhadap acakan urutan booking', () {
      final vehicles = List.generate(5, (i) => 'v$i');
      final bookings = List.generate(10, randomSlot);
      const currentBookingId = 'b0';
      const currentVehicleId = 'v0';

      final hasilAsli = BookingLogic.classifyVehicles(
        vehicleIds: vehicles, 
        bookings: bookings, 
        currentBookingId: currentBookingId, 
        currentVehicleId: currentVehicleId
      );

      final shuffledBookings = List<BookingSlot>.from(bookings)..shuffle(rnd);
      
      final hasilAcak = BookingLogic.classifyVehicles(
        vehicleIds: vehicles, 
        bookings: shuffledBookings, 
        currentBookingId: currentBookingId, 
        currentVehicleId: currentVehicleId
      );

      // Panjang dan urutan kategori harus sama persis karena fungsi memiliki sorting internal
      expect(hasilAsli.length, equals(hasilAcak.length));
      for (var i = 0; i < hasilAsli.length; i++) {
        expect(hasilAsli[i].vehicleId, equals(hasilAcak[i].vehicleId));
        expect(hasilAsli[i].category, equals(hasilAcak[i].category));
      }
    });

    // 6. Uji swapVehicles
    test('MR 7 (Involusi): swapVehicles dua kali mengembalikan data ke asal', () {
      // Dibuat eksplisit (bukan randomSlot) untuk menjamin vehicleId berbeda,
      // sesuai deskripsi MR-7 di dokumen: "kendaraan yang berbeda"
      final a = BookingSlot(
        id: 'b1',
        vehicleId: 'v1',
        status: 'APPROVAL_1',
        start: baseTime,
        end: baseTime.add(const Duration(hours: 2)),
      );
      final b = BookingSlot(
        id: 'b2',
        vehicleId: 'v2',
        status: 'APPROVAL_2',
        start: baseTime.add(const Duration(hours: 5)),
        end: baseTime.add(const Duration(hours: 7)),
      );

      // Pastikan prasyarat MR-7 terpenuhi sebelum transformasi dijalankan
      expect(a.vehicleId, isNot(equals(b.vehicleId)));

      // Tukar pertama
      final swap1 = BookingLogic.swapVehicles(a, b);
      // Tukar kedua (kembalikan)
      final swap2 = BookingLogic.swapVehicles(swap1[0], swap1[1]);

      expect(swap2[0].vehicleId, equals(a.vehicleId));
      expect(swap2[1].vehicleId, equals(b.vehicleId));
    });
    // 7. Uji approveTransition
    test('MR 8 (Peralihan Bentrok): approveTransition merespons perubahan hasConflict dengan penolakan', () {
      // Kondisi operator normal tanpa konflik
      final resultAman = BookingLogic.approveTransition(
        role: 'operator', 
        jabatan: 'staf', 
        currentStatus: 'APPROVAL_1', 
        hasConflict: false
      );
      expect(resultAman.newStatus, equals('APPROVAL_2'));

      // Kondisi yang sama persis, tapi ada konflik
      final resultKonflik = BookingLogic.approveTransition(
        role: 'operator', 
        jabatan: 'staf', 
        currentStatus: 'APPROVAL_1', 
        hasConflict: true
      );
      expect(resultKonflik.error, equals('Kendaraan bentrok'));
      expect(resultKonflik.newStatus, isNull);
    });

    // Uji MR 9 (Elevasi Role): approveTransition
    test('MR 9 (Elevasi Role): Persetujuan admin pada APPROVAL_2 menghasilkan level status > persetujuan operator pada APPROVAL_1', () {
      // Source: operator menyetujui pada tahap APPROVAL_1
      final resOperator = BookingLogic.approveTransition(
        role: 'operator',
        jabatan: 'staf',
        currentStatus: 'APPROVAL_1',
        hasConflict: false,
      );

      // Follow-up: role diganti admin pada tahap berikutnya (APPROVAL_2),
      // jabatan dan hasConflict tetap sama
      final resAdmin = BookingLogic.approveTransition(
        role: 'admin',
        jabatan: 'staf',
        currentStatus: 'APPROVAL_2',
        hasConflict: false,
      );

      expect(resOperator.newStatus, isNotNull);
      expect(resAdmin.newStatus, isNotNull);

      // operator: APPROVAL_1 -> APPROVAL_2, admin: APPROVAL_2 -> APPROVAL_3
      final opLevel = int.parse(resOperator.newStatus!.split('_')[1]);
      final adminLevel = int.parse(resAdmin.newStatus!.split('_')[1]);
      expect(adminLevel > opLevel, isTrue);
    });

    // Uji boundary (pelengkap, bukan bagian dari MR-9)
    test('Boundary approveTransition: penolakan role user dan admin pada status di luar kewenangan', () {
      final resUserErr = BookingLogic.approveTransition(
        role: 'user',
        jabatan: 'manager divisi',
        currentStatus: 'APPROVAL_1',
      );
      expect(resUserErr.error, equals('Hanya dapat menyetujui status SUBMITTED'));

      final resAdminErr = BookingLogic.approveTransition(
        role: 'admin',
        jabatan: 'manager_umum',
        currentStatus: 'SUBMITTED',
      );
      expect(resAdminErr.error, equals('Hanya dapat menyetujui status APPROVAL_2'));
    });

    // Uji MR 10 (Transformasi Data/Status): availableVehicleIds
    test('MR 10 (Restriksi Status): Mengubah status booking menjadi ON_GOING harus mengurangi ketersediaan', () {
      final vehicles = List.generate(5, (i) => 'v$i');
      final start = baseTime;
      final end = baseTime.add(const Duration(hours: 2));

      // Source: Booking dengan status SUBMITTED (tidak memblokir kendaraan)
      final sourceBookings = [
        BookingSlot(id: 'b1', vehicleId: 'v1', status: 'SUBMITTED', start: start, end: end)
      ];
      final sourceAvail = BookingLogic.availableVehicleIds(vehicles, sourceBookings, start, end);

      // Prasyarat: v1 tersedia sebelum transformasi
      expect(sourceAvail.contains('v1'), isTrue);
      
      // Follow-up: Status diubah menjadi ON_GOING (memblokir kendaraan)
      final followUpBookings = [
        BookingSlot(id: 'b1', vehicleId: 'v1', status: 'ON_GOING', start: start, end: end)
      ];
      final followUpAvail = BookingLogic.availableVehicleIds(vehicles, followUpBookings, start, end);

      // Kendaraan yang tersedia setelah status diubah harus lebih sedikit
      expect(followUpAvail.length < sourceAvail.length, isTrue);
      // v1 harus hilang dari hasil follow-up
      expect(followUpAvail.contains('v1'), isFalse);
    });

    // MR 11 skenario (a): dari free
    test('MR 11 (Pergeseran Kategori - dari free): Menambah jadwal ON_GOING menggeser kendaraan dari free ke hardUnavailable', () {
      final vehicles = ['v1', 'v2'];
      const currentBookingId = 'b0';
      final end = baseTime.add(const Duration(hours: 2));

      // Source: v1 soft-booked, v2 masih free
      final sourceBookings = [
        BookingSlot(id: 'b1', vehicleId: 'v1', status: 'APPROVAL_1', start: baseTime, end: end)
      ];
      final sourceClass = BookingLogic.classifyVehicles(
        vehicleIds: vehicles, bookings: sourceBookings,
        currentBookingId: currentBookingId, currentVehicleId: null,
      );

      // Prasyarat: v2 berstatus free
      final sV2Check = sourceClass.firstWhere((v) => v.vehicleId == 'v2');
      expect(sV2Check.category, equals(VehicleCategory.free));

      // Follow-up: tambah jadwal ON_GOING pada v2
      final followUpBookings = [
        ...sourceBookings,
        BookingSlot(id: 'b2', vehicleId: 'v2', status: 'ON_GOING', start: baseTime, end: end)
      ];
      final followUpClass = BookingLogic.classifyVehicles(
        vehicleIds: vehicles, bookings: followUpBookings,
        currentBookingId: currentBookingId, currentVehicleId: null,
      );

      final fV2 = followUpClass.firstWhere((v) => v.vehicleId == 'v2');
      expect(fV2.category, equals(VehicleCategory.hardUnavailable));
    });

    // MR 11 skenario (b): dari soft-booked
    test('MR 11 (Pergeseran Kategori - dari soft-booked): Mengubah status jadwal menjadi ON_GOING menggeser kendaraan dari softBooked ke hardUnavailable', () {
      final vehicles = ['v1', 'v2'];
      const currentBookingId = 'b0';
      final end = baseTime.add(const Duration(hours: 2));

      // Source: v2 soft-booked (APPROVAL_1)
      final sourceBookings = [
        BookingSlot(id: 'b1', vehicleId: 'v2', status: 'APPROVAL_1', start: baseTime, end: end)
      ];
      final sourceClass = BookingLogic.classifyVehicles(
        vehicleIds: vehicles, bookings: sourceBookings,
        currentBookingId: currentBookingId, currentVehicleId: null,
      );

      // Prasyarat: v2 berstatus softBooked
      final sV2 = sourceClass.firstWhere((v) => v.vehicleId == 'v2');
      expect(sV2.category, equals(VehicleCategory.softBooked));

      // Follow-up: status jadwal b1 yang sama diubah menjadi ON_GOING (tanpa menambah jadwal baru)
      final followUpBookings = [
        BookingSlot(id: 'b1', vehicleId: 'v2', status: 'ON_GOING', start: baseTime, end: end)
      ];
      final followUpClass = BookingLogic.classifyVehicles(
        vehicleIds: vehicles, bookings: followUpBookings,
        currentBookingId: currentBookingId, currentVehicleId: null,
      );

      final fV2 = followUpClass.firstWhere((v) => v.vehicleId == 'v2');
      expect(fV2.category, equals(VehicleCategory.hardUnavailable));
    });

  });
}