# Analisis Mutation Analysis — Test Suite Metamorphic Testing BookingLogic

Dokumen kerja eksperimen (bahan Bab IV). Dibuat dari laporan `mutation-test-report/`
hasil run tanggal 2026-11-14.

## 1. Konfigurasi eksperimen

| Item | Nilai |
|---|---|
| Tool | `mutation_test` 1.8.0 |
| Perintah | `dart run mutation_test mutation_test.xml --no-builtin -f all -o mutation-test-report` |
| Aturan bawaan (builtin) | **Tidak dipakai**; hanya operator di `mutation_test.xml` |
| Kode yang dimutasi | `lib/utils/booking_logic.dart`, hanya baris 7 fungsi yang diuji |
| Test suite yang dijalankan | **Hanya** `test/booking_logic_mt_test.dart` (11 MR, 14 blok `test()`) |
| Kriteria killed | `flutter test` keluar dengan exit code ≠ 0 (minimal satu MR dilanggar) |
| Timeout per mutan | 300 detik (tidak ada mutan yang timeout) |

Fungsi dan baris yang dimutasi:

| No | Fungsi | Baris |
|---|---|---|
| 1 | isTimeConflict | 35–37 |
| 2 | availableVehicleIds (+ `blockingStatuses`) | 92–108 |
| 3 | classifyVehicles | 110–151 |
| 4 | swapVehicles | 152–157 |
| 5 | approveTransition | 158–190 |
| 6 | isFormAvailable | 192–194 |
| 7 | calculateCompleteness | 55–59 |

Operator mutasi (dikelompokkan sesuai Bab 3.2.11):

| Kategori | ID operator | Contoh |
|---|---|---|
| Logika | `logika.and_ke_or`, `logika.or_ke_and`, `logika.negasi_if`, `logika.negasi_if_continue`, `logika.negasi_operand_or`, `logika.hapus_negasi` | `&&` → `\|\|`, `if (c)` → `if (!(c))`, `!x.contains()` → `x.contains()` |
| Relasional | `relasional.eq_ke_neq`, `relasional.neq_ke_eq`, `relasional.before_ke_after`, `relasional.after_ke_before`, `relasional.before_ke_before_eq`, `relasional.after_ke_after_eq` | `==` → `!=`, `a.isBefore(b)` (a<b) → `!a.isAfter(b)` (a≤b) |
| Aritmatika | `aritmatika.tambah_ke_kurang`, `aritmatika.kurang_ke_tambah`, `aritmatika.kali_ke_bagi`, `aritmatika.bagi_ke_kali`, `aritmatika.subtract_ke_add`, `aritmatika.konstanta_durasi` | `/` → `*`, `.subtract(` → `.add(`, `Duration(hours: 1)` → `0` / `2` |
| Ekspresi/pemanggilan | `ekspresi.hapus_pemanggilan1/2`, `ekspresi.hapus_continue`, `ekspresi.balik_komparator`, `ekspresi.status_*`, `ekspresi.ganti_operand_a_ke_b`, `ekspresi.ganti_operand_b_ke_a` | hapus `blocked.add(...)`, `'ON_GOING'` → `'APPROVAL_3'`, `status: a.status` → `status: b.status` |

## 2. Hasil

| Status | Jumlah |
|---|---|
| Total mutant | 72 |
| Killed | 56 |
| Survived | 16 |
| Equivalent | 0 |
| Timeout | 0 |
| Stillborn (gagal compile) | 0 (lihat catatan validitas) |

**Mutation score = Killed / (Total − Equivalent) × 100% = 56 / (72 − 0) × 100% = 77,78%**

Mutation score per fungsi:

| Fungsi | Killed | Total | Skor |
|---|---|---|---|
| isTimeConflict | 4 | 5 | 80,0% |
| calculateCompleteness | 2 | 2 | 100% |
| availableVehicleIds | 7 | 8 | 87,5% |
| classifyVehicles | 14 | 17 | 82,4% |
| swapVehicles | 10 | 10 | 100% |
| approveTransition | 19 | 25 | 76,0% |
| isFormAvailable | 0 | 5 | 0% |

