import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/widgets/sante_shell.dart';

class ClinicMobileExperience extends StatefulWidget {
  final String userName;
  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> consultations;
  final List<Map<String, dynamic>> ordonnances;
  final List<Map<String, dynamic>> appointments;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String patientId) onOpenPatient;
  final VoidCallback onScanPatient;
  final VoidCallback onNewPatient;
  final VoidCallback onNewAppointment;
  final VoidCallback onSettings;
  final Future<void> Function() onLogout;

  const ClinicMobileExperience({
    super.key,
    required this.userName,
    required this.patients,
    required this.consultations,
    required this.ordonnances,
    required this.appointments,
    required this.onRefresh,
    required this.onOpenPatient,
    required this.onScanPatient,
    required this.onNewPatient,
    required this.onNewAppointment,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  State<ClinicMobileExperience> createState() => _ClinicMobileExperienceState();
}

class _ClinicMobileExperienceState extends State<ClinicMobileExperience>
    with SingleTickerProviderStateMixin {
  String _page = 'home';
  Map<String, dynamic>? _selectedPatient;
  final _search = TextEditingController();
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _search.dispose();
    _intro.dispose();
    super.dispose();
  }

  void _go(String page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF8),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(key: ValueKey(_page), child: _content()),
              ),
            ),
            _bottomNavigation(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onScanPatient,
        backgroundColor: AppColors.g700,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scanner'),
      ),
    );
  }

  Widget _content() {
    switch (_page) {
      case 'patients':
        return _patientsPage();
      case 'patient':
        return _patientPage();
      case 'consultations':
        return _listPage(
          'Consultations',
          widget.consultations,
          Icons.medical_services_rounded,
        );
      case 'ordonnances':
        return _listPage(
          'Ordonnances',
          widget.ordonnances,
          Icons.receipt_long_rounded,
        );
      case 'appointments':
        return _appointmentsPage();
      case 'reports':
        return _reportsPage();
      case 'settings':
        return _settingsPage();
      default:
        return _homePage();
    }
  }

  Widget _header(String title, String subtitle, {VoidCallback? back}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          if (back != null)
            IconButton(
              onPressed: back,
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.g700,
            )
          else
            const SanteBrandLogo(
              emblemSize: 36,
              titleFontSize: 16,
              wordmarkWidth: 156,
            ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _title(19, AppColors.g900)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(10, AppColors.s500),
                ),
              ],
            ),
          ),
          if (back == null)
            IconButton(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.g700,
              tooltip: 'Actualiser',
            ),
        ],
      ),
    );
  }

  Widget _homePage() {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOut),
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            _header('Espace clinique', 'Suivi de votre établissement'),
            _hero(),
            const SizedBox(height: 14),
            Row(
              children: [
                _metric(
                  '${widget.patients.length}',
                  'Patients',
                  Icons.people_alt_rounded,
                  AppColors.g100,
                ),
                const SizedBox(width: 8),
                _metric(
                  '${widget.consultations.length}',
                  'Soins',
                  Icons.medical_services_rounded,
                  AppColors.blueBg,
                ),
                const SizedBox(width: 8),
                _metric(
                  '${widget.ordonnances.length}',
                  'Ordonnances',
                  Icons.receipt_long_rounded,
                  const Color(0xFFF0E8FF),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Actions rapides', style: _title(16, AppColors.g900)),
            const SizedBox(height: 8),
            _action(
              Icons.qr_code_scanner_rounded,
              'Scanner une carte patient',
              'Ouvrir rapidement un dossier',
              widget.onScanPatient,
              AppColors.g100,
            ),
            _action(
              Icons.person_add_alt_1_rounded,
              'Nouveau patient',
              'Créer un dossier patient',
              widget.onNewPatient,
              AppColors.blueBg,
            ),
            _action(
              Icons.calendar_month_rounded,
              'Nouveau rendez-vous',
              'Planifier une consultation',
              widget.onNewAppointment,
              const Color(0xFFFFF2D8),
            ),
            const SizedBox(height: 8),
            _section('Patients récents', () => _go('patients')),
            ...widget.patients.take(4).map(_patientTile),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.g800, AppColors.g600]),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 40),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour ${widget.userName.split(' ').first}',
                style: _body(12, Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'Votre établissement\nen bonne santé.',
                style: _title(20, Colors.white),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.health_and_safety_rounded,
          color: Colors.white,
          size: 38,
        ),
      ],
    ),
  );

  Widget _patientsPage() {
    final query = _search.text.trim().toLowerCase();
    final patients = widget.patients.where(
      (patient) =>
          query.isEmpty ||
          '${patient['fullName']} ${patient['dossierNumber']}'
              .toLowerCase()
              .contains(query),
    );
    return _pageScaffold('Patients', 'Dossiers rattachés à votre clinique', [
      Container(
        decoration: _surface(),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.g700),
            hintText: 'Rechercher un patient…',
            border: InputBorder.none,
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (patients.isEmpty)
        _empty('Aucun patient trouvé.')
      else
        ...patients.map(_patientTile),
    ]);
  }

  Widget _patientTile(Map<String, dynamic> patient) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: InkWell(
      onTap: () {
        _selectedPatient = patient;
        _go('patient');
      },
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: _surface(),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.g100,
              child: Icon(Icons.person_rounded, color: AppColors.g700),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient['fullName']?.toString() ?? 'Patient',
                    style: _body(12, AppColors.s800, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${patient['dossierNumber'] ?? 'Dossier'} · Groupe ${patient['groupeSanguin'] ?? '—'}',
                    style: _body(10, AppColors.s500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.s400),
          ],
        ),
      ),
    ),
  );

  Widget _patientPage() {
    final patient = _selectedPatient ?? const <String, dynamic>{};
    final allergies = ((patient['allergies'] as List?) ?? const []).join(' · ');
    return _pageScaffold(
      patient['fullName']?.toString() ?? 'Dossier patient',
      'Dossier médical sécurisé',
      [
        _detail(
          'Numéro de dossier',
          patient['dossierNumber']?.toString() ?? '—',
          Icons.badge_rounded,
        ),
        _detail(
          'Téléphone',
          patient['telephone']?.toString() ?? '—',
          Icons.phone_rounded,
        ),
        _detail(
          'Groupe sanguin',
          patient['groupeSanguin']?.toString() ?? '—',
          Icons.favorite_rounded,
        ),
        _detail(
          'Allergies',
          allergies.isEmpty ? 'Aucune allergie renseignée' : allergies,
          Icons.warning_amber_rounded,
        ),
        FilledButton.icon(
          onPressed: () =>
              widget.onOpenPatient(patient['id']?.toString() ?? ''),
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Ouvrir le dossier complet'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.g700),
        ),
      ],
      back: 'patients',
    );
  }

  Widget _listPage(
    String title,
    List<Map<String, dynamic>> items,
    IconData icon,
  ) => _pageScaffold(
    title,
    'Données de votre établissement',
    items.isEmpty
        ? [_empty('Aucune donnée enregistrée.')]
        : items
              .map(
                (item) => _detail(
                  item['patient']?.toString() ??
                      item['type']?.toString() ??
                      'Document',
                  '${item['date'] ?? item['state'] ?? item['status'] ?? 'Enregistré'} · ${item['medicaments'] ?? item['diagnostic'] ?? ''}',
                  icon,
                ),
              )
              .toList(),
  );
  Widget _appointmentsPage() => _pageScaffold(
    'Rendez-vous',
    'Planning de votre clinique',
    [
      FilledButton.icon(
        onPressed: widget.onNewAppointment,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Planifier un rendez-vous'),
        style: FilledButton.styleFrom(backgroundColor: AppColors.g700),
      ),
      const SizedBox(height: 12),
      if (widget.appointments.isEmpty)
        _empty('Aucun rendez-vous planifié.')
      else
        ...widget.appointments.map(
          (item) => _detail(
            item['name']?.toString() ?? 'Patient',
            '${item['date'] ?? ''} · ${item['time'] ?? ''} · ${item['reason'] ?? 'Consultation'}',
            Icons.calendar_month_rounded,
          ),
        ),
    ],
  );
  Widget _reportsPage() =>
      _pageScaffold('Rapports', 'Vue rapide de l’activité', [
        _detail(
          'Patients suivis',
          '${widget.patients.length} dossiers actifs',
          Icons.people_alt_rounded,
        ),
        _detail(
          'Consultations',
          '${widget.consultations.length} consultations',
          Icons.medical_services_rounded,
        ),
        _detail(
          'Ordonnances',
          '${widget.ordonnances.length} prescriptions émises',
          Icons.receipt_long_rounded,
        ),
      ]);
  Widget _settingsPage() =>
      _pageScaffold('Paramètres', 'Compte et établissement', [
        _action(
          Icons.settings_rounded,
          'Paramètres de la clinique',
          'Modifier les informations de l’établissement',
          widget.onSettings,
          AppColors.g100,
        ),
        _action(
          Icons.security_rounded,
          'Sécurité du compte',
          'Gérer vos accès depuis votre espace sécurisé',
          widget.onSettings,
          AppColors.blueBg,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Se déconnecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: .35)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ]);

  Widget _pageScaffold(
    String title,
    String subtitle,
    List<Widget> children, {
    String back = 'home',
  }) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(title, subtitle, back: () => _go(back)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ],
    ),
  );
  Widget _action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    Color tint,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _surface(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.g700),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _body(12, AppColors.s800, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: _body(10, AppColors.s500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.s400),
          ],
        ),
      ),
    ),
  );
  Widget _detail(String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: _surface(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.g100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.g700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _body(12, AppColors.s800, weight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _body(10, AppColors.s500),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _section(String title, VoidCallback onTap) => Row(
    children: [
      Expanded(child: Text(title, style: _title(16, AppColors.g900))),
      TextButton(
        onPressed: onTap,
        child: Text(
          'Tout voir',
          style: _body(10, AppColors.g700, weight: FontWeight.w800),
        ),
      ),
    ],
  );
  Widget _metric(String value, String label, IconData icon, Color tint) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.g700, size: 18),
              const SizedBox(height: 7),
              Text(value, style: _title(19, AppColors.g900)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(9, AppColors.s500),
              ),
            ],
          ),
        ),
      );
  Widget _empty(String message) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _surface(),
    child: Text(message, style: _body(12, AppColors.s500)),
  );
  BoxDecoration _surface() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    border: Border.all(color: const Color(0xFFE5F0EC)),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: .025), blurRadius: 8),
    ],
  );
  TextStyle _title(double size, Color color) => GoogleFonts.syne(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
  );
  TextStyle _body(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w500,
  }) => GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  Widget _bottomNavigation() {
    final items = [
      ('home', Icons.home_rounded, 'Accueil'),
      ('patients', Icons.people_alt_rounded, 'Patients'),
      ('consultations', Icons.medical_services_rounded, 'Soins'),
      ('appointments', Icons.calendar_month_rounded, 'Agenda'),
      ('settings', Icons.settings_rounded, 'Réglages'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 14),
        ],
      ),
      child: Row(
        children: items.map((item) {
          final selected =
              _page == item.$1 || (_page == 'patient' && item.$1 == 'patients');
          return Expanded(
            child: InkWell(
              onTap: () => _go(item.$1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.$2,
                    color: selected ? AppColors.g700 : AppColors.s500,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$3,
                    style: _body(
                      9,
                      selected ? AppColors.g700 : AppColors.s500,
                      weight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
