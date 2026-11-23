class Validators {
  // Validate Email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu correo electrónico.';
    }
    final trimmed = value.trim();
    final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegExp.hasMatch(trimmed)) {
      return 'Ingresa un correo electrónico válido.';
    }
    return null;
  }

  // Validate Required Name / Text
  static String? validateName(String? value, {String fieldName = 'nombre'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tus $fieldName (mín. 2 letras).';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Los $fieldName deben tener al menos 2 caracteres.';
    }
    if (trimmed.length > 100) {
      return 'Los $fieldName no deben exceder los 100 caracteres.';
    }
    return null;
  }

  // Validate Password (min 6 chars)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa una contraseña.';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return null;
  }

  // Validate Confirm Password
  static String? validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña.';
    }
    if (value != originalPassword) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  // Validate Phone (optional)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }
    final trimmed = value.trim();
    final phoneRegExp = RegExp(r'^[+0-9\s\-()]{7,20}$');
    if (!phoneRegExp.hasMatch(trimmed)) {
      return 'Formato de teléfono inválido.';
    }
    return null;
  }

  // Calculate password strength score 0 to 3
  static int calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 8 && RegExp(r'[0-9]').hasMatch(password)) score++;
    if (password.length >= 10 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      score++;
    }
    return score; // 0: None, 1: Weak, 2: Medium, 3: Strong
  }
}
