import '../../data/models/auth_models.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<TokenResponse> login(LoginRequest request);
  Future<UserEntity> register(RegisterRequest request);
  Future<ForgotPasswordResponse> forgotPassword(ForgotPasswordRequest request);
  Future<void> resetPassword(ResetPasswordRequest request);
  Future<UserEntity> getMe();
  Future<void> logout();
}
