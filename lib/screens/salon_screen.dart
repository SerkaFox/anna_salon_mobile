import 'package:flutter/material.dart';

import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'cashbox_screen.dart';
import 'employees_screen.dart';
import 'services_screen.dart';
import 'shared.dart';

class SalonScreen extends StatelessWidget {
  const SalonScreen({
    required this.api,
    required this.canManageStaff,
    required this.currentEmployeeId,
    super.key,
  });

  final AnnaApi api;
  final bool canManageStaff;
  final String? currentEmployeeId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ScreenScaffold(
      title: canManageStaff ? t.tr('Salon') : t.tr('Mi trabajo'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SalonActionCard(
            icon: Icons.badge_outlined,
            title: canManageStaff ? t.tr('Empleados') : t.tr('Mi ficha'),
            subtitle: canManageStaff
                ? t.tr('Datos, servicios, comision, estadisticas y color.')
                : t.tr('Datos propios, servicios que realizas y estadisticas.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DecoratedBox(
                  decoration: annaBackgroundDecoration(context),
                  child: SafeArea(
                    child: EmployeesScreen(
                      api: api,
                      canManageStaff: canManageStaff,
                      currentEmployeeId: currentEmployeeId,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (canManageStaff) ...[
            const SizedBox(height: 12),
            _SalonActionCard(
              icon: Icons.spa_outlined,
              title: t.tr('Servicios y zonas'),
              subtitle:
                  t.tr('Servicios, precios, duracion, colores y recursos.'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DecoratedBox(
                    decoration: annaBackgroundDecoration(context),
                    child: SafeArea(
                      child: ServicesScreen(
                        api: api,
                        canManageStaff: canManageStaff,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SalonActionCard(
              icon: Icons.point_of_sale_outlined,
              title: t.tr('Caja'),
              subtitle: t.tr('Cobros, documentos, caja del dia y cierres.'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DecoratedBox(
                    decoration: annaBackgroundDecoration(context),
                    child: SafeArea(
                      child: CashboxScreen(api: api),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SalonActionCard extends StatelessWidget {
  const _SalonActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AnnaColors.line),
          ),
          child: Icon(icon),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child:
              Text(subtitle, style: const TextStyle(color: AnnaColors.muted)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
