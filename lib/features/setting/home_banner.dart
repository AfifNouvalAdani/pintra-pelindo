import 'package:cloud_firestore/cloud_firestore.dart';

class HomeBanner {
  final String id;
  final String title;
  final String imageBase64;
  final bool isActive;
  final DateTime updatedAt;
  final String updatedBy;
  final int order;

  HomeBanner({
    required this.id,
    required this.title,
    required this.imageBase64,
    required this.isActive,
    required this.updatedAt,
    required this.updatedBy,
    required this.order,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageBase64': imageBase64,
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
      'order': order,
    };
  }

  factory HomeBanner.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Validasi Timestamp yang aman (Cegah crash jika null)
    DateTime parsedDate = DateTime.now(); 
    if (data['updatedAt'] != null && data['updatedAt'] is Timestamp) {
      parsedDate = (data['updatedAt'] as Timestamp).toDate();
    }

    return HomeBanner(
      id: doc.id,
      title: data['title']?.toString() ?? 'Tanpa Judul',
      imageBase64: data['imageBase64']?.toString() ?? '',
      isActive: data['isActive'] as bool? ?? false,
      updatedAt: parsedDate,
      updatedBy: data['updatedBy']?.toString() ?? '',
      order: data['order'] as int? ?? 0,
    );
  }
}