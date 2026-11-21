import 'package:flutter/material.dart';
import '../../data/services/fcm_adapter.dart';

/// Banner emergente flotante estilo WhatsApp en primer plano (CU20).
/// Aparece suavemente desde arriba, se descarta al deslizar hacia arriba o desaparece solo tras unos segundos.
class InAppNotificationBanner extends StatelessWidget {
  final NotificacionMensajePush mensaje;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const InAppNotificationBanner({
    super.key,
    required this.mensaje,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Dismissible(
        key: ValueKey('inapp_banner_${mensaje.id}'),
        direction: DismissDirection.up,
        onDismissed: (_) => onDismiss(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF0F4C81).withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F4C81),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  mensaje.titulo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ahora',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            mensaje.cuerpo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.25,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      onPressed: onDismiss,
                      tooltip: 'Descartar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
