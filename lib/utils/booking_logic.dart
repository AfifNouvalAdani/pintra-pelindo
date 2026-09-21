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
}