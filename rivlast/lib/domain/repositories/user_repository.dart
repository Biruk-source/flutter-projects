import 'package:rivlast/data/fake_api_service.dart';
import 'package:rivlast/domain/models/user_profile.dart';

class UserRepository {
  final FakeApiService _apiService;

  UserRepository(this._apiService);

  Future<void> submitProfile(UserProfile profile) async {
    try {
      await _apiService.submitUserProfile(profile);
    } catch (e) {
      // Re-throw a more specific error or just the original one
      throw Exception('Failed to submit user profile: ${e.toString()}');
    }
  }
}
