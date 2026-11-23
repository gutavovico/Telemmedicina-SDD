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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  /// Canal de entrega del codigo (CU23). Solo email.
  final String _canal = 'email';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = context.read<AuthController>();
    final success = await authController.forgotPassword(
      _emailController.text.trim(),
      canal: _canal,
    );

    if (success && mounted) {
      Navigator.of(context).pushNamed(
        '/reset-password',
        arguments: _emailController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  const HospitalBrandHeader(
                    title: 'Recuperar Contraseña',
                    subtitle: 'Ingresa tu correo electrónico y te enviaremos un código de 6 dígitos para restablecer tu contraseña.',
                  ),
                  const SizedBox(height: 28),

                  // Main Card
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
                          // Dynamic Success Banner
                          if (authController.successMessage != null)
                            AuthBanner(
                              message: authController.successMessage!,
                              type: BannerType.success,
                              onDismiss: () => authController.clearMessages(),
                            ),

                          // Dynamic Error Banner
                          if (authController.errorMessage != null)
                            AuthBanner(
                              message: authController.errorMessage!,
                              type: BannerType.error,
                              onDismiss: () => authController.clearMessages(),
                            ),

                          // Email Field
                          CustomTextField(
                            controller: _emailController,
                            label: 'Correo Electrónico',
                            hint: 'ejemplo@correo.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            validator: Validators.validateEmail,
                            onFieldSubmitted: (_) => _handleForgotPassword(),
                          ),
const SizedBox(height: 24),

                          // Submit Button
                          AuthButton(
                            text: 'Enviar Código',
                            icon: Icons.send_rounded,
                            isLoading: authController.isLoading,
                            onPressed: _handleForgotPassword,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Back to Login Link
                  Center(
                    child: TextButton(
                      onPressed: () {
                        authController.clearMessages();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Volver al inicio de sesión',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  // Hospital Info Footnote
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Atención médica digital 24/7 • San Juan de Dios',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
