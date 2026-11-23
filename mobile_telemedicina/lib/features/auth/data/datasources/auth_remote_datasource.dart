import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_interface.dart';
import '../models/auth_models.dart';

class AuthRemoteDataSource {
  final ApiClientInterface _apiClient;

  AuthRemoteDataSource({ApiClientInterface? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // Login
  Future<TokenResponse> login(LoginRequest request) async {
    final response = await _apiClient.post(
      ApiConfig.loginUrl,
      body: request.toJson(),
      includeAuth: false,
    );
    return TokenResponse.fromJson(response as Map<String, dynamic>);
  }

  // Register
  Future<UserModel> register(RegisterRequest request) async {
    final response = await _apiClient.post(
      ApiConfig.registerUrl,
      body: request.toJson(),
      includeAuth: false,
    );
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  // Get current user profile
  Future<UserModel> getMe() async {
    final response = await _apiClient.get(
      ApiConfig.meUrl,
      includeAuth: true,
    );
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  // Refresh token
  Future<TokenResponse> refreshToken(String refreshToken) async {
    final response = await _apiClient.post(
      ApiConfig.refreshUrl,
      body: {'refresh_token': refreshToken},
      includeAuth: false,
    );
    return TokenResponse.fromJson(response as Map<String, dynamic>);
  }

  // Forgot Password
  Future<ForgotPasswordResponse> forgotPassword(ForgotPasswordRequest request) async {
    final response = await _apiClient.post(
      ApiConfig.forgotPasswordUrl,
      body: request.toJson(),
      includeAuth: false,
    );
    return ForgotPasswordResponse.fromJson(response as Map<String, dynamic>);
  }

  // Inactivity status (CU23). GET does NOT renew the session: it only reports
  // the remaining time so the client can reconcile its own clock.
  Future<SessionStatusResponse> getSessionStatus() async {
    final response = await _apiClient.get(ApiConfig.sessionUrl);
    return SessionStatusResponse.fromJson(response as Map<String, dynamic>);
  }

  // Renews `ultima_actividad` on the server (CU23 "Seguir conectado").
  Future<SessionStatusResponse> continueSession() async {
    final response = await _apiClient.post(
      ApiConfig.sessionContinueUrl,
      body: <String, dynamic>{},
    );
    return SessionStatusResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Cierre global de sesion (CU24).
  ///
  /// Se envia el `refresh_token` en el body y no como Bearer: tras un logout, el
  /// access token puede estar invalidado y aun asi hay que poder cerrar la
  /// sesion de forma idempotente.
  Future<void> logout([String? refreshToken]) async {
    await _apiClient.post(
      ApiConfig.logoutUrl,
      body: <String, dynamic>{
        if (refreshToken != null && refreshToken.isNotEmpty)
          'refresh_token': refreshToken,
      },
    );
  }

  // Reset Password
  Future<void> resetPassword(ResetPasswordRequest request) async {
    await _apiClient.post(
      ApiConfig.resetPasswordUrl,
      body: request.toJson(),
      includeAuth: false,
    );
  }
}