## 3. Analisis mutan survived (16)

Semua mutan yang lolos sudah diperiksa manual. **Tidak ada yang equivalent**: untuk setiap
mutan ada input yang membuat output-nya berbeda dari program asli (kolom "Bukti non-equivalent").

| # | Baris | Operator | Mutasi | Bukti non-equivalent | Penyebab lolos |
|---|---|---|---|---|---|
| 1 | 36 | logika.and_ke_or | `A && B` → `A \|\| B` di isTimeConflict | A=[00–01], B=[05–06] → asli `false`, mutan `true` | MR-1 (simetri) tetap terpenuhi karena `\|\|` juga simetris. MR-4/5/10 tidak menguji kasus rentang yang **tidak** beririsan |
| 2 | 92 | ekspresi.status_approval2 | `APPROVAL_2` dihapus dari `blockingStatuses` | booking APPROVAL_2 yang beririsan → asli memblokir, mutan tidak | MR-10 hanya mentransformasi SUBMITTED → ON_GOING, bukan → APPROVAL_2 |
| 3 | 120 | ekspresi.hapus_continue | booking milik sendiri tidak dilewati | booking `currentBookingId` ON_GOING → kendaraan sendiri ikut jadi hard | MR-6/MR-11 tidak memasukkan jadwal milik booking yang sedang diedit |
| 4 | 147 | ekspresi.hapus_pemanggilan2 | `result.sort(...)` dihapus | hasil tidak lagi terurut current → free → soft → hard | MR-6 membandingkan dua eksekusi dengan `vehicleIds` sama, sehingga urutan tanpa sort pun tetap identik |
| 5 | 149 | ekspresi.balik_komparator | urutan sort dibalik | urutan menjadi hard → … → current | Sama dengan #4: relasi permutasi tidak sensitif terhadap urutan keluaran yang konsisten |
| 6 | 168 | relasional.neq_ke_eq | `!= 'SUBMITTED'` → `== 'SUBMITTED'` | manager divisi pada SUBMITTED → asli APPROVAL_1, mutan ditolak | Cabang `role == 'user' && manager` tidak dicakup MR-8/MR-9 (hanya operator & admin) |
| 7 | 168 | ekspresi.status_submitted | `'SUBMITTED'` → `'APPROVAL_1'` | idem #6 | idem #6 |
| 8 | 168 | logika.negasi_if | negasi kondisi | idem #6 | idem #6 |
| 9 | 171 | ekspresi.status_approval1 | hasil `APPROVAL_1` → `APPROVAL_2` | manager divisi menyetujui → status lompat ke APPROVAL_2 | idem #6 |
| 10 | 183 | relasional.eq_ke_neq | `role == 'manager_umum'` → `!=` | role manager_umum → asli boleh, mutan ditolak | MR-9 hanya memakai role `admin`, yang sudah memenuhi operand pertama `\|\|` |
| 11 | 183 | logika.negasi_operand_or | `!(role == 'manager_umum')` | idem #10 | idem #10 |
| 12 | 193 | relasional.after_ke_before | `now > batas` → `now < batas` | waktuPinjam=10:00, now=09:30 → asli `true`, mutan `false` | **MR-3 (translasi) secara konstruksi tidak bisa membunuh mutan yang hanya bergantung pada selisih waktu**: hasil mutan juga invarian terhadap pergeseran yang sama |
| 13 | 193 | aritmatika.subtract_ke_add | H-1 jam → H+1 jam | now=09:30 → asli `true`, mutan `false` | idem #12 |
| 14 | 193 | aritmatika.konstanta_durasi | H-1 jam → H-0 jam | now=09:30 → asli `true`, mutan `false` | idem #12 |
| 15 | 193 | aritmatika.konstanta_durasi | H-1 jam → H-2 jam | now=08:30 → asli `false`, mutan `true` | idem #12 |
| 16 | 193 | relasional.after_ke_after_eq | `>` → `≥` | now tepat 09:00 → asli `false`, mutan `true` | idem #12 |

