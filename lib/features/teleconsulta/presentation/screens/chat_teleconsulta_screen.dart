import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/chat_message_model.dart';
import '../providers/teleconsulta_provider.dart';

class ChatTeleconsultaScreen extends StatefulWidget {
  final int idCita;
  final String? medicoNombre;
  final String? especialidadNombre;
  final String? fechaCita;
  final String? horaCita;
  final String? clinicaNombre;
  final bool isModal;

  const ChatTeleconsultaScreen({
    super.key,
    required this.idCita,
    this.medicoNombre,
    this.especialidadNombre,
    this.fechaCita,
    this.horaCita,
    this.clinicaNombre,
    this.isModal = false,
  });

  static Future<void> showAsModal(
    BuildContext context, {
    required int idCita,
    String? medicoNombre,
    String? especialidadNombre,
    String? fechaCita,
    String? horaCita,
    String? clinicaNombre,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ChatTeleconsultaScreen(
          idCita: idCita,
          medicoNombre: medicoNombre,
          especialidadNombre: especialidadNombre,
          fechaCita: fechaCita,
          horaCita: horaCita,
          clinicaNombre: clinicaNombre,
          isModal: true,
        ),
      ),
    );
  }

  @override
  State<ChatTeleconsultaScreen> createState() => _ChatTeleconsultaScreenState();
}

