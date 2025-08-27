import 'package:equatable/equatable.dart';
import 'package:rivlast/domain/models/user_profile.dart';

class ProfileSetupState extends Equatable {
  final UserProfile userProfile;
  final bool isLoading;
  final bool isSubmissionSuccess;
  final String? errorMessage;
  final bool isFormValid;
  final int selectedInterestsCount;

  const ProfileSetupState({
    required this.userProfile,
    this.isLoading = false,
    this.isSubmissionSuccess = false,
    this.errorMessage,
    this.isFormValid = false,
    this.selectedInterestsCount = 0,
  });

  ProfileSetupState copyWith({
    UserProfile? userProfile,
    bool? isLoading,
    bool? isSubmissionSuccess,
    String? errorMessage,
    bool? isFormValid,
    int? selectedInterestsCount,
  }) {
    return ProfileSetupState(
      userProfile: userProfile ?? this.userProfile,
      isLoading: isLoading ?? this.isLoading,
      isSubmissionSuccess: isSubmissionSuccess ?? this.isSubmissionSuccess,
      errorMessage: errorMessage, // Nullable string, allow explicit null
      isFormValid: isFormValid ?? this.isFormValid,
      selectedInterestsCount:
          selectedInterestsCount ?? this.selectedInterestsCount,
    );
  }

  @override
  List<Object?> get props => [
    userProfile,
    isLoading,
    isSubmissionSuccess,
    errorMessage,
    isFormValid,
    selectedInterestsCount,
  ];
}
