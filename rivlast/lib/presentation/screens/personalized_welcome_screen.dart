import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import 'package:rivlast/core/constants.dart';
import 'package:rivlast/core/utils.dart';
import 'package:rivlast/presentation/screens/welcome_screen.dart';

class PersonalizedWelcomeScreen extends StatefulWidget {
  final String userName;
  final String userGoal;

  const PersonalizedWelcomeScreen({
    super.key,
    required this.userName,
    required this.userGoal,
  });

  @override
  State<PersonalizedWelcomeScreen> createState() =>
      _PersonalizedWelcomeScreenState();
}

class _PersonalizedWelcomeScreenState extends State<PersonalizedWelcomeScreen> {
  Artboard? _riveArtboard;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  void _loadRiveFile() async {
    try {
      final bytes = await rootBundle.load(
        AppConstants.rivePersonalizedWelcomeAsset,
      );
      final file = RiveFile.import(bytes);
      final artboard = file.mainArtboard;

      // Try to find a state machine and add it, or just play default animation.
      var controller = StateMachineController.fromArtboard(
        artboard,
        AppConstants.defaultRiveStateMachineName,
      );
      if (controller != null) {
        artboard.addController(controller);
      } else {
        print(
          'Rive State Machine "${AppConstants.defaultRiveStateMachineName}" not found for personalized welcome. Playing default animation.',
        );
      }

      setState(() {
        _riveArtboard = artboard;
      });
    } catch (e) {
      print('Error loading Rive file for personalized welcome screen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome!'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                child: _riveArtboard != null
                    ? Rive(artboard: _riveArtboard!, fit: BoxFit.contain)
                    : const CircularProgressIndicator(),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome, ${widget.userName}!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We\'re excited to help you on your journey to "${widget.userGoal}"!',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    customPageRouteBuilder(page: const WelcomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Start Over'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