class _ChatTeleconsultaScreenState extends State<ChatTeleconsultaScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  TeleconsultaProvider? _teleconsultaProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<TeleconsultaProvider>(context, listen: false);
      _teleconsultaProvider = provider;
      provider.cargarTeleconsulta(widget.idCita);
      provider.iniciarPolling(widget.idCita);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _teleconsultaProvider?.detenerPolling();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _limpiarTituloMedico(String? nombre) {
    if (nombre == null || nombre.trim().isEmpty) return 'Dr. Especialista';
    var limpio = nombre.trim();
    limpio = limpio.replaceAll(RegExp(r'^(Dr\(a\)\.?\s*)+', caseSensitive: false), '');
    limpio = limpio.replaceAll(RegExp(r'^(Dr\.?\s*)+', caseSensitive: false), '');
    limpio = limpio.replaceAll(RegExp(r'^(Dra\.?\s*)+', caseSensitive: false), '');
    return 'Dr. $limpio';
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final provider = Provider.of<TeleconsultaProvider>(context, listen: false);

    _scrollToBottom();
    final ok = await provider.enviarMensaje(
      idCita: widget.idCita,
      contenido: text,
    );

    if (ok) {
      _scrollToBottom();
    }
  }

  Future<void> _seleccionarArchivoReal() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'doc', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final f = result.files.first;
        final bytes = f.bytes;
        final kb = ((f.size > 0 ? f.size : (bytes?.length ?? 1024)) / 1024).ceil();
        final ext = (f.extension ?? 'pdf').toLowerCase();
        String mime = 'application/pdf';
        if (['png', 'jpg', 'jpeg', 'webp'].contains(ext)) {
          mime = 'image/${ext == 'jpg' ? 'jpeg' : ext}';
        }
        final dataUrl = bytes != null ? 'data:$mime;base64,${base64Encode(bytes)}' : null;
        if (!mounted) return;
        final provider = Provider.of<TeleconsultaProvider>(context, listen: false);
        await provider.enviarMensaje(
          idCita: widget.idCita,
          contenido: 'Adjunto documento: ${f.name}',
          adjuntoNombre: f.name,
          adjuntoTamano: '$kb KB',
          adjuntoUrl: dataUrl,
        );
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _seleccionarImagenGaleria() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        final kb = (bytes.length / 1024).ceil();
        final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (!mounted) return;
        final provider = Provider.of<TeleconsultaProvider>(context, listen: false);
        await provider.enviarMensaje(
          idCita: widget.idCita,
          contenido: 'Adjunto imagen médica: ${xfile.name}',
          adjuntoNombre: xfile.name,
          adjuntoTamano: '$kb KB',
          adjuntoUrl: dataUrl,
        );
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _mostrarSelectorAdjuntos() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adjuntar archivo a la consulta',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.upload_file_rounded, color: AppColors.primary),
                ),
                title: const Text('Seleccionar Documento o PDF del dispositivo'),
                subtitle: const Text('PDF, JPG, PNG o Documento clínico'),
                onTap: () {
                  Navigator.pop(ctx);
                  _seleccionarArchivoReal();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.successContainer,
                  child: Icon(Icons.photo_library_outlined, color: AppColors.success),
                ),
                title: const Text('Seleccionar Fotografía de la Galería'),
                subtitle: const Text('Enviar foto o imagen médica en tiempo real'),
                onTap: () {
                  Navigator.pop(ctx);
                  _seleccionarImagenGaleria();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Uint8List? _extraerBytesDataUrl(String? url) {
    if (url == null || !url.startsWith('data:')) return null;
    final commaIdx = url.indexOf(',');
    if (commaIdx < 0) return null;
    try {
      return base64Decode(url.substring(commaIdx + 1));
    } catch (_) {
      return null;
    }
  }

  void _verArchivoAdjunto(ChatMessageModel msg) {
    final bytes = _extraerBytesDataUrl(msg.adjuntoUrl);
    final esImagen = (msg.adjuntoUrl != null && msg.adjuntoUrl!.startsWith('data:image/')) ||
        (msg.adjuntoNombre != null &&
            RegExp(r'\.(png|jpg|jpeg|webp|gif)$', caseSensitive: false).hasMatch(msg.adjuntoNombre!));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          msg.adjuntoNombre ?? 'Documento clínico',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: esImagen && bytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, color: AppColors.primary, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.adjuntoNombre ?? 'Documento.pdf',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'Tamaño: ${msg.adjuntoTamano ?? "Adjunto"} • Enviado por ${msg.nombreRemitente}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      msg.contenido,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _descargarArchivoAdjunto(msg);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Descargar'),
          ),
        ],
      ),
    );
  }

  Future<void> _descargarArchivoAdjunto(ChatMessageModel msg) async {
    try {
      final bytes = _extraerBytesDataUrl(msg.adjuntoUrl) ??
          Uint8List.fromList(
            utf8.encode(
              'DOCUMENTO DE TELECONSULTA\nArchivo: ${msg.adjuntoNombre}\nRemitente: ${msg.nombreRemitente}\nDetalle: ${msg.contenido}\n',
            ),
          );
      final nombreCompleto = msg.adjuntoNombre ?? 'documento_teleconsulta.pdf';
      final dotIdx = nombreCompleto.lastIndexOf('.');
      final nombreSinExt = dotIdx > 0 ? nombreCompleto.substring(0, dotIdx) : nombreCompleto;
      final ext = dotIdx > 0 ? nombreCompleto.substring(dotIdx + 1) : 'pdf';

      await FileSaver.instance.saveFile(
        name: nombreSinExt,
        bytes: bytes,
        fileExtension: ext,
        mimeType: MimeType.other,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo descargado: $nombreCompleto'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo preparado: ${msg.adjuntoNombre ?? "documento"}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teleconsultaProvider = Provider.of<TeleconsultaProvider>(context);
    final vm = teleconsultaProvider.teleconsulta;

    final nombreMedicoReal = _limpiarTituloMedico(
      vm?.medico?.nombreCompleto ?? widget.medicoNombre,
    );
    final especialidadReal = vm?.cita?.especialidad ?? widget.especialidadNombre ?? 'Medicina General';
    final fechaReal = vm?.cita?.rangoFechas ?? widget.fechaCita ?? 'Hoy';
    final horaReal = vm?.cita?.horaTeleconsulta ?? widget.horaCita ?? '10:30 h';
    final clinicaReal = vm?.nombreClinica ?? widget.clinicaNombre ?? 'Hospital San Juan de Dios';

    final mensajes = teleconsultaProvider.mensajes;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    Widget content = Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      widget.isModal ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary,
                        backgroundImage: vm?.medico?.fotoUrl != null && vm!.medico!.fotoUrl!.isNotEmpty
                            ? NetworkImage(vm.medico!.fotoUrl!)
                            : null,
                        child: vm?.medico?.fotoUrl == null || vm!.medico!.fotoUrl!.isEmpty
                            ? const Icon(Icons.person, color: Colors.white, size: 24)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          nombreMedicoReal,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              especialidadReal,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                            Text(
                              'Chat en tiempo real',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF8FAFC),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$fechaReal • $horaReal • $clinicaReal',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Cita activa',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSuccessContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: teleconsultaProvider.isLoading && mensajes.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : mensajes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 32,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Inicia la conversación',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Envía un saludo o adjunta tus estudios y documentos clínicos.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: mensajes.length,
                          itemBuilder: (ctx, index) {
                            final msg = mensajes[index];
                            return _buildMessageBubble(msg);
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.divider, width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary),
                    onPressed: _mostrarSelectorAdjuntos,
                    tooltip: 'Adjuntar archivo',
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSendMessage(),
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Escribe a $nombreMedicoReal...',
                          hintStyle: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _handleSendMessage,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isModal) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: content,
      );
    }

    return content;
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final esPropio = msg.esPropio;
    final bytesImagen = (msg.adjuntoUrl != null && msg.adjuntoUrl!.startsWith('data:image/'))
        ? _extraerBytesDataUrl(msg.adjuntoUrl)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: esPropio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esPropio) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: esPropio ? AppColors.primary : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(esPropio ? 16 : 4),
                  bottomRight: Radius.circular(esPropio ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    esPropio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.contenido,
                    style: AppTypography.bodyMedium.copyWith(
                      color: esPropio ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  if (msg.adjuntoNombre != null && msg.adjuntoNombre!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (bytesImagen != null) ...[
                            GestureDetector(
                              onTap: () => _verArchivoAdjunto(msg),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  bytesImagen,
                                  height: 130,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.attach_file_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${msg.adjuntoNombre} (${msg.adjuntoTamano ?? "Archivo"})',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _verArchivoAdjunto(msg),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.visibility_outlined, size: 14, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Ver',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _descargarArchivoAdjunto(msg),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.download_rounded, size: 14, color: AppColors.textPrimary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Descargar',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.horaDisplay,
                        style: AppTypography.bodySmall.copyWith(
                          color: esPropio
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      if (esPropio) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.idMensaje < 0
                              ? Icons.access_time_rounded
                              : Icons.done_all_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
