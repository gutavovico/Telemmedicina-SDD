import '../../data/models/auth_models.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository _repository;

  ResetPasswordUseCase(this._repository);

  Future<void> call(ResetPasswordRequest request) {
    return _repository.resetPassword(request);
  }
}
