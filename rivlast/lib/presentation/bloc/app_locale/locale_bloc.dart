import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rivlast/presentation/bloc/app_locale/locale_event.dart'; // Correct import for events
import 'package:rivlast/presentation/bloc/app_locale/locale_state.dart'; // Correct import for state

class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  // Fixed: LocaleEvent now found via import
  LocaleBloc() : super(const LocaleState(locale: Locale('en'))) {
    on<LoadLocale>(_onLoadLocale); // Fixed: LoadLocale now found via import
    on<ChangeLocale>(
      _onChangeLocale,
    ); // Fixed: ChangeLocale now found via import
  }

  Future<void> _onLoadLocale(
    LoadLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('languageCode') ?? 'en';
    emit(LocaleState(locale: Locale(langCode)));
  }

  Future<void> _onChangeLocale(
    ChangeLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', event.locale.languageCode);
    emit(LocaleState(locale: event.locale));
  }
}
