import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String name;
  final String goal;
  final List<String> interests;

  const UserProfile({
    required this.name,
    required this.goal,
    required this.interests,
  });

  // Method to create a new UserProfile instance with updated values
  UserProfile copyWith({String? name, String? goal, List<String>? interests}) {
    return UserProfile(
      name: name ?? this.name,
      goal: goal ?? this.goal,
      interests: interests ?? this.interests,
    );
  }

  // Equatable for value comparison in BLoC states
  @override
  List<Object?> get props => [name, goal, interests];
}
