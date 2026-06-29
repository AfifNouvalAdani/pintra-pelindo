import 'package:flutter/material.dart';
import 'home_banner.dart';
import 'banner_service.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageBannerPage extends StatefulWidget {
  final String userId;

  const ManageBannerPage({super.key, required this.userId});

  @override
  State<ManageBannerPage> createState() => _ManageBannerPageState();
}

class _ManageBannerPageState extends State<ManageBannerPage> {
  final BannerService _bannerService = BannerService();
  List<HomeBanner> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('home_banner')
          .orderBy('order')
          .get();

      if (!mounted) return;

      setState(() {
        _banners = snapshot.docs
            .map((doc) => HomeBanner.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data banner: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addBanner() async {
    if (_banners.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maksimal 3 banner. Hapus salah satu terlebih dahulu.'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    String? imageBase64;

    bool? success = await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.blue.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Tambah Banner Baru'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul Banner',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await BannerService.pickAndCropImage();
                      if (picked != null) {
                        imageBase64 = picked;
                        setStateDialog(() {});
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Pilih & Crop Gambar (21:9)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (imageBase64 != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Gambar dipilih',
                          style: TextStyle(
                              fontSize: 13, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Batal',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (imageBase64 == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Pilih gambar terlebih dahulu'),
                        backgroundColor: Colors.orange.shade600,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    if (success == true && imageBase64 != null) {
      final newOrder = _banners.isEmpty
          ? 1
          : _banners.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1;
      await _bannerService.addBanner(
        title: titleController.text,
        imageBase64: imageBase64!,
        userId: widget.userId,
        order: newOrder,
      );
      _loadBanners();
    }
  }

  Future<void> _editBanner(HomeBanner banner) async {
    final titleController = TextEditingController(text: banner.title);
    bool isActive = banner.isActive;
    int order = banner.order;
    String? newImageBase64;

    bool? changed = await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_outlined,
                      color: Colors.blue.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Edit Banner'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul Banner',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.toggle_on_outlined,
                          color: Colors.grey.shade600, size: 18),
                      const SizedBox(width: 8),
                      Text('Aktif',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade700)),
                      const Spacer(),
                      Switch(
                        value: isActive,
                        onChanged: (val) =>
                            setStateDialog(() => isActive = val),
                        activeColor: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sort, color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 8),
                          Text('Urutan: $order',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade700)),
                        ],
                      ),
                      Slider(
                        min: 1,
                        max: 3,
                        divisions: 2,
                        value: order.toDouble(),
                        activeColor: Colors.blue.shade700,
                        onChanged: (val) =>
                            setStateDialog(() => order = val.round()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      newImageBase64 = await BannerService.pickAndCropImage();
                      if (newImageBase64 != null && context.mounted) {
                        setStateDialog(() {});
                      }
                    },
                    icon: const Icon(Icons.change_circle_outlined),
                    label: const Text('Ganti Gambar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (newImageBase64 != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text('Gambar baru dipilih',
                            style: TextStyle(
                                fontSize: 13, color: Colors.green.shade800)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Batal',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    if (changed == true) {
      await _bannerService.updateBanner(
        bannerId: banner.id,
        title: titleController.text,
        imageBase64: newImageBase64,
        isActive: isActive,
        userId: widget.userId,
        order: order,
      );
      _loadBanners();
    }
  }

  Future<void> _deleteBanner(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Hapus Banner'),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus banner ini? Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _bannerService.deleteBanner(id);
      _loadBanners();
    }
  }

  Widget _buildImageSafe(String base64String) {
    if (base64String.isEmpty) {
      return const Icon(Icons.image_not_supported,
          color: Colors.grey, size: 18);
    }
    try {
      String clean = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
      return Image.memory(
        base64Decode(clean),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.red, size: 18),
      );
    } catch (_) {
      return const Icon(Icons.broken_image, color: Colors.red, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usedSlots = _banners.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.grey.shade700, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kelola Banner Home',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_banners.length < 3)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _addBanner,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blue.shade700))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Maksimal 3 banner aktif. Seret kartu untuk mengubah urutan tampilan di halaman home.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade800,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Slot usage bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.view_carousel_outlined,
                            color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Slot terpakai: $usedSlots / 3',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(3, (i) {
                            final used = i < usedSlots;
                            return Container(
                              width: 24,
                              height: 6,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: used
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Daftar Banner',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_banners.isEmpty)
                    _buildEmptyState()
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final moved = _banners.removeAt(oldIndex);
                        _banners.insert(newIndex, moved);
                        for (int i = 0; i < _banners.length; i++) {
                          await _bannerService.updateBanner(
                            bannerId: _banners[i].id,
                            title: _banners[i].title,
                            imageBase64: null,
                            isActive: _banners[i].isActive,
                            userId: widget.userId,
                            order: i + 1,
                          );
                        }
                        setState(() {});
                      },
                      itemCount: _banners.length,
                      itemBuilder: (context, index) {
                        final banner = _banners[index];
                        return _buildBannerCard(banner);
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildBannerCard(HomeBanner banner) {
    return Container(
      key: ValueKey(banner.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: banner.isActive ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: banner.isActive
              ? Colors.grey.shade200
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 88,
                height: 38,
                color: Colors.grey.shade100,
                child: _buildImageSafe(banner.imageBase64),
              ),
            ),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title.isEmpty ? 'Tanpa Judul' : banner.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: banner.isActive
                          ? Colors.grey.shade900
                          : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Order badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_vert_rounded,
                                size: 11, color: Colors.blue.shade700),
                            const SizedBox(width: 3),
                            Text(
                              'Urutan ${banner.order}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Active badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: banner.isActive
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: banner.isActive
                                ? Colors.green.shade200
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              banner.isActive
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              size: 7,
                              color: banner.isActive
                                  ? Colors.green.shade600
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              banner.isActive ? 'Aktif' : 'Nonaktif',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: banner.isActive
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                Row(
                  children: [
                    _actionButton(
                      icon: Icons.edit_outlined,
                      color: Colors.blue.shade700,
                      bgColor: Colors.blue.shade50,
                      onTap: () => _editBanner(banner),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 6),
                    _actionButton(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red.shade600,
                      bgColor: Colors.red.shade50,
                      onTap: () => _deleteBanner(banner.id),
                      tooltip: 'Hapus',
                    ),
                    const SizedBox(width: 6),
                    _actionButton(
                      icon: Icons.drag_handle_rounded,
                      color: Colors.grey.shade500,
                      bgColor: Colors.grey.shade100,
                      onTap: null,
                      tooltip: 'Seret untuk reorder',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.photo_library_outlined,
                  color: Colors.blue.shade700, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada banner',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tekan tombol Tambah untuk\nmenambahkan banner pertama.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}