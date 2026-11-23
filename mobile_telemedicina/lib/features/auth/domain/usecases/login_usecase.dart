import '../../data/models/auth_models.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<TokenResponse> call(LoginRequest request) {
    return _repository.login(request);
  }
}
