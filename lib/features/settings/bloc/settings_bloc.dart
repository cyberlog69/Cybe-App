import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/settings_service.dart';

abstract class SettingsEvent {}
class SettingsLoad extends SettingsEvent {}
class SettingsThemeChanged extends SettingsEvent { final String themeMode; SettingsThemeChanged(this.themeMode); }
class SettingsAutoLockChanged extends SettingsEvent { final int minutes; SettingsAutoLockChanged(this.minutes); }
class SettingsBiometricsToggled extends SettingsEvent { final bool enabled; SettingsBiometricsToggled(this.enabled); }
class SettingsClipboardTimeoutChanged extends SettingsEvent { final int seconds; SettingsClipboardTimeoutChanged(this.seconds); }
class SettingsLanguageChanged extends SettingsEvent { final String code; SettingsLanguageChanged(this.code); }

class SettingsState {
  final ThemeMode themeMode;
  final String themeModeString;
  final int autoLockMinutes;
  final bool biometricsEnabled;
  final int clipboardClearSeconds;
  final String languageCode;

  const SettingsState({
    required this.themeMode,
    required this.themeModeString,
    required this.autoLockMinutes,
    required this.biometricsEnabled,
    required this.clipboardClearSeconds,
    required this.languageCode,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? themeModeString,
    int? autoLockMinutes,
    bool? biometricsEnabled,
    int? clipboardClearSeconds,
    String? languageCode,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      themeModeString: themeModeString ?? this.themeModeString,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      clipboardClearSeconds: clipboardClearSeconds ?? this.clipboardClearSeconds,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsService _service;

  SettingsBloc({SettingsService? service})
      : _service = service ?? SettingsService(),
        super(const SettingsState(
          themeMode: ThemeMode.system,
          themeModeString: 'system',
          autoLockMinutes: 5,
          biometricsEnabled: true,
          clipboardClearSeconds: 30,
          languageCode: 'en',
        )) {
    on<SettingsLoad>(_onLoad);
    on<SettingsThemeChanged>(_onThemeChanged);
    on<SettingsAutoLockChanged>(_onAutoLockChanged);
    on<SettingsBiometricsToggled>(_onBiometricsToggled);
    on<SettingsClipboardTimeoutChanged>(_onClipboardTimeoutChanged);
    on<SettingsLanguageChanged>(_onLanguageChanged);
  }

  Future<void> _onLoad(SettingsLoad e, Emitter<SettingsState> emit) async {
    await _service.init();
    emit(SettingsState(
      themeMode: _service.getThemeMode(),
      themeModeString: _service.getThemeMode() == ThemeMode.dark ? 'dark' : _service.getThemeMode() == ThemeMode.light ? 'light' : 'system',
      autoLockMinutes: _service.getAutoLockMinutes(),
      biometricsEnabled: _service.getBiometricsEnabled(),
      clipboardClearSeconds: _service.getClipboardClearSeconds(),
      languageCode: _service.getLanguage(),
    ));
  }

  Future<void> _onThemeChanged(SettingsThemeChanged e, Emitter<SettingsState> emit) async {
    await _service.setThemeMode(e.themeMode);
    final mode = e.themeMode == 'dark' ? ThemeMode.dark : e.themeMode == 'light' ? ThemeMode.light : ThemeMode.system;
    emit(state.copyWith(themeMode: mode, themeModeString: e.themeMode));
  }

  Future<void> _onAutoLockChanged(SettingsAutoLockChanged e, Emitter<SettingsState> emit) async {
    await _service.setAutoLockMinutes(e.minutes);
    emit(state.copyWith(autoLockMinutes: e.minutes));
  }

  Future<void> _onBiometricsToggled(SettingsBiometricsToggled e, Emitter<SettingsState> emit) async {
    await _service.setBiometricsEnabled(e.enabled);
    emit(state.copyWith(biometricsEnabled: e.enabled));
  }

  Future<void> _onClipboardTimeoutChanged(SettingsClipboardTimeoutChanged e, Emitter<SettingsState> emit) async {
    await _service.setClipboardClearSeconds(e.seconds);
    emit(state.copyWith(clipboardClearSeconds: e.seconds));
  }

  Future<void> _onLanguageChanged(SettingsLanguageChanged e, Emitter<SettingsState> emit) async {
    await _service.setLanguage(e.code);
    emit(state.copyWith(languageCode: e.code));
  }
}
