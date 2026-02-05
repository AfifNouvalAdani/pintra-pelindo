import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  late TextEditingController _jabatanController;

  String _selectedRole = 'user';

  final List<String> _roleOptions = [
    'admin',
    'operator',
    'user',
  ];

  String _selectedJabatan = 'staff';

  final List<String> _jabatanOptions = [
    'staff',
    'manager',
  ];

  final List<String> _divisiOptions = [
    'SDM',
    'IT',
    'umum',
    'keuangan',
    'operasi',
    'pemasaran',
  ];

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
    
    // ✅ Load jabatan dari userData atau default 'staff'
    _selectedJabatan = widget.userData?['jabatan'] ?? 'staff';
    _selectedRole = widget.userData?['role'] ?? 'user';
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
        final jabatan = _selectedJabatan; // ✅ Ambil dari dropdown

        if (widget.isEdit) {
          // MODE EDIT
          await _updateUser(
            nama: nama,
            nipp: nipp,
            email: email,
            noTelp: noTelp,
            divisi: divisi,
            jabatan: jabatan,
          );
        } else {
          // MODE TAMBAH BARU
          await _createNewUser(
            nama: nama,
            nipp: nipp,
            email: email,
            noTelp: noTelp,
            divisi: divisi,
            jabatan: jabatan,
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
  }) async {
    try {
      // 1. Cek apakah NIPP sudah digunakan
      final nippCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('nipp', isEqualTo: nipp)
          .get();

      if (nippCheck.docs.isNotEmpty) {
        throw 'NIPP sudah terdaftar';
      }

      // 2. Cek apakah email sudah digunakan
      final emailCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (emailCheck.docs.isNotEmpty) {
        throw 'Email sudah terdaftar';
      }

      // 3. Daftarkan ke Firebase Auth
      // Password = NIPP (sesuai dengan logic login)
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: nipp, // Password sama dengan NIPP
      );

      final uid = userCredential.user!.uid;

      // 4. Simpan data user ke Firestore dengan UID sebagai document ID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'nama': nama,
        'nipp': nipp,
        'email': email,
        'noTelp': int.tryParse(noTelp) ?? noTelp,
        'divisi': divisi,
        'jabatan': jabatan,
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('User berhasil ditambahkan!');
      
      // Kembali ke halaman sebelumnya dengan result true
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
    }
  }

  Future<void> _updateUser({
    required String nama,
    required String nipp,
    required String email,
    required String noTelp,
    required String divisi,
    required String jabatan,
  }) async {
    try {
      final userId = widget.userData!['id'];
      final oldNipp = widget.userData!['nipp'];
      final oldEmail = widget.userData!['email'];

      // 1. Jika NIPP berubah, cek apakah NIPP baru sudah digunakan
      if (nipp != oldNipp) {
        final nippCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('nipp', isEqualTo: nipp)
            .get();

        if (nippCheck.docs.isNotEmpty) {
          throw 'NIPP sudah terdaftar';
        }
      }

      // 2. Jika email berubah, cek apakah email baru sudah digunakan
      if (email != oldEmail) {
        final emailCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .get();

        if (emailCheck.docs.isNotEmpty) {
          throw 'Email sudah terdaftar';
        }
      }

      // 3. Update data di Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'nama': nama,
        'nipp': nipp,
        'email': email,
        'noTelp': int.tryParse(noTelp) ?? noTelp,
        'divisi': divisi,
        'jabatan': jabatan,
        'role': _selectedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Update email di Firebase Auth (jika berubah)
      if (email != oldEmail) {
        print('Email changed, but Auth email not updated (requires admin SDK)');
      }

      _showSnackbar('User berhasil diupdate!');
      
      // Kembali ke halaman sebelumnya dengan result true
      Navigator.pop(context, true);
      
    } catch (e) {
      throw e;
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email wajib diisi';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? _validateNIPP(String? value) {
    if (value == null || value.isEmpty) {
      return 'NIPP wajib diisi';
    }
    final nippRegex = RegExp(r'^[0-9]+$');
    if (!nippRegex.hasMatch(value)) {
      return 'NIPP hanya boleh berisi angka';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'No. Telepon wajib diisi';
    }
    final phoneRegex = RegExp(r'^[0-9]+$');
    if (!phoneRegex.hasMatch(value)) {
      return 'No. Telepon hanya boleh berisi angka';
    }
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nama Lengkap',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _namaController,
                            decoration: InputDecoration(
                              hintText: 'Masukkan nama lengkap',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outlined,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            validator: (v) => _validateRequired(v, 'Nama'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // NIPP
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NIPP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nippController,
                            decoration: InputDecoration(
                              hintText: 'Masukkan NIPP',
                              filled: true,
                              fillColor: widget.isEdit 
                                  ? Colors.grey.shade100 
                                  : Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.badge_outlined,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _validateNIPP,
                            readOnly: widget.isEdit,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Email
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: 'Masukkan email',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // No. Telepon
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No. Telepon',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _noTelpController,
                            decoration: InputDecoration(
                              hintText: 'Masukkan nomor telepon',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.phone_outlined,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: _validatePhone,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Divisi
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Divisi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
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
                              decoration: InputDecoration(
                                hintText: 'Pilih divisi',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.business_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
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
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Jabatan
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jabatan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedJabatan,
                              decoration: InputDecoration(
                                hintText: 'Pilih jabatan',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.work_outline,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
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
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Role
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Role',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedRole,
                              decoration: InputDecoration(
                                hintText: 'Pilih role',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.shield_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
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
                                  case 'manager_umum':
                                    label = 'Manager Umum';
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
                                });
                              },
                              dropdownColor: Colors.white,
                            ),
                          ),
                        ],
                      ),

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
}