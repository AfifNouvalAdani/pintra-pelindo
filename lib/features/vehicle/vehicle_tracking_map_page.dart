import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class VehicleTrackingMapPage extends StatefulWidget {
  final String bookingId;
  final String vehicleNama;
  final String vehiclePlat;
  final String namaPeminjam;
  final String divisi;
  final String tujuan;

  const VehicleTrackingMapPage({
    super.key,
    required this.bookingId,
    required this.vehicleNama,
    required this.vehiclePlat,
    required this.namaPeminjam,
    required this.divisi,
    required this.tujuan,
  });

  @override
  State<VehicleTrackingMapPage> createState() =>
      _VehicleTrackingMapPageState();
}

class _VehicleTrackingMapPageState extends State<VehicleTrackingMapPage> {
  // ── Map controller ─────────────────────────────────────────────────────────
  final MapController _mapController = MapController();

  // ── State ──────────────────────────────────────────────────────────────────
  LatLng? _currentPosition;
  double _accuracy = 0;
  DateTime? _lastUpdate;
  bool _isTracking = false;
  bool _isFirstLoad = true;
  bool _followVehicle = true;

  // Riwayat jejak pergerakan (polyline)
  final List<LatLng> _trail = [];
  static const int _maxTrailPoints = 50;

  // ── Firestore stream ───────────────────────────────────────────────────────
  StreamSubscription<DocumentSnapshot>? _trackingSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToTracking();
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    super.dispose();
  }

  // ── Subscribe realtime dari Firestore ──────────────────────────────────────
  void _subscribeToTracking() {
    _trackingSubscription = FirebaseFirestore.instance
        .collection('vehicle_tracking')
        .doc(widget.bookingId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          
          if (!snapshot.exists) {
            debugPrint('[TrackingMap] Dokumen belum ada, menunggu...');
            return;
          }

      final data = snapshot.data()!;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final accuracy = (data['accuracy'] as num?)?.toDouble() ?? 0;
      final isTracking = data['isTracking'] as bool? ?? false;
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

      if (lat == null || lng == null) return;

      final newPos = LatLng(lat, lng);

      setState(() {
        _currentPosition = newPos;
        _accuracy = accuracy;
        _lastUpdate = updatedAt;
        _isTracking = isTracking;

        // Tambah ke trail
        if (_trail.isEmpty || _trail.last != newPos) {
          _trail.add(newPos);
          if (_trail.length > _maxTrailPoints) {
            _trail.removeAt(0);
          }
        }
      });

      if (_followVehicle && mounted) {
        try {
          final zoom = _isFirstLoad ? 15.0 : _mapController.camera.zoom;
          _mapController.move(newPos, zoom);
        } catch (e) {
          debugPrint('[TrackingMap] Gagal move kamera: $e');
        }
      }

      _isFirstLoad = false;
    }, onError: (e) {
      debugPrint('[TrackingMap] Stream error: $e');
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('HH:mm:ss').format(dt);
  }

  String _timeSinceUpdate() {
    if (_lastUpdate == null) return 'Belum ada data';
    final diff = DateTime.now().difference(_lastUpdate!);
    if (diff.inSeconds < 60) return '${diff.inSeconds} detik lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    return '${diff.inHours} jam lalu';
  }

  bool get _isStale {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!).inSeconds > 30;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: Colors.grey.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.vehicleNama,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900),
            ),
            Text(
              widget.vehiclePlat,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          // Tombol follow / unfollow kamera
          IconButton(
            onPressed: () {
              setState(() => _followVehicle = !_followVehicle);
              if (_followVehicle && _currentPosition != null) {
                _mapController.move(
                    _currentPosition!, _mapController.camera.zoom);
              }
            },
            icon: Icon(
              _followVehicle
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
              color: _followVehicle
                  ? Colors.blue.shade700
                  : Colors.grey.shade500,
            ),
            tooltip:
                _followVehicle ? 'Kamera mengikuti' : 'Kamera bebas',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Status bar ───────────────────────────────────────────────
          _buildStatusBar(),

          // ── Map ──────────────────────────────────────────────────────
          Expanded(
            child: _currentPosition == null
                ? _buildWaitingState()
                : _buildMap(),
          ),

          // ── Info panel ───────────────────────────────────────────────
          _buildInfoPanel(),
        ],
      ),
    );
  }

  // ── Status Bar ─────────────────────────────────────────────────────────────
  Widget _buildStatusBar() {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (_currentPosition == null) {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
      icon = Icons.location_searching_rounded;
      label = 'Menunggu data lokasi...';
    } else if (!_isTracking || _isStale) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
      icon = Icons.signal_wifi_statusbar_connected_no_internet_4_rounded;
      label = 'Sinyal terakhir: ${_timeSinceUpdate()}';
    } else {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
      icon = Icons.location_on_rounded;
      label = 'Live • Diperbarui ${_timeSinceUpdate()}';
    }

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor),
          ),
          if (_currentPosition != null) ...[
            const Spacer(),
            Text(
              'Akurasi ±${_accuracy.toStringAsFixed(0)}m',
              style: TextStyle(fontSize: 11, color: textColor),
            ),
          ],
        ],
      ),
    );
  }

  // ── Waiting state ──────────────────────────────────────────────────────────
  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_searching_rounded,
                size: 36, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 16),
          Text(
            'Menunggu data lokasi',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            'Lokasi akan muncul saat peminjam\nmembuka aplikasi',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }

  // ── Map ────────────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition!,
        initialZoom: 15.0,
        onTap: (_, __) {
          // Saat user tap peta, nonaktifkan follow
          if (_followVehicle) {
            setState(() => _followVehicle = false);
          }
        },
      ),
      children: [
        // ── Tile layer (OpenStreetMap — gratis) ───────────────────────
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.pintra',
          maxZoom: 19,
        ),

        // ── Trail polyline ────────────────────────────────────────────
        if (_trail.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _trail,
                color: Colors.blue.shade600.withOpacity(0.6),
                strokeWidth: 3.5,
              ),
            ],
          ),

        // ── Accuracy circle ───────────────────────────────────────────
        if (_accuracy > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _currentPosition!,
                radius: _accuracy,
                useRadiusInMeter: true,
                color: Colors.blue.withOpacity(0.08),
                borderColor: Colors.blue.withOpacity(0.3),
                borderStrokeWidth: 1,
              ),
            ],
          ),

        // ── Vehicle marker ────────────────────────────────────────────
        MarkerLayer(
          markers: [
            Marker(
              point: _currentPosition!,
              width: 56,
              height: 56,
              child: _buildVehicleMarker(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVehicleMarker() {
    final isOnline = _isTracking && !_isStale;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse ring
        if (isOnline)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.15),
              border: Border.all(
                  color: Colors.blue.withOpacity(0.4), width: 1.5),
            ),
          ),
        // Icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isOnline ? Colors.blue.shade700 : Colors.grey.shade500,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.directions_car_filled,
              color: Colors.white, size: 18),
        ),
      ],
    );
  }

  // ── Info panel ─────────────────────────────────────────────────────────────
  Widget _buildInfoPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: peminjam info
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline,
                    color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.namaPeminjam,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900),
                    ),
                    Text(
                      widget.divisi,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              // Koordinat
              if (_currentPosition != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currentPosition!.latitude
                            .toStringAsFixed(5),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700),
                      ),
                      Text(
                        _currentPosition!.longitude
                            .toStringAsFixed(5),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 12),

          // Row 2: tujuan
          Row(
            children: [
              Icon(Icons.place_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.tujuan,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 3: update time
          Row(
            children: [
              Icon(Icons.update_rounded,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                _lastUpdate != null
                    ? 'Update terakhir: ${_fmtTime(_lastUpdate)}'
                    : 'Belum ada data lokasi',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}