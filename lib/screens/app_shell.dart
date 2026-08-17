import 'package:flutter/material.dart';

import '../app_settings_controller.dart';
import '../api/anna_api.dart';
import '../l10n/app_localizations.dart';
import 'shared.dart';
import 'booking_screen.dart';
import 'calendar_screen.dart';
import 'client_portal_screen.dart';
import 'clients_screen.dart';
import 'salon_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.api,
    required this.settings,
    required this.onSignOut,
    super.key,
  });

  final AnnaApi api;
  final AppSettingsController settings;
  final VoidCallback onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  DateTime? _calendarDate;
  String? _highlightBookingId;
  int _highlightToken = 0;
  BookingDraft? _bookingDraft;
  int _bookingDraftToken = 0;
  late Future<Map<String, dynamic>> _profile = _loadProfile();

  Future<Map<String, dynamic>> _loadProfile() async {
    final profile = (await widget.api.me()).data;
    if (profile['can_manage_staff'] == true) {
      try {
        profile['whatsapp_status'] = (await widget.api.whatsappStatus()).data;
      } on Object {
        profile['whatsapp_status'] = {
          'connected': false,
          'needs_reconnect': true,
          'status': 'error',
        };
      }
    }
    return profile;
  }

  void _handleBookingCreated(CreatedBooking booking) {
    setState(() {
      _calendarDate = booking.date;
      _highlightBookingId = booking.id;
      _highlightToken++;
      _index = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reserva creada.')),
    );
  }

  void _handleCalendarSlotSelected(CalendarSlotDraft draft) {
    setState(() {
      _bookingDraft = BookingDraft(
        startAt: draft.startAt,
        employeeId: draft.employeeId,
      );
      _bookingDraftToken++;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: DecoratedBox(
              decoration: annaBackgroundDecoration(context),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorState(
                    error: snapshot.error!,
                    onRetry: () => setState(() => _profile = _loadProfile()),
                  ),
                ),
              ),
            ),
          );
        }
        final profile = snapshot.data ?? const <String, dynamic>{};
        final isClientPortal = profile['role'] == 'client';
        if (isClientPortal) {
          return ClientPortalShell(
            api: widget.api,
            settings: widget.settings,
            profile: profile,
            onSignOut: widget.onSignOut,
          );
        }
        final canManageStaff = profile['can_manage_staff'] == true;
        final employeeId = profile['employee_id']?.toString();
        return _AppShellBody(
          api: widget.api,
          settings: widget.settings,
          onSignOut: widget.onSignOut,
          index: _index,
          onIndexChanged: (value) => setState(() => _index = value),
          calendarDate: _calendarDate,
          highlightBookingId: _highlightBookingId,
          highlightToken: _highlightToken,
          bookingDraft: _bookingDraft,
          bookingDraftToken: _bookingDraftToken,
          canManageStaff: canManageStaff,
          whatsappStatus: profile['whatsapp_status'] is Map
              ? Map<String, dynamic>.from(profile['whatsapp_status'] as Map)
              : null,
          employeeId: employeeId,
          onBookingCreated: _handleBookingCreated,
          onCalendarSlotSelected: _handleCalendarSlotSelected,
        );
      },
    );
  }
}

class _AppShellBody extends StatelessWidget {
  const _AppShellBody({
    required this.api,
    required this.settings,
    required this.onSignOut,
    required this.index,
    required this.onIndexChanged,
    required this.calendarDate,
    required this.highlightBookingId,
    required this.highlightToken,
    required this.bookingDraft,
    required this.bookingDraftToken,
    required this.canManageStaff,
    required this.whatsappStatus,
    required this.employeeId,
    required this.onBookingCreated,
    required this.onCalendarSlotSelected,
  });

  final AnnaApi api;
  final AppSettingsController settings;
  final VoidCallback onSignOut;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final DateTime? calendarDate;
  final String? highlightBookingId;
  final int highlightToken;
  final BookingDraft? bookingDraft;
  final int bookingDraftToken;
  final bool canManageStaff;
  final Map<String, dynamic>? whatsappStatus;
  final String? employeeId;
  final ValueChanged<CreatedBooking> onBookingCreated;
  final ValueChanged<CalendarSlotDraft> onCalendarSlotSelected;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final screens = [
      CalendarScreen(
        api: api,
        canManageStaff: canManageStaff,
        currentEmployeeId: employeeId,
        activeDate: calendarDate,
        highlightBookingId: highlightBookingId,
        highlightToken: highlightToken,
        onCreateFromSlot: onCalendarSlotSelected,
      ),
      BookingScreen(
        api: api,
        onBookingCreated: onBookingCreated,
        draft: bookingDraft,
        draftToken: bookingDraftToken,
      ),
      ClientsScreen(api: api, canManagePhotos: canManageStaff),
      SalonScreen(
        api: api,
        canManageStaff: canManageStaff,
        currentEmployeeId: employeeId,
      ),
      SettingsScreen(
        api: api,
        settings: settings,
        onSignOut: onSignOut,
      ),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: annaBackgroundDecoration(context),
        child: SafeArea(
          child: Column(
            children: [
              if (canManageStaff && whatsappStatus?['needs_reconnect'] == true)
                _WhatsAppDisconnectedBanner(
                  onOpenSettings: () => onIndexChanged(4),
                ),
              Expanded(child: screens[index]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onIndexChanged,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: t.calendar,
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: t.booking,
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: t.clients,
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: t.salon,
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: t.settings,
          ),
        ],
      ),
    );
  }
}

class _WhatsAppDisconnectedBanner extends StatelessWidget {
  const _WhatsAppDisconnectedBanner({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final russian = AppLocalizations.of(context).isRussian;
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: InkWell(
        onTap: onOpenSettings,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  russian
                      ? 'WhatsApp отключён. Нажмите, чтобы переподключить.'
                      : 'WhatsApp esta desconectado. Pulsa para volver a conectarlo.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
