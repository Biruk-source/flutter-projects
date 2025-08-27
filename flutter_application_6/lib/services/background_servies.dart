import 'dart:async';
import 'dart:io'; 
import 'package:flutter/services.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart'; 
import '../firebase_options.dart';

class BackgroundService extends ChangeNotifier {
  String? _activeOrderId;
  String? _restaurantId;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;
  Timer? _locationTimer;
  StreamSubscription<Position>? _locationSubscription;
  bool _isServiceRunning = false;

  Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();


  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'location_tracking',
      initialNotificationTitle: 'GB Delivery Tracking',
      initialNotificationContent: 'Preparing to track your order...',
      foregroundServiceNotificationId: 888,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

    // Request battery optimization exemption
   // Request battery optimization exemption (Android only)
  if (Platform.isAndroid) {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final androidInfo = await deviceInfoPlugin.androidInfo;

    if (androidInfo.version.sdkInt >= 23) {
      const platform = MethodChannel('background_service/power_manager');
      final bool? isIgnoringBatteryOptimizations = await platform.invokeMethod('isIgnoringBatteryOptimizations');

      if (isIgnoringBatteryOptimizations == false) {
        await platform.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    }
  }
  }

  Future<void> startService() async {
    if (_isServiceRunning) return;

    final service = FlutterBackgroundService();
    await service.startService();
    _isServiceRunning = true;

    // Ensure foreground mode is active
    if (Platform.isAndroid) {
      service.invoke('setAsForeground');
    }

    // Start periodic health check
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!_isServiceRunning) {
        timer.cancel();
        return;
      }

      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
        service.invoke('setAsForeground');
      }
    });
  }


 @pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Set as foreground immediately
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'GB Delivery Active',
        content: 'Tracking your order location',
      );
    }

      service.on('setAsForeground').listen((event) {
        if (service is AndroidServiceInstance) {
          service.setAsForegroundService();
        }
      });

      service.on('setAsBackground').listen((event) {
        if (service is AndroidServiceInstance) {
          service.setAsBackgroundService();
        }
      });

      service.on('stopService').listen((event) async {
        _locationTimer?.cancel();
        _locationSubscription?.cancel();
        _activeOrderId = null;
        _restaurantId = null;
        await service.stopSelf();
      });

      service.on('startTracking').listen((event) async {
        final orderId = event?['orderId'] as String?;
        final restaurantId = event?['restaurantId'] as String?;
        if (orderId == null || restaurantId == null) return;

        _activeOrderId = orderId;
        _restaurantId = restaurantId;

        try {
          final auth = FirebaseAuth.instance;
          final user = auth.currentUser;
          if (user == null) {
            debugPrint('No authenticated user found');
            return;
          }

          // Request high accuracy location permission
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.deniedForever) {
            debugPrint('Location permissions permanently denied');
            return;
          }

          // Configure location settings for high accuracy and updates every meter
          const locationSettings = LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1, // Update every 1 meter
          );

          // Create a timer for 1-second updates
          _locationTimer?.cancel();
          _locationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
            try {
              final position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );
              
              if (position != null && _activeOrderId != null) {
                // Check if we should update based on distance and time
                bool shouldUpdate = true;
                if (_lastPosition != null && _lastUpdateTime != null) {
                  final distance = Geolocator.distanceBetween(
                    _lastPosition!.latitude,
                    _lastPosition!.longitude,
                    position.latitude,
                    position.longitude,
                  );
                  final timeDiff = DateTime.now().difference(_lastUpdateTime!).inSeconds;
                  
                  // Only update if moved more than 1 meter or 1 second has passed
                  shouldUpdate = distance >= 1.0 || timeDiff >= 1;
                }

                if (shouldUpdate) {
                  _lastPosition = position;
                  _lastUpdateTime = DateTime.now();

                  final firestore = FirebaseFirestore.instance;
                  
                  // Update location in Firestore with timestamp
                  await firestore.collection('orders').doc(_activeOrderId).update({
                    'currentLocation': GeoPoint(position.latitude, position.longitude),
                    'lastUpdated': FieldValue.serverTimestamp(),
                    'speed': position.speed,
                    'heading': position.heading,
                    'accuracy': position.accuracy,
                    'timestamp': DateTime.now().toIso8601String(),
                    'distanceMoved': _lastPosition != null ? Geolocator.distanceBetween(
                      _lastPosition!.latitude,
                      _lastPosition!.longitude,
                      position.latitude,
                      position.longitude,
                    ) : 0.0,
                  });

                  // Update notification
                  if (service is AndroidServiceInstance) {
                    service.setForegroundNotificationInfo(
                      title: 'Tracking Order: $_activeOrderId',
                      content: 'Speed: ${(position.speed * 3.6).toStringAsFixed(1)} km/h\n'
                          'Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                    );
                  }
                }
              }
            } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
    return;
  }
});

          // Start listening to position stream for continuous updates
          _locationSubscription?.cancel();
          _locationSubscription = Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position? position) {
              if (position != null) {
                _lastPosition = position;
              }
            },
            onError: (error) => debugPrint('Location stream error: $error'),
          );
        } catch (e) {
          debugPrint('Error starting location tracking: $e');
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
      return;
    }

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }
  }

  @pragma('vm:entry-point')
  Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }
}