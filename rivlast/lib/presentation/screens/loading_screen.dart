import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import 'package:rivlast/core/constants.dart';
import 'package:rivlast/core/utils.dart';
import 'package:rivlast/presentation/screens/welcome_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  Artboard? _riveArtboard;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
    _navigateToWelcome();
  }

  void _loadRiveFile() async {
    try {
      final bytes = await rootBundle.load(AppConstants.riveLoadingAsset);
      final file = RiveFile.import(bytes);
      final artboard = file.mainArtboard;

      // Try to find a state machine and add it, or just play default animation.
      // If there's a default animation, Rive widget will play it automatically.
      var controller = StateMachineController.fromArtboard(
        artboard,
        AppConstants.defaultRiveStateMachineName,
      );
      if (controller != null) {
        artboard.addController(controller);
      } else {
        print(
          'Rive State Machine "${AppConstants.defaultRiveStateMachineName}" not found for loading. Playing default animation.',
        );
      }

      setState(() {
        _riveArtboard = artboard;
      });
    } catch (e) {
      print('Error loading Rive file for loading screen: $e');
      // Fallback if Rive file fails to load
      setState(() {
        _riveArtboard = null;
      });
    }
  }

  void _navigateToWelcome() async {
    await Future.delayed(
      const Duration(seconds: 3),
    ); // Display loading for 3 seconds
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(customPageRouteBuilder(page: const WelcomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 200, // Adjust size as needed
              width: 200,
              child: _riveArtboard != null
                  ? Rive(artboard: _riveArtboard!, fit: BoxFit.contain)
                  : const CircularProgressIndicator(), // Fallback
            ),
            const SizedBox(height: 32),
            Text(
              AppConstants.loadingMessage,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
