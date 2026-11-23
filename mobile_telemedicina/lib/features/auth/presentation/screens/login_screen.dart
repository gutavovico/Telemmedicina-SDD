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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = context.read<AuthController>();
    final success = await authController.login(
      _emailController.text.trim(),
      _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (success && mounted) {
      // CU23: el control de inactividad arranca con la sesion ya valida.
      authController.startInactivityControl();
      Navigator.of(context).pushReplacementNamed('/home');
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
                    title: 'Iniciar Sesión',
                    subtitle: 'Ingresa a tu cuenta para acceder a tus consultas, citas médicas y recetas digitales.',
                  ),
                  const SizedBox(height: 28),

                  // Main Login Card
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
                            textInputAction: TextInputAction.next,
                            validator: Validators.validateEmail,
                            onFieldSubmitted: (_) {
                              FocusScope.of(context).requestFocus(_passwordFocus);
                            },
                          ),
                          const SizedBox(height: 18),

                          // Password Field
                          CustomTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            label: 'Contraseña',
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            validator: Validators.validatePassword,
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 12),

                          // Remember Me Checkbox
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) {
                                    setState(() {
                                      _rememberMe = val ?? true;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _rememberMe = !_rememberMe;
                                  });
                                },
                                child: Text(
                                  'Recordar sesión',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          AuthButton(
                            text: 'Ingresar al Portal',
                            icon: Icons.login_rounded,
                            isLoading: authController.isLoading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 16),

                          // Forgot Password Link
                          Center(
                            child: TextButton(
                              onPressed: () {
                                authController.clearMessages();
                                Navigator.of(context).pushNamed('/forgot-password');
                              },
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer Register Link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '¿Aún no tienes una cuenta? ',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          authController.clearMessages();
                          Navigator.of(context).pushNamed('/register');
                        },
                        child: Text(
                          'Regístrate aquí',
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

                  // Hospital Info Footnote
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
