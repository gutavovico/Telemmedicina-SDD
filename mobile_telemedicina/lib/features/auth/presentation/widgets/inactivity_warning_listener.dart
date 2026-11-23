import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';

/// Aviso de cierre por inactividad con cuenta regresiva (CU23).
///
/// Se monta una sola vez sobre la aplicacion, encima del `Navigator`, para que
/// el aviso aparezca este donde este el usuario. La cuenta atras la emite
/// [AuthController.inactivityWarning]; al agotarse, el backend ya habra
/// revocado la sesion y el controlador limpiara las credenciales.
class InactivityWarningListener extends StatefulWidget {
  const InactivityWarningListener({super.key, required this.child});

  final Widget child;

  @override
  State<InactivityWarningListener> createState() =>
      _InactivityWarningListenerState();
}

class _InactivityWarningListenerState extends State<InactivityWarningListener> {
  StreamSubscription<int>? _warningSub;
  int _seconds = 0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _warningSub = auth.inactivityWarning.listen(_onTick);
  }

  void _onTick(int seconds) {
    if (!mounted) return;
    // El servicio emite 0 justo antes de cerrar la sesion: en ese momento el
    // aviso ya no debe quedar congelado sobre la pantalla.
    setState(() {
      _seconds = seconds;
      _visible = seconds > 0;
    });
  }

  @override
  void dispose() {
    _warningSub?.cancel();
    super.dispose();
  }

  Future<void> _continue() async {
    final auth = context.read<AuthController>();
    if (!mounted) return;
    setState(() => _visible = false);
    await auth.continueSession();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned.fill(
            child: _InactivityOverlay(
              seconds: _seconds,
              onContinue: _continue,
            ),
          ),
      ],
    );
  }
}

class _InactivityOverlay extends StatelessWidget {
  const _InactivityOverlay({required this.seconds, required this.onContinue});

  final int seconds;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tu sesión está por cerrarse',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Por seguridad, la sesión se cerrará automáticamente si no '
                  'hay actividad.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${seconds}s',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Seguir conectado'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
