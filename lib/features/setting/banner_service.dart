import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_banner.dart';
import 'package:flutter/material.dart';
import 'cross_platform_image_service.dart';   // <-- TAMBAHAN

class BannerService {
  final CollectionReference _bannerCollection =
      FirebaseFirestore.instance.collection('home_banner');

  // Ambil semua banner (urut berdasarkan order)
  Stream<List<HomeBanner>> streamBanners() {
    return _bannerCollection
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HomeBanner.fromFirestore(doc))
            .toList());
  }

  // Ambil hanya banner aktif untuk carousel
  Stream<List<HomeBanner>> streamActiveBanners() {
    return _bannerCollection
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HomeBanner.fromFirestore(doc))
            .toList());
  }

  // Cek jumlah banner saat ini
  Future<int> getBannerCount() async {
    final snapshot = await _bannerCollection.get();
    return snapshot.docs.length;
  }

  // Tambah banner (pastikan total < 3 sebelum panggil)
  Future<void> addBanner({
    required String title,
    required String imageBase64,
    required String userId,
    required int order,
  }) async {
    await _bannerCollection.add({
      'title': title,
      'imageBase64': imageBase64,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'order': order,
    });
  }

  // Edit banner
  Future<void> updateBanner({
    required String bannerId,
    required String title,
    required String? imageBase64,
    required bool isActive,
    required String userId,
    required int order,
  }) async {
    final updateData = {
      'title': title,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'order': order,
    };
    if (imageBase64 != null) {
      updateData['imageBase64'] = imageBase64;
    }
    await _bannerCollection.doc(bannerId).update(updateData);
  }

  // Hapus banner
  Future<void> deleteBanner(String bannerId) async {
    await _bannerCollection.doc(bannerId).delete();
  }

  // METHOD INI DIGANTI TOTAL
  static Future<String?> pickAndCropImage() async {
    return CrossPlatformImageService.pickAndCropImage();
  }
}