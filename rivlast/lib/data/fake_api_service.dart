import 'dart:async';
import 'package:rivlast/domain/models/user_profile.dart';

class FakeApiService {
  Future<bool> submitUserProfile(UserProfile profile) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Simulate success or failure based on input for testing
    if (profile.name.toLowerCase().contains('error') ||
        profile.goal.toLowerCase().contains('fail')) {
      throw Exception('Simulated network error during submission.');
    }

    print(
      'DEBUG: Profile submitted to fake server: ${profile.name}, Goal: ${profile.goal}, Interests: ${profile.interests}',
    );
    return true;
  }
}
