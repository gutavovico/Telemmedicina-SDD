import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/hospital_brand_header.dart';
import '../widgets/password_strength_meter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _apellidosFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _acceptTerms = false;
  int _passwordStrength = 0;
  String? _termsError;

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _apellidosFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _passwordStrength = Validators.calculatePasswordStrength(value);
    });
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _termsError = _acceptTerms ? null : 'Debes aceptar los términos y condiciones para continuar.';
    });

    if (!_formKey.currentState!.validate() || !_acceptTerms) {
      return;
    }

    final authController = context.read<AuthController>();
    final success = await authController.register(
      nombres: _nombresController.text.trim(),
      apellidos: _apellidosController.text.trim(),
      correo: _emailController.text.trim(),
      password: _passwordController.text,
      telefono: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
    );

    if (success && mounted) {
      // Navigate back to Login and show success banner
      authController.setSuccessMessage('¡Cuenta creada con éxito! Inicia sesión para continuar.');
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Términos del Servicio', style: AppTypography.titleLarge),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'Bienvenido a la plataforma de Telemedicina del Hospital San Juan de Dios. Al registrarte y utilizar este servicio, aceptas la confidencialidad de tus datos médicos conforme a la normativa de salud y privacidad vigente. Toda la información proporcionada será resguardada bajo estrictos estándares de seguridad y utilizada únicamente para la gestión de tus consultas y atenciones médicas.',
            style: AppTypography.bodyMedium.copyWith(height: 1.4),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _acceptTerms = true;
                _termsError = null;
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Aceptar Términos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            authController.clearMessages();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  const HospitalBrandHeader(
                    title: 'Crear Cuenta',
                    subtitle: 'Regístrate para agendar consultas virtuales y acceder a tu historial médico institucional.',
                    compact: true,
                  ),
                  const SizedBox(height: 20),

                  // Main Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.divider, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Dynamic Error Banner
                          if (authController.errorMessage != null)
                            AuthBanner(
                              message: authController.errorMessage!,
                              type: BannerType.error,
                              onDismiss: () => authController.clearMessages(),
                            ),

                          // Nombres & Apellidos in 2 columns for wider screens or 2 full fields
                          CustomTextField(
                            controller: _nombresController,
                            label: 'Nombres',
                            hint: 'Ej. Juan Carlos',
                            prefixIcon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (v) => Validators.validateName(v, fieldName: 'nombres'),
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_apellidosFocus),
                          ),
                          const SizedBox(height: 16),

                          CustomTextField(
                            controller: _apellidosController,
                            focusNode: _apellidosFocus,
                            label: 'Apellidos',
                            hint: 'Ej. Pérez Gómez',
                            prefixIcon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (v) => Validators.validateName(v, fieldName: 'apellidos'),
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
                          ),
                          const SizedBox(height: 16),

                          // Email
                          CustomTextField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            label: 'Correo Electrónico',
                            hint: 'ejemplo@correo.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: Validators.validateEmail,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
                          ),
                          const SizedBox(height: 16),

                          // Phone (Optional)
                          CustomTextField(
                            controller: _phoneController,
                            focusNode: _phoneFocus,
                            label: 'Teléfono (Opcional)',
                            hint: '+591 70000000',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            validator: Validators.validatePhone,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          CustomTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            label: 'Contraseña',
                            hint: 'Mínimo 6 caracteres',
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.next,
                            validator: Validators.validatePassword,
                            onChanged: _onPasswordChanged,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPasswordFocus),
                          ),

                          // Password Strength Indicator
                          PasswordStrengthMeter(strengthScore: _passwordStrength),
                          const SizedBox(height: 12),

                          // Confirm Password
                          CustomTextField(
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocus,
                            label: 'Confirmar Contraseña',
                            hint: 'Repite tu contraseña',
                            prefixIcon: Icons.lock_reset_outlined,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            validator: (v) => Validators.validateConfirmPassword(v, _passwordController.text),
                            onFieldSubmitted: (_) => _handleRegister(),
                          ),
                          const SizedBox(height: 18),

                          // Terms and Conditions Checkbox
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _acceptTerms,
                                  onChanged: (val) {
                                    setState(() {
                                      _acceptTerms = val ?? false;
                                      if (_acceptTerms) _termsError = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _acceptTerms = !_acceptTerms;
                                      if (_acceptTerms) _termsError = null;
                                    });
                                  },
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Acepto los ',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _showTermsDialog,
                                        child: Text(
                                          'términos y condiciones',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            decoration: TextDecoration.underline,
                                            decorationColor: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ' y la política de privacidad de salud.',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_termsError != null) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 34),
                              child: Text(
                                _termsError!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Submit Button
                          AuthButton(
                            text: 'Registrar Cuenta de Paciente',
                            icon: Icons.person_add_alt_1_rounded,
                            isLoading: authController.isLoading,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Footer Login Link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '¿Ya tienes una cuenta registrada? ',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          authController.clearMessages();
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                        child: Text(
                          'Inicia sesión',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
