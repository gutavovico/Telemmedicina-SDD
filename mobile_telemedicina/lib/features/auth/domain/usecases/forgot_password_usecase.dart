import '../../data/models/auth_models.dart';
import '../repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  final AuthRepository _repository;

  ForgotPasswordUseCase(this._repository);

  Future<ForgotPasswordResponse> call(ForgotPasswordRequest request) {
    return _repository.forgotPassword(request);
  }
}
