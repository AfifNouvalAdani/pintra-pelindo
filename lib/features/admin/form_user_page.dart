import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FormUserPage extends StatefulWidget {
  final String role;
  final String userName;
  final String userId;
  final String userDivision;
  final Map<String, dynamic>? userData;
  final bool isEdit;

  const FormUserPage({
    super.key,
    required this.role,
    required this.userName,
    required this.userId,
    required this.userDivision,
    this.userData,
    this.isEdit = false,
  });

  @override
  State<FormUserPage> createState() => _FormUserPageState();
}

class _FormUserPageState extends State<FormUserPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _namaController;
  late TextEditingController _nippController;
  late TextEditingController _emailController;
  late TextEditingController _noTelpController;
  late TextEditingController _divisiController;

  String _selectedRole = 'user';
  final List<String> _roleOptions = ['admin', 'operator', 'user'];

  String _selectedJabatan = 'staff';
  final List<String> _jabatanOptions = ['staff', 'manager'];

  final List<String> _divisiOptions = [
    'SDM',
    'IT',
    'umum',
    'keuangan',
    'teknik',
    'komersil',
    'properti',
    'perencanaan dan pengendalian',
    'manajemen, mutu dan resiko',
    'tanggung jawab sosial dan lingkungan',
    'HSSE',
  ];

  String? _selectedOperatorType; // null = umum (semua), 'kendaraan', 'ruang_meeting'

  final List<Map<String, dynamic>> _operatorTypeOptions = [
    {
      'value': null,
      'label': 'Semua (Umum)',
      'subtitle': 'Akses kendaraan & ruang meeting',
      'icon': Icons.admin_panel_settings_outlined,
    },
    {
      'value': 'kendaraan',
      'label': 'Kendaraan',
      'subtitle': 'Hanya approval kendaraan',
      'icon': Icons.directions_car_outlined,
    },
    {
      'value': 'ruang_meeting',
      'label': 'Ruang Meeting',
      'subtitle': 'Hanya approval ruang meeting',
      'icon': Icons.meeting_room_outlined,
    },
  ];
  // ===========================================

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(
      text: widget.userData?['nama'] ?? '',
    );
    _nippController = TextEditingController(
      text: widget.userData?['nipp'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.userData?['email'] ?? '',
    );
    _noTelpController = TextEditingController(
      text: widget.userData?['noTelp']?.toString() ?? '',
    );
    _divisiController = TextEditingController(
      text: widget.userData?['divisi'] ?? '',
    );

    _selectedJabatan = widget.userData?['jabatan'] ?? 'staff';
    _selectedRole = widget.userData?['role'] ?? 'user';

    // ===== TAMBAHAN: Load spesialisasi jika ada (perbaikan error) =====
    if (widget.isEdit) {
      _selectedOperatorType = widget.userData?['operatorType'] as String?;
    } else {
      _selectedOperatorType = null; // default null (umum) untuk user baru
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nippController.dispose();
    _emailController.dispose();
    _noTelpController.dispose();
    _divisiController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nama = _namaController.text.trim();
      final nipp = _nippController.text.trim();
      final email = _emailController.text.trim();
      final noTelp = _noTelpController.text.trim();
      final divisi = _divisiController.text.trim();
      final jabatan = _selectedJabatan;

      // ===== TAMBAHAN: Ambil nilai spesialisasi, hanya relevan jika role operator =====
      final String? operatorType =
          _selectedRole == 'operator' ? _selectedOperatorType : null;

      if (widget.isEdit) {
        await _updateUser(
          nama: nama,
          nipp: nipp,
          email: email,
          noTelp: noTelp,
          divisi: divisi,
          jabatan: jabatan,
          operatorType: operatorType,
        );
      } else {
        await _createNewUser(
          nama: nama,
          nipp: nipp,
          email: email,
          noTelp: noTelp,
          divisi: divisi,
          jabatan: jabatan,
          operatorType: operatorType,
        );
      }
    } catch (e) {
      print('Error saving user: $e');
      _showSnackbar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewUser({
    required String nama,
    required String nipp,
    required String email,
    required String noTelp,
    required String divisi,
    required String jabatan,
    String? operatorType,
  }) async {
    FirebaseApp? secondaryApp;

    try {
      final nippCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('nipp', isEqualTo: nipp)
          .get();
      if (nippCheck.docs.isNotEmpty) throw 'NIPP sudah terdaftar';

      final emailCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      if (emailCheck.docs.isNotEmpty) throw 'Email sudah terdaftar';

      secondaryApp = await Firebase.initializeApp(
        name: 'secondaryApp',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: nipp,
      );

      final uid = userCredential.user!.uid;

      await secondaryAuth.signOut();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nama': nama,
        'nipp': nipp,
        'email': email,
        'noTelp': noTelp,
        'divisi': divisi,
        'jabatan': jabatan,
        'role': _selectedRole,
        if (operatorType != null) 'operatorType': operatorType,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('User berhasil ditambahkan!');
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email sudah digunakan';
          break;
        case 'weak-password':
          errorMessage = 'Password terlalu lemah';
          break;
        case 'invalid-email':
          errorMessage = 'Format email tidak valid';
          break;
        default:
          errorMessage = 'Error Firebase Auth: ${e.message}';
      }
      throw errorMessage;
    } finally {
      await secondaryApp?.delete();
    }
  }

  Future<void> _updateUser({
    required String nama,
    required String nipp,
    required String email,
    required String noTelp,
    required String divisi,
    required String jabatan,
    String? operatorType,
  }) async {
    try {
      final userId = widget.userData!['id'];
      final oldNipp = widget.userData!['nipp'];
      final oldEmail = widget.userData!['email'];

      if (nipp != oldNipp) {
        final nippCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('nipp', isEqualTo: nipp)
            .get();
        if (nippCheck.docs.isNotEmpty) throw 'NIPP sudah terdaftar';
      }

      if (email != oldEmail) {
        final emailCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .get();
        if (emailCheck.docs.isNotEmpty) throw 'Email sudah terdaftar';
      }

        final Map<String, dynamic> updateData = {
          'nama': nama,
          'nipp': nipp,
          'email': email,
          'noTelp': noTelp,
          'divisi': divisi,
          'jabatan': jabatan,
          'role': _selectedRole,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (operatorType != null) {
          updateData['operatorType'] = operatorType;
        } else {
          updateData['operatorType'] = FieldValue.delete();
        }
        await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update(updateData);

      if (email != oldEmail) {
        print('Email changed, but Auth email not updated (requires admin SDK)');
      }

      _showSnackbar('User berhasil diupdate!');
      Navigator.pop(context, true);
    } catch (e) {
      throw e;
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email wajib diisi';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Format email tidak valid';
    return null;
  }

  String? _validateNIPP(String? value) {
    if (value == null || value.isEmpty) return 'NIPP wajib diisi';
    final nippRegex = RegExp(r'^[0-9]+$');
    if (!nippRegex.hasMatch(value)) return 'NIPP hanya boleh berisi angka';
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) return '$fieldName wajib diisi';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'No. Telepon wajib diisi';
    final phoneRegex = RegExp(r'^[0-9]+$');
    if (!phoneRegex.hasMatch(value)) return 'No. Telepon hanya boleh berisi angka';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.grey.shade700,
                        size: 20,
                      ),
                    ),
                    Text(
                      widget.isEdit ? 'Edit User' : 'Tambah User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade100,
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 24,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // Judul
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEdit ? 'Edit Data User' : 'Tambah User Baru',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isEdit
                          ? 'Perbarui data pengguna yang sudah ada'
                          : 'Tambahkan pengguna baru ke dalam sistem',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Informasi password
                      if (!widget.isEdit)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade100,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Password akan otomatis sama dengan NIPP',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Nama Lengkap
                      _buildLabel('Nama Lengkap'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _namaController,
                        decoration: _inputDecoration(
                          hint: 'Masukkan nama lengkap',
                          icon: Icons.person_outlined,
                        ),
                        validator: (v) => _validateRequired(v, 'Nama'),
                      ),
                      const SizedBox(height: 16),

                      // NIPP
                      _buildLabel('NIPP'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nippController,
                        decoration: _inputDecoration(
                          hint: 'Masukkan NIPP',
                          icon: Icons.badge_outlined,
                          fillColor: widget.isEdit ? Colors.grey.shade100 : null,
                        ),
                        keyboardType: TextInputType.number,
                        validator: _validateNIPP,
                        readOnly: widget.isEdit,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      _buildLabel('Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        decoration: _inputDecoration(
                          hint: 'Masukkan email',
                          icon: Icons.email_outlined,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),

                      // No. Telepon
                      _buildLabel('No. Telepon'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _noTelpController,
                        decoration: _inputDecoration(
                          hint: 'Masukkan nomor telepon',
                          icon: Icons.phone_outlined,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 16),

                      // Divisi
                      _buildLabel('Divisi'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _divisiOptions.contains(_divisiController.text)
                              ? _divisiController.text
                              : null,
                          decoration: _inputDecoration(
                            hint: 'Pilih divisi',
                            icon: Icons.business_outlined,
                            withBackground: false,
                          ),
                          items: _divisiOptions.map((divisi) {
                            return DropdownMenuItem(
                              value: divisi,
                              child: Text(divisi),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _divisiController.text = value;
                              });
                            }
                          },
                          validator: (v) => _validateRequired(v, 'Divisi'),
                          dropdownColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Jabatan
                      _buildLabel('Jabatan'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedJabatan,
                          decoration: _inputDecoration(
                            hint: 'Pilih jabatan',
                            icon: Icons.work_outline,
                            withBackground: false,
                          ),
                          items: _jabatanOptions.map((jabatan) {
                            String label;
                            switch (jabatan) {
                              case 'staff':
                                label = 'Staff';
                                break;
                              case 'manager':
                                label = 'Manager';
                                break;
                              default:
                                label = jabatan;
                            }
                            return DropdownMenuItem(
                              value: jabatan,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedJabatan = value!;
                            });
                          },
                          dropdownColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Role
                      _buildLabel('Role'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: _inputDecoration(
                            hint: 'Pilih role',
                            icon: Icons.shield_outlined,
                            withBackground: false,
                          ),
                          items: _roleOptions.map((role) {
                            String label;
                            switch (role) {
                              case 'admin':
                                label = 'Admin';
                                break;
                              case 'operator':
                                label = 'Operator';
                                break;
                              case 'user':
                                label = 'User';
                                break;
                              default:
                                label = role;
                            }
                            return DropdownMenuItem(
                              value: role,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                              // ===== TAMBAHAN: Reset spesialisasi jika bukan operator =====
                              if (value != 'operator') {
                                _selectedOperatorType = null;
                              }
                            });
                          },
                          dropdownColor: Colors.white,
                        ),
                      ),

                      // ===== TAMBAHAN: Widget Spesialisasi Operator =====
                      if (_selectedRole == 'operator') ...[
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Spesialisasi Operator',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    'Opsional',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Kosongkan untuk operator umum yang bisa akses semua.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 3 pilihan kartu
                            Column(
                              children: _operatorTypeOptions.map((opt) {
                                final optValue = opt['value'] as String?;
                                final isSelected = _selectedOperatorType == optValue;
                                final color = isSelected
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade500;

                                return GestureDetector(
                                  onTap: () => setState(() => _selectedOperatorType = optValue),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.shade50
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue.shade400
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.blue.shade100
                                                : Colors.grey.shade200,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            opt['icon'] as IconData,
                                            size: 20,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                opt['label'] as String,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? Colors.blue.shade800
                                                      : Colors.grey.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                opt['subtitle'] as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(Icons.check_circle_rounded,
                                              color: Colors.blue.shade600, size: 20)
                                        else
                                          Icon(Icons.radio_button_unchecked,
                                              color: Colors.grey.shade400, size: 20),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isEdit ? 'Update User' : 'Tambah User',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tombol Batal
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper untuk label form
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade800,
      ),
    );
  }

  // Helper untuk dekorasi input
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Color? fillColor,
    bool withBackground = true,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: fillColor ?? Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.grey.shade600,
      ),
    );
  }
}