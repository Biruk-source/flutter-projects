import 'package:bloc/bloc.dart';
import 'package:rivlast/domain/models/user_profile.dart';
import 'package:rivlast/domain/repositories/user_repository.dart';
import 'profile_setup_event.dart';
import 'profile_setup_state.dart';

class ProfileSetupBloc extends Bloc<ProfileSetupEvent, ProfileSetupState> {
  final UserRepository _userRepository;

  ProfileSetupBloc(this._userRepository)
    : super(
        ProfileSetupState(
          userProfile: UserProfile(name: '', goal: '', interests: const []),
        ),
      ) {
    on<NameChanged>(_onNameChanged);
    on<GoalChanged>(_onGoalChanged);
    on<InterestSelected>(_onInterestSelected);
    on<SubmitProfile>(_onSubmitProfile);
  }

  void _onNameChanged(NameChanged event, Emitter<ProfileSetupState> emit) {
    final updatedProfile = state.userProfile.copyWith(name: event.name);
    emit(
      state.copyWith(
        userProfile: updatedProfile,
        isFormValid: _validateForm(updatedProfile),
      ),
    );
  }

  void _onGoalChanged(GoalChanged event, Emitter<ProfileSetupState> emit) {
    final updatedProfile = state.userProfile.copyWith(goal: event.goal);
    emit(
      state.copyWith(
        userProfile: updatedProfile,
        isFormValid: _validateForm(updatedProfile),
      ),
    );
  }

  void _onInterestSelected(
    InterestSelected event,
    Emitter<ProfileSetupState> emit,
  ) {
    final currentInterests = List<String>.from(state.userProfile.interests);
    if (event.isSelected) {
      // Allow max 3 interests
      if (currentInterests.length < 3 &&
          !currentInterests.contains(event.interest)) {
        currentInterests.add(event.interest);
      }
    } else {
      currentInterests.remove(event.interest);
    }
    final updatedProfile = state.userProfile.copyWith(
      interests: currentInterests,
    );
    emit(
      state.copyWith(
        userProfile: updatedProfile,
        isFormValid: _validateForm(updatedProfile),
        selectedInterestsCount: currentInterests.length,
      ),
    );
  }

  void _onSubmitProfile(
    SubmitProfile event,
    Emitter<ProfileSetupState> emit,
  ) async {
    if (!state.isFormValid) {
      emit(
        state.copyWith(
          errorMessage:
              'Please fill all required fields and select at least one interest.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        isSubmissionSuccess: false,
      ),
    );
    try {
      await _userRepository.submitProfile(state.userProfile);
      emit(state.copyWith(isLoading: false, isSubmissionSuccess: true));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          isSubmissionSuccess: false,
          errorMessage: e.toString().replaceFirst(
            'Exception: ',
            '',
          ), // Clean up error message
        ),
      );
    }
  }

  bool _validateForm(UserProfile profile) {
    return profile.name.isNotEmpty &&
        profile.goal.isNotEmpty &&
        profile.interests.isNotEmpty &&
        profile.interests.length >= 1 && // At least one interest
        profile.interests.length <= 3; // Max three interests
  }
}
