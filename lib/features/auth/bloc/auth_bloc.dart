import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/crypto_utils.dart';

// ─── Events ────────────────────────────────────────────────────────────────
abstract class AuthEvent {}
class AuthCheckStatus extends AuthEvent {}
class AuthSetupMasterPassword extends AuthEvent {
  final String password;
  AuthSetupMasterPassword(this.password);
}
class AuthUnlockWithPassword extends AuthEvent {
  final String password;
  AuthUnlockWithPassword(this.password);
}
class AuthUnlockWithBiometrics extends AuthEvent {}
class AuthLockApp extends AuthEvent {}

// ─── States ────────────────────────────────────────────────────────────────
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSetupRequired extends AuthState {}
class AuthLocked extends AuthState {}
class AuthAuthenticated extends AuthState {
  final DateTime authenticatedAt = DateTime.now();
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
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
      emit(AuthAuthenticated());
    } else {
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
      emit(authenticated ? AuthAuthenticated() : AuthLocked());
    } catch (err) {
      emit(AuthError('Biometric error: $err'));
      await Future.delayed(const Duration(milliseconds: 400));
      emit(AuthLocked());
    }
  }

  Future<void> _onLockApp(AuthLockApp e, Emitter<AuthState> emit) async {
    emit(AuthLocked());
  }
}
