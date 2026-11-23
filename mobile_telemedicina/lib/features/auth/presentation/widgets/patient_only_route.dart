import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

/// Protects patient views even when their route is opened directly.
/// The backend remains responsible for authorizing every data request.
class PatientOnlyRoute extends StatefulWidget {
  final Widget child;

  const PatientOnlyRoute({super.key, required this.child});

  @override
  State<PatientOnlyRoute> createState() => _PatientOnlyRouteState();
}

class _PatientOnlyRouteState extends State<PatientOnlyRoute> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccess());
  }

  Future<void> _checkAccess() async {
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated) {
      await auth.checkAuthStatus();
    }
    if (!mounted) return;

    if (auth.isPatient) {
      setState(() => _checking = false);
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      auth.isAuthenticated ? '/home' : '/login',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return widget.child;
  }
}