Ringkasan penyebab:
- **Keterbatasan relasi MR** (#1, #4, #5, #12–16): MR invariansi seperti simetri, permutasi dan translasi tetap terpenuhi oleh mutan yang mempertahankan sifat invarian tersebut.
- **Cakupan input MR** (#2, #3, #6–11): jalur kode (role manager divisi/manager_umum, status APPROVAL_2, booking milik sendiri) tidak dijangkau oleh source/follow-up test case MR yang dirancang.

## 4. Catatan validitas

1. **Mutan stillborn sudah dihilangkan.** Pada run pertama, pola `negasi_if` (sama dengan pola bawaan tool)
   melompati `if (...) continue;` dan menghasilkan 2 mutan yang gagal compile (baris 102 dan 120).
   Tool menghitungnya sebagai killed. Pola sudah dibatasi (`[^;{]`) dan ditambah operator `negasi_if_continue`,
   lalu eksperimen dijalankan ulang. Semua mutan yang killed pada run final sudah diperiksa dan berupa kode Dart yang valid.
2. **Hanya suite MT yang dijalankan.** Unit test konvensional di `test/booking_logic_unit_test.dart`
   tidak ikut berkontribusi pada skor.
3. **Kode yang diuji adalah kode yang dipakai aplikasi.** Ketujuh fungsi dipanggil langsung oleh halaman aplikasi:
   - `isTimeConflict`, `availableVehicleIds`: `vehicle_booking_form_page.dart`
   - `classifyVehicles`, `swapVehicles`, `approveTransition`, `isFormAvailable`, `isTimeConflict`: `detail_peminjaman_page.dart`
   - `calculateCompleteness`: `form_kondisi_kendaraan_awal_page.dart`, `form_pengembalian_kendaraan_page.dart`
4. **Semua MR ikut dievaluasi.** Pada run sebelumnya `swapVehicles` tidak menghasilkan mutan, sehingga MR-7
   tidak terukur. Operator penggantian operand (`ekspresi.ganti_operand_*`) ditambahkan dan menghasilkan
   10 mutan pada `swapVehicles`. Kesepuluhnya killed oleh MR-7, karena relasi involusi memeriksa
   seluruh atribut dokumen (id, kendaraan, status, waktu).
5. **Determinisme.** Setiap MR memakai `Random(seed)` sendiri, sehingga data uji identik di setiap eksekusi dan tidak bergantung pada urutan test.

## 5. Eksekusi MT pada program asli

`flutter test test/booking_logic_mt_test.dart`: **14/14 test lulus** (11 MR; MR-11 punya 2 skenario,
ditambah 1 blok per MR lainnya). Tidak ada pelanggaran MR pada program asli.

| MR | Fungsi | Jumlah pasangan source/follow-up |
|---|---|---|
| MR-1 Simetri | isTimeConflict | 200 acak + 5 nilai batas |
| MR-2 Monotonisitas | calculateCompleteness | 200 acak + 3 nilai batas |
| MR-3 Translasi Waktu | isFormAvailable | 110 selisih waktu (termasuk −61/−60/−59 menit) × 5 pergeseran |
| MR-4 Subset Ketersediaan | availableVehicleIds | 100 acak + 1 set nilai batas (4 jadwal tepi) |
| MR-5 Permutasi Jadwal | availableVehicleIds | 100 acak |
| MR-6 Permutasi Kategori | classifyVehicles | 100 acak |
| MR-7 Involusi | swapVehicles | 100 acak |
| MR-8 Peralihan Bentrok | approveTransition | 10 kombinasi (5 jabatan × 2 operatorType) |
| MR-9 Elevasi Role | approveTransition | 5 variasi jabatan |
| MR-10 Restriksi Status | availableVehicleIds | 100 acak + 3 nilai batas (irisan 1 menit, rentang identik) |
| MR-11 Pergeseran Kategori | classifyVehicles | (a) 100 acak, (b) 100 acak (semua status soft) |
