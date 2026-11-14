class BookingSlot {
  final String id;
  final String vehicleId;
  final String status;
  final DateTime start;
  final DateTime end;

  const BookingSlot({
    required this.id,
    required this.vehicleId,
    required this.status,
    required this.start,
    required this.end,
  });
}

enum VehicleCategory { current, free, softBooked, hardUnavailable }

class VehicleClass {
  final String vehicleId;
  final VehicleCategory category;
  final String? otherBookingId;
  const VehicleClass(this.vehicleId, this.category, this.otherBookingId);
}

class ApprovalResult {
  final String? newStatus;
  final String? error;
  const ApprovalResult.ok(this.newStatus) : error = null;
  const ApprovalResult.fail(this.error) : newStatus = null;
}
class BookingLogic {
  
  // 1. Logika untuk mengecek bentrok waktu (Conflict Detection)
  static bool isTimeConflict(DateTime newStart, DateTime newEnd, DateTime existingStart, DateTime existingEnd) {
    return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
  }

  // 2. Logika untuk menentukan status awal berdasarkan role dan jabatan
  static String determineInitialStatus(String role, String jabatan) {
    final jab = jabatan.toLowerCase();
    
    if (role == 'admin' || role == 'manager_umum') {
      return 'APPROVAL_3';
    } else if (role == 'operator') {
      return 'APPROVAL_2';
    } else if (role == 'user' && jab.contains('manager')) {
      return 'APPROVAL_1';
    } else {
      return 'SUBMITTED';
    }
  }

  // 3. Logika untuk menghitung persentase kelengkapan kendaraan
  static double calculateCompleteness(List<bool> items) {
    if (items.isEmpty) return 0.0;
    final completed = items.where((item) => item == true).length;
    return completed / items.length;
  }

  // ==========================================
  // TAMBAHAN UNTUK MR 2: Validasi Waktu
  // ==========================================
  static String? validateBookingTime(DateTime waktuPinjam, DateTime waktuKembali, DateTime now) {
    if (waktuKembali.isBefore(waktuPinjam)) {
      return 'Waktu kembali harus setelah waktu pinjam';
    }
    if (waktuPinjam.isBefore(now)) {
      return 'Waktu pinjam tidak boleh di masa lalu';
    }
    return null; // Null berarti lolos validasi
  }

  // ==========================================
  // TAMBAHAN UNTUK MR 4: Validasi Odometer
  // ==========================================
  static String? validateOdometer(int odometerAwal, int odometerAkhir) {
    if (odometerAkhir < odometerAwal) {
      return 'Odometer akhir tidak boleh kurang dari odometer awal';
    }
    if (odometerAkhir == odometerAwal) {
      return 'Odometer akhir tidak boleh sama dengan odometer awal. Minimal bertambah 1 km';
    }
    return null;
  }

  // Kalkulasi jarak tempuh
  static int calculateDistance(int odometerAwal, int odometerAkhir) {
    return odometerAkhir - odometerAwal;
  }

  static const List<String> blockingStatuses = ['APPROVAL_2', 'APPROVAL_3', 'ON_GOING'];

  static List<String> availableVehicleIds(
    List<String> vehicleIds,
    List<BookingSlot> bookings,
    DateTime start,
    DateTime end,
  ) {
    final blocked = <String>{};
    for (final b in bookings) {
      if (!blockingStatuses.contains(b.status)) continue;
      if (isTimeConflict(start, end, b.start, b.end)) {
        blocked.add(b.vehicleId);
      }
    }
    return vehicleIds.where((id) => !blocked.contains(id)).toList();
  }

  static List<VehicleClass> classifyVehicles({
    required List<String> vehicleIds,
    required List<BookingSlot> bookings,
    required String currentBookingId,
    required String? currentVehicleId,
  }) {
    final hard = <String>{};
    final soft = <String, String>{}; // vehicleId -> bookingId

    for (final b in bookings) {
      if (b.id == currentBookingId) continue;
      if (b.status == 'ON_GOING') {
        hard.add(b.vehicleId);
      } else if (['SUBMITTED', 'APPROVAL_1', 'APPROVAL_2', 'APPROVAL_3']
          .contains(b.status)) {
        soft[b.vehicleId] = b.id; // sengaja sama seperti kode asli
      }
    }

    final result = vehicleIds.map((id) {
      if (id == currentVehicleId) {
        return VehicleClass(id, VehicleCategory.current, null);
      } else if (hard.contains(id)) {
        return VehicleClass(id, VehicleCategory.hardUnavailable, null);
      } else if (soft.containsKey(id)) {
        return VehicleClass(id, VehicleCategory.softBooked, soft[id]);
      }
      return VehicleClass(id, VehicleCategory.free, null);
    }).toList();

    int rank(VehicleCategory c) {
      switch (c) {
        case VehicleCategory.current: return 0;
        case VehicleCategory.free: return 1;
        case VehicleCategory.softBooked: return 2;
        case VehicleCategory.hardUnavailable: return 3;
      }
    }

    result.sort((a, b) => rank(a.category).compareTo(rank(b.category)));
    return result;
  }
  static List<BookingSlot> swapVehicles(BookingSlot a, BookingSlot b) {
      return [
        BookingSlot(id: a.id, vehicleId: b.vehicleId, status: a.status, start: a.start, end: a.end),
        BookingSlot(id: b.id, vehicleId: a.vehicleId, status: b.status, start: b.start, end: b.end),
      ];
    }
    static ApprovalResult approveTransition({
    required String role,
    required String jabatan,
    required String currentStatus,
    String? operatorType,
    bool hasConflict = false,
  }) {
    final isManagerDivisi = jabatan.toLowerCase().contains('manager');

    if (role == 'user' && isManagerDivisi) {
      if (currentStatus != 'SUBMITTED') {
        return const ApprovalResult.fail('Hanya dapat menyetujui status SUBMITTED');
      }
      return const ApprovalResult.ok('APPROVAL_1');
    } else if (role == 'operator') {
      if (operatorType == 'ruang_meeting') {
        return const ApprovalResult.fail('Operator Ruang Meeting tidak bisa menyetujui');
      }
      if (currentStatus != 'APPROVAL_1') {
        return const ApprovalResult.fail('Hanya dapat menyetujui status APPROVAL_1');
      }
      if (hasConflict) {
        return const ApprovalResult.fail('Kendaraan bentrok');
      }
      return const ApprovalResult.ok('APPROVAL_2');
    } else if (role == 'admin' || role == 'manager_umum') {
      if (currentStatus != 'APPROVAL_2') {
        return const ApprovalResult.fail('Hanya dapat menyetujui status APPROVAL_2');
      }
      return const ApprovalResult.ok('APPROVAL_3');
    }
    return const ApprovalResult.fail('Role tidak memiliki izin');
  }

  static bool isFormAvailable(DateTime waktuPinjam, DateTime now) {
    return now.isAfter(waktuPinjam.subtract(const Duration(hours: 1)));
  }
}