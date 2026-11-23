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

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _email = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      _email = args;
    }
  }

  @override
  void dispose() {
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final focusNode in _codeFocusNodes) {
      focusNode.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _code => _codeControllers.map((c) => c.text).join();

  void _onCodeChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _codeFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _codeFocusNodes[index - 1].requestFocus();
    }
    _formKey.currentState?.validate();
  }

  Future<void> _handleResetPassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = context.read<AuthController>();
    final success = await authController.resetPassword(
      _email,
      _code,
      _passwordController.text,
    );

    if (success && mounted) {
      authController.clearMessages();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
                    title: 'Restablecer Contraseña',
                    subtitle: 'Ingresa el código de 6 dígitos enviado a tu correo y tu nueva contraseña.',
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

                          // Code Input (6 digits)
                          Text(
                            'Código de Verificación',
                            style: AppTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width: 48,
                                height: 56,
                                child: TextFormField(
                                  controller: _codeControllers[index],
                                  focusNode: _codeFocusNodes[index],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  decoration: InputDecoration(
                                    counterText: '',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: AppColors.divider, width: 1.2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: AppColors.divider, width: 1.2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                  ),
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  onChanged: (value) => _onCodeChanged(index, value),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return '';
                                    }
                                    return null;
                                  },
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Se envió un código a $_email',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // New Password Field
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Nueva Contraseña',
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.next,
                            validator: Validators.validatePassword,
                            onFieldSubmitted: (_) {
                              FocusScope.of(context).requestFocus(_confirmPasswordFocus);
                            },
                          ),
                          const SizedBox(height: 18),

                          // Confirm Password Field
                          CustomTextField(
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocus,
                            label: 'Confirmar Contraseña',
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            validator: (value) => Validators.validateConfirmPassword(value, _passwordController.text),
                            onFieldSubmitted: (_) => _handleResetPassword(),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          AuthButton(
                            text: 'Restablecer Contraseña',
                            icon: Icons.lock_reset_rounded,
                            isLoading: authController.isLoading,
                            onPressed: _handleResetPassword,
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
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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

final FocusNode _confirmPasswordFocus = FocusNode();