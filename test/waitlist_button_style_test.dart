import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_telemedicina/core/theme/app_colors.dart';
import 'package:mobile_telemedicina/core/theme/app_theme.dart';
import 'package:mobile_telemedicina/features/waitlist/data/models/waitlist_models.dart';
import 'package:mobile_telemedicina/features/waitlist/domain/repositories/waitlist_repository.dart';
import 'package:mobile_telemedicina/features/waitlist/presentation/providers/waitlist_provider.dart';
import 'package:mobile_telemedicina/features/waitlist/presentation/screens/waitlist_screen.dart';
import 'package:provider/provider.dart';

class _RepositorioVacio implements WaitlistRepository {
  @override
  Future<List<InscripcionEsperaModel>> getMisInscripciones() async => const [];

  @override
  Future<InscripcionEsperaModel> inscribirse({
    int? idMedico,
    int? idEspecialidad,
    String? fechaDeseada,
    String? motivo,
  }) =>
      throw UnimplementedError();

  @override
  Future<InscripcionEsperaModel> salir(int id) => throw UnimplementedError();

  @override
  Future<InscripcionEsperaModel> confirmar(int id) => throw UnimplementedError();

  @override
  Future<InscripcionEsperaModel> rechazar(int id) => throw UnimplementedError();
}

void main() {
  testWidgets('El boton Inscribirme usa letras blancas sobre fondo primario',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<WaitlistProvider>(
        create: (_) => WaitlistProvider(repository: _RepositorioVacio()),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const WaitlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.foregroundColor, AppColors.onPrimary);
    expect(fab.backgroundColor, AppColors.primary);
    expect(find.text('Inscribirme'), findsOneWidget);
  });
}
