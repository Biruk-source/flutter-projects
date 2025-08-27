import 'package:equatable/equatable.dart';

abstract class ProfileSetupEvent extends Equatable {
  const ProfileSetupEvent();

  @override
  List<Object> get props => [];
}

class NameChanged extends ProfileSetupEvent {
  final String name;
  const NameChanged(this.name);
  @override
  List<Object> get props => [name];
}

class GoalChanged extends ProfileSetupEvent {
  final String goal;
  const GoalChanged(this.goal);
  @override
  List<Object> get props => [goal];
}

class InterestSelected extends ProfileSetupEvent {
  final String interest;
  final bool isSelected;
  const InterestSelected(this.interest, this.isSelected);
  @override
  List<Object> get props => [interest, isSelected];
}

class SubmitProfile extends ProfileSetupEvent {
  const SubmitProfile();
}
