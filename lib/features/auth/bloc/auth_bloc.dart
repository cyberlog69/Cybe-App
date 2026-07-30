import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:equatable/equatable.dart';
import 'dart:convert';
import 'package:cybe_app/core/constants/app_constants.dart';
import 'package:cybe_app/core/utils/crypto_utils.dart';
import 'package:cybe_app/features/security_logs/services/security_log_service.dart';

// ─── Events ────────────────────────────────────────────────────────────────
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}
class AuthCheckStatus extends AuthEvent {}
class AuthSetupMasterPassword extends AuthEvent {
  final String password;
  AuthSetupMasterPassword(this.password);
  @override
  List<Object?> get props => [password];
}
class AuthUnlockWithPassword extends AuthEvent {
  final String password;
  AuthUnlockWithPassword(this.password);
  @override
  List<Object?> get props => [password];
}
class AuthUnlockWithBiometrics extends AuthEvent {}
class AuthLockApp extends AuthEvent {}

// ─── States ────────────────────────────────────────────────────────────────
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSetupRequired extends AuthState {}
class AuthLocked extends AuthState {}
class AuthAuthenticated extends AuthState {
  final DateTime authenticatedAt = DateTime.now();
  @override
  List<Object?> get props => [authenticatedAt];
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  final _localAuth = LocalAuthentication();

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthSetupMasterPassword>(_onSetupMasterPassword);
    on<AuthUnlockWithPassword>(_onUnlockWithPassword);
    on<AuthUnlockWithBiometrics>(_onUnlockWithBiometrics);
    on<AuthLockApp>(_onLockApp);
    add(AuthCheckStatus());
  }

  Future<void> _onCheckStatus(AuthCheckStatus e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final hash = await _storage.read(key: AppConstants.masterPasswordHashKey);
    emit(hash == null ? AuthSetupRequired() : AuthLocked());
  }

  Future<void> _onSetupMasterPassword(AuthSetupMasterPassword e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final salt = CryptoUtils.generateSalt();
      final hash = CryptoUtils.hashPassword(e.password, salt);
      final encKey = CryptoUtils.generateRandomBytes(32);
      final vaultKey = CryptoUtils.generateRandomBytes(32);
      await _storage.write(key: AppConstants.masterPasswordHashKey, value: hash);
      await _storage.write(key: AppConstants.masterSaltKey, value: salt);
      await _storage.write(key: AppConstants.encryptionKeyKey, value: base64.encode(encKey));
      await _storage.write(key: AppConstants.vaultKeyKey, value: base64.encode(vaultKey));
      await SecurityLogService.logEvent(
        title: 'Master Password Initialized',
        message: 'PBKDF2 master salt and 256-bit encryption keys generated.',
        severity: 'safe',
        category: 'Auth',
      );
      emit(AuthAuthenticated());
    } catch (err) {
      emit(AuthError('Setup failed: $err'));
    }
  }

  Future<void> _onUnlockWithPassword(AuthUnlockWithPassword e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final hash = await _storage.read(key: AppConstants.masterPasswordHashKey);
    final salt = await _storage.read(key: AppConstants.masterSaltKey);
    if (hash == null || salt == null) { emit(AuthSetupRequired()); return; }
    final valid = CryptoUtils.verifyPassword(e.password, salt, hash);
    if (valid) {
      await SecurityLogService.logEvent(
        title: 'App Unlocked (Password)',
        message: 'Master password verification passed successfully.',
        severity: 'safe',
        category: 'Auth',
      );
      emit(AuthAuthenticated());
    } else {
      await SecurityLogService.logEvent(
        title: 'Password Unlock Failed',
        message: 'Incorrect master password attempt detected.',
        severity: 'warning',
        category: 'Auth',
      );
      emit(AuthError('Incorrect master password'));
      await Future.delayed(const Duration(milliseconds: 400));
      emit(AuthLocked());
    }
  }

  Future<void> _onUnlockWithBiometrics(AuthUnlockWithBiometrics e, Emitter<AuthState> emit) async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canAuth) {
        emit(AuthError('Biometrics not available on this device'));
        await Future.delayed(const Duration(milliseconds: 400));
        emit(AuthLocked());
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock Cybe Security',
        biometricOnly: false,
      );
      if (authenticated) {
        await SecurityLogService.logEvent(
          title: 'App Unlocked (Biometric)',
          message: 'Biometric fingerprint/face challenge passed.',
          severity: 'safe',
          category: 'Auth',
        );
        emit(AuthAuthenticated());
      } else {
        await SecurityLogService.logEvent(
          title: 'Biometric Unlock Cancelled',
          message: 'Biometric authentication challenge was cancelled or failed.',
          severity: 'warning',
          category: 'Auth',
        );
        emit(AuthLocked());
      }
    } catch (err) {
      await SecurityLogService.logEvent(
        title: 'Biometric Error',
        message: 'Biometric authentication error: $err',
        severity: 'critical',
        category: 'Auth',
      );
      emit(AuthError('Biometric error: $err'));
      await Future.delayed(const Duration(milliseconds: 400));
      emit(AuthLocked());
    }
  }

  Future<void> _onLockApp(AuthLockApp e, Emitter<AuthState> emit) async {
    emit(AuthLocked());
  }
}
