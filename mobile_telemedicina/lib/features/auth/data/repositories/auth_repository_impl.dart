import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl({AuthRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? AuthRemoteDataSource();

  @override
  Future<TokenResponse> login(LoginRequest request) => _remoteDataSource.login(request);

  @override
  Future<UserEntity> register(RegisterRequest request) => _remoteDataSource.register(request);

  @override
  Future<ForgotPasswordResponse> forgotPassword(ForgotPasswordRequest request) =>
      _remoteDataSource.forgotPassword(request);

  @override
  Future<void> resetPassword(ResetPasswordRequest request) =>
      _remoteDataSource.resetPassword(request);

  @override
  Future<UserEntity> getMe() => _remoteDataSource.getMe();

  @override
  Future<void> logout() => _remoteDataSource.logout();
}
