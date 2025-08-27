import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rivlast/core/constants.dart';
import 'package:rivlast/core/theme.dart';
import 'package:rivlast/data/fake_api_service.dart';
import 'package:rivlast/domain/repositories/user_repository.dart';
import 'package:rivlast/presentation/bloc/profile_setup/profile_setup_bloc.dart';
import 'package:rivlast/presentation/screens/loading_screen.dart'; // NEW import

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FakeApiService>(
          create: (context) => FakeApiService(),
        ),
        RepositoryProvider<UserRepository>(
          create: (context) => UserRepository(context.read<FakeApiService>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ProfileSetupBloc>(
            create: (context) =>
                ProfileSetupBloc(context.read<UserRepository>()),
          ),
        ],
        child: MaterialApp(
          title: AppConstants.appTitle,
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: const LoadingScreen(), // Start with the new LoadingScreen
        ),
      ),
    );
  }
}
