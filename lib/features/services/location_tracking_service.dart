import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  Timer? _timer;
  String? _activeBookingId;
  bool _isTracking = false;

  bool get isTracking => _isTracking;
  String? get activeBookingId => _activeBookingId;

  Future<void> startTracking({
    required String bookingId,
    required String vehicleNama,
    required String vehiclePlat,
    required String namaPeminjam,
  }) async {
    if (_isTracking && _activeBookingId == bookingId) return;
    await stopTracking();

    if (kIsWeb) {
      await _startWebTracking(
        bookingId: bookingId,
        vehicleNama: vehicleNama,
        vehiclePlat: vehiclePlat,
        namaPeminjam: namaPeminjam,
      );
      return;
    }

    // Native (Android/iOS)
    final hasPermission = await _requestPermission();
    if (!hasPermission) return;

    _activeBookingId = bookingId;
    _isTracking = true;

    await _sendLocationNative(
      bookingId: bookingId,
      vehicleNama: vehicleNama,
      vehiclePlat: vehiclePlat,
      namaPeminjam: namaPeminjam,
    );

    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _sendLocationNative(
        bookingId: bookingId,
        vehicleNama: vehicleNama,
        vehiclePlat: vehiclePlat,
        namaPeminjam: namaPeminjam,
      );
    });
  }

  // ── Web: pakai Geolocator (sudah support web, tanpa dart:js) ──────────────
  Future<Map<String, double>?> _getWebPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'acc': position.accuracy,
      };
    } catch (e) {
      debugPrint('[Tracking Web] Gagal dapat lokasi: $e');
      return null;
    }
  }

  Future<void> _startWebTracking({
    required String bookingId,
    required String vehicleNama,
    required String vehiclePlat,
    required String namaPeminjam,
  }) async {
    final pos = await _getWebPosition();
    if (pos == null) return;

    debugPrint('[Tracking Web] Lokasi pertama: ${pos['lat']}, ${pos['lng']}');

    await _sendToFirestore(
      bookingId: bookingId,
      vehicleNama: vehicleNama,
      vehiclePlat: vehiclePlat,
      namaPeminjam: namaPeminjam,
      lat: pos['lat']!,
      lng: pos['lng']!,
      accuracy: pos['acc']!,
    );

    _activeBookingId = bookingId;
    _isTracking = true;

    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _sendLocationWeb(
        bookingId: bookingId,
        vehicleNama: vehicleNama,
        vehiclePlat: vehiclePlat,
        namaPeminjam: namaPeminjam,
      );
    });
  }

  Future<void> _sendLocationWeb({
    required String bookingId,
    required String vehicleNama,
    required String vehiclePlat,
    required String namaPeminjam,
  }) async {
    final pos = await _getWebPosition();
    if (pos == null) return;

    await _sendToFirestore(
      bookingId: bookingId,
      vehicleNama: vehicleNama,
      vehiclePlat: vehiclePlat,
      namaPeminjam: namaPeminjam,
      lat: pos['lat']!,
      lng: pos['lng']!,
      accuracy: pos['acc']!,
    );
  }

  // ── Kirim ke Firestore ─────────────────────────────────────────────────────
  Future<void> _sendToFirestore({
    required String bookingId,
    required String vehicleNama,
    required String vehiclePlat,
    required String namaPeminjam,
    required double lat,
    required double lng,
    required double accuracy,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('vehicle_tracking')
          .doc(bookingId)
          .set({
        'bookingId': bookingId,
        'vehicleNama': vehicleNama,
        'vehiclePlat': vehiclePlat,
        'namaPeminjam': namaPeminjam,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'updatedAt': Timestamp.now(),
        'isTracking': true,
      }, SetOptions(merge: true));

      debugPrint('[Tracking] Lokasi terkirim: $lat, $lng');
    } catch (e) {
      debugPrint('[Tracking] Gagal kirim Firestore: $e');
    }
  }

  // ── Native (Android/iOS) ───────────────────────────────────────────────────
  Future<void> _sendLocationNative({
    required String bookingId,
    required String vehicleNama,
    required String vehiclePlat,
    required String namaPeminjam,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await _sendToFirestore(
        bookingId: bookingId,
        vehicleNama: vehicleNama,
        vehiclePlat: vehiclePlat,
        namaPeminjam: namaPeminjam,
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      debugPrint('[Tracking] Gagal kirim lokasi native: $e');
    }
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _timer?.cancel();
    _timer = null;

    if (_activeBookingId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('vehicle_tracking')
            .doc(_activeBookingId)
            .update({
          'isTracking': false,
          'updatedAt': Timestamp.now(),
        });
      } catch (e) {
        debugPrint('[Tracking] Gagal update isTracking=false: $e');
      }
    }

    _isTracking = false;
    _activeBookingId = null;
  }

  Future<bool> _requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}