import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';

class Restaurant {
  final String id;
  final String name;
  final String imageUrl;
  final String description;
  final double rating;
  final String address;
  final String cuisine;
  final bool isOpen;
  final List<String> categories;
  final List<FoodItem> menu;
  final int deliveryTime;
  final bool isPromoted;
  final double latitude;
  final double longitude;
  final GeoPoint? location;
  final bool isFavorite;
  final int totalOrders;
  final int pendingOrders;
  final DateTime? lastOrderTime;
  final Map<String, dynamic>? operatingHours;
  final double minOrderAmount;
  final double deliveryFee;
  final String phoneNumber;
  final String email;
  final bool isActive;

  Restaurant({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.description,
    required this.rating,
    required this.address,
    required this.cuisine,
    required this.isOpen,
    required this.categories,
    required this.menu,
    required this.deliveryTime,
    required this.isPromoted,
    required this.latitude,
    required this.longitude,
    required this.isFavorite,
    this.location,
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.lastOrderTime,
    this.operatingHours,
    this.minOrderAmount = 0.0,
    this.deliveryFee = 0.0,
    this.phoneNumber = '',
    this.email = '',
    this.isActive = true,
  });

  factory Restaurant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final GeoPoint? geoPoint = data['location'] as GeoPoint?;

    return Restaurant(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      address: data['address'] ?? '',
      cuisine: data['cuisine'] ?? '',
      isOpen: data['isOpen'] ?? false,
      categories: List<String>.from(data['categories'] ?? []),
      menu: (data['menu'] as List<dynamic>?)
              ?.map((item) => FoodItem.fromMap({...item as Map<String, dynamic>, 'restaurantId': doc.id}))
              .toList() ??
          [],
      deliveryTime: data['deliveryTime'] ?? 30,
      isPromoted: data['isPromoted'] ?? false,
      latitude: geoPoint?.latitude ?? (data['latitude'] ?? 0.0).toDouble(),
      longitude: geoPoint?.longitude ?? (data['longitude'] ?? 0.0).toDouble(),
      location: geoPoint,
      isFavorite: data['isFavorite'] ?? false,
      totalOrders: data['totalOrders'] ?? 0,
      pendingOrders: data['pendingOrders'] ?? 0,
      lastOrderTime: data['lastOrderTime']?.toDate(),
      operatingHours: data['operatingHours'] as Map<String, dynamic>?,
      minOrderAmount: (data['minOrderAmount'] ?? 0.0).toDouble(),
      deliveryFee: (data['deliveryFee'] ?? 0.0).toDouble(),
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'description': description,
      'rating': rating,
      'address': address,
      'cuisine': cuisine,
      'isOpen': isOpen,
      'categories': categories,
      'menu': menu.map((item) => item.toMap()).toList(),
      'deliveryTime': deliveryTime,
      'isPromoted': isPromoted,
      'latitude': latitude,
      'longitude': longitude,
      'location': location ?? GeoPoint(latitude, longitude),
      'isFavorite': isFavorite,
      'totalOrders': totalOrders,
      'pendingOrders': pendingOrders,
      'lastOrderTime': lastOrderTime,
      'operatingHours': operatingHours,
      'minOrderAmount': minOrderAmount,
      'deliveryFee': deliveryFee,
      'phoneNumber': phoneNumber,
      'email': email,
      'isActive': isActive,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  Restaurant copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? description,
    double? rating,
    String? address,
    String? cuisine,
    bool? isOpen,
    List<String>? categories,
    List<FoodItem>? menu,
    int? deliveryTime,
    bool? isPromoted,
    double? latitude,
    double? longitude,
    GeoPoint? location,
    bool? isFavorite,
    int? totalOrders,
    int? pendingOrders,
    DateTime? lastOrderTime,
    Map<String, dynamic>? operatingHours,
    double? minOrderAmount,
    double? deliveryFee,
    String? phoneNumber,
    String? email,
    bool? isActive,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      address: address ?? this.address,
      cuisine: cuisine ?? this.cuisine,
      isOpen: isOpen ?? this.isOpen,
      categories: categories ?? this.categories,
      menu: menu ?? this.menu,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      isPromoted: isPromoted ?? this.isPromoted,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      location: location ?? this.location,
      isFavorite: isFavorite ?? this.isFavorite,
      totalOrders: totalOrders ?? this.totalOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      lastOrderTime: lastOrderTime ?? this.lastOrderTime,
      operatingHours: operatingHours ?? this.operatingHours,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
    );
  }
}
