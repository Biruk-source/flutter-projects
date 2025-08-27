// @dart=2.17
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/restaurant.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../widgets/glassmorphic_button.dart';
import 'package:intl/intl.dart';
import '../services/background_servies.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class OrdersScreen extends StatefulWidget {
  static const routeName = '/orders';
  final Restaurant restaurant;
  final List<CartItem> cartItems;
  final double totalPrice;

  const OrdersScreen({
    super.key,
    required this.restaurant,
    required this.cartItems,
    required this.totalPrice,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isProcessing = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final List<String> _paymentMethods = ['cash', 'card'];
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  Position? _currentPosition;
  bool _notificationsInitialized = false;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  String _currentTime = '';
  String _orderStartTime = '';
  String? _currentOrderId;

  bool _isLocationEnabled = false;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _timeUpdateTimer;
  Timer? _locationTimer;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;
  int _eta = 0;
  String notes = '';
  double _totalDistance = 0;
  double _averageSpeed = 0;
  String _deliveryStatus = '';
  int _stopCount = 0;
  String _trafficCondition = '';

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _setupOrderTracking();
    _startTimeUpdateTimer();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentOrderId = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
      _orderStartTime = DateTime.now().toIso8601String();
    }
  }

  void _startTimeUpdateTimer() {
    _currentTime = DateTime.now().toIso8601String();
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now().toIso8601String();
        });
      }
    });
  }

  void _showErrorNotification(String message) {
    _notifications.show(
      0,
      'Location Error',
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'food will be delivered waiting for acceptance',
          'GB delivery',
          importance: Importance.high,
        ),
      ),
    );
  }

  Future<void> _startLocationTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _isLocationEnabled = true;

        // Configure location settings for high accuracy and updates every meter
        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1, // Update every 1 meter
        );

        // Create a timer for 1-second updates
        Timer.periodic(const Duration(seconds: 1), (timer) async {
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );

            if (position != null && _currentOrderId != null) {
              // Check if we should update based on distance and time
              bool shouldUpdate = true;
              if (_lastPosition != null && _lastUpdateTime != null) {
                final distance = Geolocator.distanceBetween(
                  _lastPosition!.latitude,
                  _lastPosition!.longitude,
                  position.latitude,
                  position.longitude,
                );
                final timeDiff =
                    DateTime.now().difference(_lastUpdateTime!).inSeconds;

                // Only update if moved more than 1 meter or 1 second has passed
                shouldUpdate = distance >= 1.0 || timeDiff >= 1;
              }

              if (shouldUpdate) {
                if (mounted) {
                  setState(() {
                    _currentPosition = position;
                    _lastPosition = position;
                    _lastUpdateTime = DateTime.now();

                    // Update map markers
                    _markers.clear();
                    _markers.add(
                      Marker(
                        markerId: const MarkerId('current_location'),
                        position: LatLng(position.latitude, position.longitude),
                        infoWindow: InfoWindow(
                          title: 'Current Location',
                          snippet:
                              'Updated: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                        ),
                      ),
                    );

                    // Update map camera position
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(
                          LatLng(position.latitude, position.longitude)),
                    );
                  });
                }

                // Update location in Firestore with timestamp
                await _firestore
                    .collection('orders')
                    .doc(_currentOrderId)
                    .update({
                  'currentLocation':
                      GeoPoint(position.latitude, position.longitude),
                  'lastUpdated': FieldValue.serverTimestamp(),
                  'speed': position.speed,
                  'heading': position.heading,
                  'accuracy': position.accuracy,
                  'timestamp': DateTime.now().toIso8601String(),
                  'distanceMoved': _lastPosition != null
                      ? Geolocator.distanceBetween(
                          _lastPosition!.latitude,
                          _lastPosition!.longitude,
                          position.latitude,
                          position.longitude,
                        )
                      : 0.0,
                });
              }
            }
          } catch (e) {
            print('Error updating location: $e');
          }
        });

        // Start listening to position stream for continuous updates
        _locationSubscription?.cancel(); // Cancel any existing subscription
        _locationSubscription = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          (Position? position) async {
            if (position != null && _currentOrderId != null) {
              // Handle continuous position updates
              if (mounted) {
                setState(() {
                  _currentPosition = position;
                });
              }
            }
          },
          onError: (error) {
            print('Location tracking error: $error');
            _showErrorNotification('Location tracking error occurred');
          },
        );
      }
    } catch (e) {
      print('Error starting location tracking: $e');
      _showErrorNotification('Failed to start location tracking');
    }
  }

  void _setupOrderTracking() {
    if (_currentOrderId != null) {
      // Listen to main order updates
      FirebaseFirestore.instance
          .collection('orders')
          .doc(_currentOrderId)
          .snapshots()
          .listen((snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        setState(() {
          // Update delivery metadata
          final deliveryMetadata =
              data['deliveryMetadata'] as Map<String, dynamic>?;
          if (deliveryMetadata != null) {
            _eta = deliveryMetadata['estimatedTimeRemaining'] ?? 0;
            _totalDistance =
                (deliveryMetadata['actualDistance'] ?? 0).toDouble();
            _averageSpeed = (deliveryMetadata['averageSpeed'] ?? 0).toDouble();
            _deliveryStatus = deliveryMetadata['deliveryStatus'] ?? '';
          }

          // Update analytics
          final analytics = data['deliveryAnalytics'] as Map<String, dynamic>?;
          if (analytics != null) {
            _stopCount = analytics['totalStops'] ?? 0;
            _trafficCondition = analytics['trafficCondition'] ?? '';
          }

          notes = data['notes'] ?? '';

          // Check if order is complete
          if (data['status'] == 'delivered' || data['status'] == 'cancelled') {
            _stopTracking();
          }
        });
      });

      // Listen to real-time location updates
      FirebaseFirestore.instance
          .collection('location_updates')
          .where('orderId', isEqualTo: _currentOrderId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isEmpty) return;

        final update = snapshot.docs.first.data();
        final location = update['location'] as GeoPoint;
        setState(() {
          _lastPosition = Position(
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: DateTime.now(),
            accuracy: update['accuracy'] ?? 0.0,
            altitude: 0.0,
            heading: update['heading'] ?? 0.0,
            speed: update['speed'] ?? 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );

          // Update real-time stats
          _averageSpeed = (update['speed'] ?? 0).toDouble();
          if (update['distanceMoved'] != null) {
            _totalDistance += update['distanceMoved'];
          }
        });
      });
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds sec';
    if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      return '$minutes min';
    }
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    return '${hours}h ${minutes}m';
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to place an order')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      final firestore = FirebaseFirestore.instance;
      final orderTime = DateTime.now().toIso8601String();

      // Enhanced order data
      final orderData = {
        'userId': user.uid,
        'restaurantId': widget.restaurant.id,
        'items': widget.cartItems
            .map((item) => {
                  'name': item.name,
                  'price': item.price,
                  'quantity': item.quantity,
                })
            .toList(),
        'customerInfo': {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'address': _addressController.text,
          'dorm': _cityController.text,
          'notes': _notesController.text,
        },
        'paymentMethod': _paymentMethod,
        'totalPrice': widget.totalPrice,
        'status': 'pending',
        'orderTime': orderTime,
        'notes': _notesController.text,
        'initialLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'speed': position.speed * 3.6,
          'heading': position.heading,
          'timestamp': orderTime,
        },
        'tracking': {
          'isActive': true,
          'lastUpdate': orderTime,
          'batteryLevel': 100, // Add battery monitoring later
        },
        'locationHistory': [],
        'deliveryMetadata': {
          'estimatedDistance': 0,
          'estimatedDuration': 0,
          'actualDistance': 0,
          'actualDuration': 0,
          'averageSpeed': 0,
          'estimatedTimeRemaining': 0,
        },
        'deviceInfo': {
          'platform': 'android',
          'appVersion': '1.0.0',
        },
      };

      final orderRef = await firestore.collection('orders').add(orderData);
      _currentOrderId = orderRef.id;

      // Start background tracking service
      final service = FlutterBackgroundService();
      await service.startService();
      service.invoke('startTracking', {
        'orderId': _currentOrderId,
        'restaurantId': widget.restaurant.id,
      });

      _setupOrderTracking();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _stopTracking() {
    _locationSubscription?.cancel();
    _timeUpdateTimer?.cancel();
    FlutterBackgroundService().invoke('stopService');
  }

  @override
  void dispose() {
    _stopTracking();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Checkout - ${widget.restaurant.name}',
          style: const TextStyle(fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Order Status Card (only show if order is placed)
            if (_currentOrderId != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status: $_deliveryStatus'),
                          Text('ETA: ${_formatDuration(_eta)}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Distance: ${_totalDistance.toStringAsFixed(1)} m'),
                          Text(
                              'Speed: ${_averageSpeed.toStringAsFixed(1)} km/h'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stops: $_stopCount'),
                          Text('Traffic: $_trafficCondition'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Restaurant Info
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restaurant Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.restaurant.imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(widget.restaurant.name),
                      subtitle: Text(widget.restaurant.address),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Order Summary
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    ...widget.cartItems.map((item) => ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(item.name),
                          subtitle: Text('Quantity: ${item.quantity}'),
                          trailing: Text(
                            '${(item.price * item.quantity).toStringAsFixed(2)}',
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount:'),
                        Text(
                          '${widget.totalPrice.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Personal Information
            Text(
              'Personal Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) => value?.isEmpty ?? true
                  ? 'Please enter your phone number'
                  : null,
            ),
            const SizedBox(height: 24),

            // Delivery Information
            Text(
              'Delivery Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true
                  ? 'Please enter your delivery address'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Dorm',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter your dorm' : null,
            ),
            const SizedBox(height: 24),

            // Special Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Special Notes',
                border: OutlineInputBorder(),
                hintText: 'Any special delivery instructions?',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Payment Method

            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  items: _paymentMethods.map((method) {
                    return DropdownMenuItem<String>(
                      value: method,
                      child: Text(method == 'cash'
                          ? 'Cash on Delivery'
                          : 'Credit/Debit Card'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _paymentMethod = value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: GlassmorphicButton(
                onPressed: _isProcessing ? () {} : () => _placeOrder(),
                child: _isProcessing
                    ? const CircularProgressIndicator(
                        color: Color.fromARGB(255, 164, 255, 8),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(
                          color: Color.fromARGB(255, 191, 255, 112),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
