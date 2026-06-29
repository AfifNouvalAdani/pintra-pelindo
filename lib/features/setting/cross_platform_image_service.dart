import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

class CrossPlatformImageService {
  /// Memilih gambar dari galeri, crop ke rasio 21:9 (ambil tengah),
  /// resize max width 1200px, kompres ke JPG quality 80, return base64.
  static Future<String?> pickAndCropImage() async {
    // 1. Pilih file gambar
    Uint8List? fileBytes;
    if (kIsWeb) {
      // Web: file_picker langsung beri bytes
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      fileBytes = result.files.first.bytes;
      if (fileBytes == null) return null;
    } else {
      // Mobile/Desktop: pakai file_picker (atau image_picker, tapi file_picker lebih konsisten)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        // fallback: baca dari File
        final file = File(result.files.first.path!);
        fileBytes = await file.readAsBytes();
      }
    }

    if (fileBytes == null) return null;

    // 2. Decode gambar
    img.Image? original = img.decodeImage(fileBytes);
    if (original == null) return null;

    // 3. Crop ke rasio 21:9 (ambil area tengah)
    final targetRatio = 21 / 9; // ≈ 2.333
    final originalWidth = original.width;
    final originalHeight = original.height;
    final originalRatio = originalWidth / originalHeight;

    int cropX = 0, cropY = 0, cropWidth = originalWidth, cropHeight = originalHeight;

    if (originalRatio > targetRatio) {
      // Terlalu lebar: potong horizontal
      cropWidth = (originalHeight * targetRatio).round();
      cropX = (originalWidth - cropWidth) ~/ 2;
    } else {
      // Terlalu tinggi: potong vertikal
      cropHeight = (originalWidth / targetRatio).round();
      cropY = (originalHeight - cropHeight) ~/ 2;
    }

    img.Image cropped = img.copyCrop(original, x: cropX, y: cropY, width: cropWidth, height: cropHeight);

    // 4. Resize jika lebar > 1200
    int targetWidth = cropped.width;
    if (targetWidth > 1200) {
      targetWidth = 1200;
      // tinggi otomatis mengikuti rasio 21:9
    }
    img.Image resized = img.copyResize(cropped, width: targetWidth);

    // 5. Kompres ke JPG kualitas 80
    Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));

    // 6. Jika masih > 1MB, turunkan kualitas
    if (compressedBytes.length > 1024 * 1024) {
      // coba kualitas 60
      compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 60));
    }

    // 7. Encode ke base64
    return base64Encode(compressedBytes);
  }
}