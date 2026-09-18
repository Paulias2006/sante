import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/providers/auth_provider.dart';
import 'package:sante/widgets/qr_widgets.dart';
import 'package:sante/widgets/sante_shell.dart';
import 'package:sante/services/notification_service.dart';
import 'package:sante/services/local_storage_service.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  int _selectedTabIndex = 0;
  int _dossierTabIndex = 2;
  bool _loading = true;
  bool _missingPatientLink = false;
  String? _loadError;
  Map<String, dynamic> _patient = {};
  List<dynamic> _ordonnances = [];
  List<dynamic> _consultations = [];
  List<dynamic> _analyses = [];
  List<dynamic> _delivrances = [];
  DateTime? _historyFrom;
  DateTime? _historyTo;

  bool _inSelectedPeriod(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return true;
    if (_historyFrom != null && date.isBefore(_historyFrom!)) return false;
    if (_historyTo != null && date.isAfter(_historyTo!)) return false;
    return true;
  }

  List<dynamic> get _filteredConsultations => _consultations
      .where((item) => _inSelectedPeriod(item['date'] ?? item['createdAt']))
      .toList();

  List<dynamic> get _filteredOrdonnances => _ordonnances
      .where((item) => _inSelectedPeriod(item['emiseAt'] ?? item['createdAt']))
      .toList();

  List<dynamic> get _filteredAnalyses => _analyses
      .where((item) => _inSelectedPeriod(item['date'] ?? item['createdAt']))
      .toList();

  List<dynamic> get _filteredDelivrances => _delivrances
      .where((item) => _inSelectedPeriod(item['date'] ?? item['createdAt']))
      .toList();

  Future<void> _selectHistoryRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _historyFrom != null && _historyTo != null
          ? DateTimeRange(start: _historyFrom!, end: _historyTo!)
          : null,
    );
    if (range == null) return;
    setState(() {
      _historyFrom = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      _historyTo = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
    });
  }

  Widget _historyPeriodControls() {
    final label = _historyFrom == null
        ? 'Toute la période'
        : '${_formattedDate(_historyFrom)} → ${_formattedDate(_historyTo)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: _selectHistoryRange,
            icon: const Icon(Icons.date_range_rounded),
            label: Text(label),
          ),
          if (_historyFrom != null)
            TextButton(
              onPressed: () => setState(() {
                _historyFrom = null;
                _historyTo = null;
              }),
              child: const Text('Réinitialiser'),
            ),
        ],
      ),
    );
  }

  Future<void> _printPatientDossier() async {
    final patientName = _userName.trim().isNotEmpty
        ? _userName
        : '${_patient['prenom'] ?? ''} ${_patient['nom'] ?? ''}'.trim();
    final dossierNumber = (_patient['dossierNumber'] ?? '—').toString();
    final allergies = ((_patient['allergies'] as List?) ?? [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .join(', ');
    final summary = [
      'SantéTogo - Dossier patient',
      'Patient: ${patientName.isEmpty ? 'Patient' : patientName}',
      'Dossier: $dossierNumber',
      'Téléphone: ${_patient['telephone'] ?? '—'}',
      'Groupe sanguin: ${_patient['groupeSanguin'] ?? '—'}',
      'Allergies: ${allergies.isEmpty ? 'Aucune allergie connue' : allergies}',
      'Ordonnances: ${_filteredOrdonnances.length}',
      'Consultations: ${_filteredConsultations.length}',
      'Analyses: ${_filteredAnalyses.length}',
    ].join('\n');

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: 'SantéTogo - Dossier patient'),
          pw.Text(summary),
          pw.SizedBox(height: 16),
          pw.Text(
            'Consultations',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          ..._filteredConsultations.map(
            (item) => pw.Text(
              '${_formattedDate(item['date'] ?? item['createdAt'])} - ${item['motif'] ?? 'Consultation'} - ${item['diagnostic'] ?? 'Diagnostic non renseigné'}',
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Ordonnances',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          ..._filteredOrdonnances.map(
            (item) => pw.Text(
              '${_formattedDate(item['emiseAt'] ?? item['createdAt'])} - ${item['status'] ?? 'active'} - ${(item['medicaments'] as List? ?? const []).map((med) => med['nom'] ?? 'Médicament').join(', ')}',
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Analyses',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          ..._filteredAnalyses.map(
            (item) => pw.Text(
              '${item['type'] ?? 'Analyse'} - ${_formattedDate(item['date'] ?? item['createdAt'])}',
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => document.save());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dossier envoyé vers l’impression ou le partage PDF.'),
        backgroundColor: AppColors.g700,
      ),
    );
  }

  void _showDossierDetail(String title, String value) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.syne(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.s800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.55,
                        color: AppColors.g700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPatientData());
  }

  Future<void> _loadPatientData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _missingPatientLink = false;
        _loadError = null;
      });
    }

    final currentUser = ref.read(authStateProvider).valueOrNull;
    final patientId = currentUser?.patientId;

    if (patientId == null || patientId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _missingPatientLink = true;
      });
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      Map<String, dynamic> dossier;
      try {
        dossier = await api.getPatientDossier(patientId);
        await LocalStorageService.savePatientDossier(patientId, dossier);
      } catch (_) {
        final cached = LocalStorageService.getPatientDossier(patientId);
        if (cached == null) rethrow;
        dossier = cached;
      }
      final patient = Map<String, dynamic>.from(dossier['patient'] ?? {});
      final ordonnances = List<dynamic>.from(dossier['ordonnances'] ?? []);
      final consultations = List<dynamic>.from(dossier['consultations'] ?? []);
      final analyses = List<dynamic>.from(dossier['analyses'] ?? []);
      final delivrances = List<dynamic>.from(dossier['delivrances'] ?? []);

      setState(() {
        _patient = patient;
        _ordonnances = ordonnances;
        _consultations = consultations;
        _analyses = analyses;
        _delivrances = delivrances;
        _loading = false;
      });
      try {
        await NotificationService.instance.syncMedicationReminders(
          _activePrescriptionMedicines(),
        );
      } catch (_) {
        // Notifications are optional and cannot invalidate a loaded dossier.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _buildLoadState() {
    final title = _missingPatientLink
        ? 'Compte patient non relié'
        : 'Dossier indisponible';
    final message = _missingPatientLink
        ? 'Ce compte patient ne possède pas encore de patientId associé.'
        : (_loadError ?? 'Le dossier n’a pas pu être chargé.');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _missingPatientLink
                  ? Icons.link_off_rounded
                  : Icons.cloud_off_rounded,
              size: 42,
              color: AppColors.g700,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.s800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.g600),
            ),
            if (!_missingPatientLink) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadPatientData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.g700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _userName {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final value = currentUser?.fullName.trim();
    if (value != null && value.isNotEmpty) return value;
    return '${_patient['prenom'] ?? ''} ${_patient['nom'] ?? ''}'.trim();
  }

  String _formattedDate(dynamic value) {
    if (value == null) return '—';
    try {
      final date = DateTime.tryParse(value.toString());
      if (date == null) return value.toString();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return value.toString();
    }
  }

  String _ageLabel(dynamic value) {
    final birthDate = DateTime.tryParse(value?.toString() ?? '');
    if (birthDate == null) return 'Âge non renseigné';
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }
    return years >= 0 ? '$years ans' : 'Âge non renseigné';
  }

  String _sexLabel(dynamic value) {
    switch (value?.toString().toUpperCase()) {
      case 'F':
      case 'FEMININ':
      case 'FÉMININ':
        return 'Féminin';
      case 'M':
      case 'MASCULIN':
        return 'Masculin';
      default:
        return 'Sexe non renseigné';
    }
  }

  List<Map<String, dynamic>> _activePrescriptionMedicines() {
    final medicines = <Map<String, dynamic>>[];
    for (final ordonnance in _ordonnances) {
      if (ordonnance is! Map) continue;
      if (!_isOrdonnanceActive(ordonnance)) continue;
      for (final med in (ordonnance['medicaments'] as List? ?? const [])) {
        if (med is Map) medicines.add(Map<String, dynamic>.from(med));
      }
    }
    return medicines;
  }

  bool _isOrdonnanceActive(dynamic value) {
    if (value is! Map) return false;
    final status = (value['status'] ?? 'active').toString().toLowerCase();
    if (status != 'active' && status != 'partial') return false;
    final expireAt = DateTime.tryParse(value['expireAt']?.toString() ?? '');
    return expireAt == null || expireAt.isAfter(DateTime.now());
  }

  List<String> _medicamentsFromOrdonnance(Map<String, dynamic> ordonnance) {
    final meds = <String>[];
    final items = ordonnance['medicaments'] as List? ?? const [];
    for (final item in items) {
      if (item is Map) {
        final name = item['nom'] ?? item['name'];
        final dose = item['dose'];
        final text = name == null ? 'Médicament' : name.toString();
        if (dose != null && dose.toString().isNotEmpty) {
          meds.add('$text · $dose');
        } else {
          meds.add(text);
        }
      }
    }
    return meds;
  }

  String _analysisStatusLabel(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'bas':
        return 'Bas';
      case 'eleve':
        return 'Élevé';
      case 'critique':
        return 'Critique';
      default:
        return 'Normal';
    }
  }

  String _relatedName(dynamic value, {String fallback = 'Non renseigné'}) {
    if (value is Map) {
      final name = value['nom']?.toString().trim() ?? '';
      final firstName = value['prenom']?.toString().trim() ?? '';
      final combined = '$firstName $name'.trim();
      if (combined.isNotEmpty) return combined;
    }
    return fallback;
  }

  String _pharmacyName(dynamic value) {
    if (value is Map && value['nom'] != null) return value['nom'].toString();
    if (value == null) return 'Pharmacie';
    return value.toString();
  }

  Widget _emptyState(String message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.s100),
        ),
        child: Text(
          message,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.g600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final userName = _userName.trim().isNotEmpty ? _userName : 'Patient';

    final navItems = [
      SanteDashboardNavItem(
        icon: Icons.home_rounded,
        label: 'Accueil',
        selected: _selectedTabIndex == 0,
        onTap: () => setState(() => _selectedTabIndex = 0),
      ),
      SanteDashboardNavItem(
        icon: Icons.folder_rounded,
        label: 'Mon dossier',
        selected: _selectedTabIndex == 1,
        onTap: () => setState(() => _selectedTabIndex = 1),
      ),
      SanteDashboardNavItem(
        icon: Icons.assignment_rounded,
        label: 'Ordonnances',
        selected: _selectedTabIndex == 2,
        onTap: () => setState(() => _selectedTabIndex = 2),
      ),
      SanteDashboardNavItem(
        icon: Icons.biotech_rounded,
        label: 'Analyses',
        selected: _selectedTabIndex == 3,
        onTap: () => setState(() => _selectedTabIndex = 3),
      ),
      SanteDashboardNavItem(
        icon: Icons.qr_code_rounded,
        label: 'Carte QR',
        selected: _selectedTabIndex == 4,
        onTap: () => setState(() => _selectedTabIndex = 4),
      ),
      SanteDashboardNavItem(
        icon: Icons.local_pharmacy_rounded,
        label: 'Pharmacie',
        selected: _selectedTabIndex == 5,
        onTap: () => setState(() => _selectedTabIndex = 5),
      ),
      SanteDashboardNavItem(
        icon: Icons.notifications_active_rounded,
        label: 'Rappels',
        selected: _selectedTabIndex == 6,
        onTap: () async {
          await NotificationService.instance.requestPermission();
          if (mounted) setState(() => _selectedTabIndex = 6);
        },
      ),
    ];

    return SanteDashboardShell(
      title: 'Accueil',
      subtitle: '— dossier patient',
      navItems: navItems,
      userName: userName,
      userRole: currentUser?.role.toLowerCase() == 'patient'
          ? 'Patient'
          : 'Accès patient',
      headerAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.g50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_rounded,
                  size: 14,
                  color: AppColors.g700,
                ),
                const SizedBox(width: 6),
                Text(
                  'Dossier actif',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.g700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _loadPatientData,
            tooltip: 'Actualiser le dossier',
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.g700,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_missingPatientLink || _loadError != null)
          ? _buildLoadState()
          : _buildContent(userName),
    );
  }

  Widget _buildContent(String userName) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildHome(userName);
      case 1:
        return _buildDossier(userName);
      case 2:
        return _buildOrdonnances();
      case 3:
        return _buildAnalyses();
      case 4:
        return _buildQrCard();
      case 5:
        return _buildPharmacyHistory();
      case 6:
        return _buildReminders();
      default:
        return _buildHome(userName);
    }
  }

  Widget _buildHome(String userName) {
    final dossierNumber = _patient['dossierNumber'] ?? '—';
    final bloodGroup = _patient['groupeSanguin'] ?? '—';
    final compact = MediaQuery.sizeOf(context).width < 520;
    final allergies = ((_patient['allergies'] as List?) ?? [])
        .map((e) => e.toString())
        .join(' · ');
    final activeOrdonnances = _ordonnances.where(_isOrdonnanceActive).toList();

    if (_patient.isEmpty) {
      return _emptyState(
        'Aucun dossier patient disponible pour cet utilisateur.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppColors.g900, AppColors.g700],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      userName.substring(0, 2).toUpperCase(),
                      style: GoogleFonts.syne(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        userName,
                        style: GoogleFonts.syne(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dossier $dossierNumber',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  title: 'Carte d’urgence',
                  subtitle: allergies.isEmpty
                      ? 'Aucune allergie renseignée'
                      : allergies,
                  icon: Icons.warning_amber_rounded,
                  tint: AppColors.dangerBg,
                  value: bloodGroup,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  title: 'QR patient',
                  subtitle: 'Montrer à la pharmacie',
                  icon: Icons.qr_code_rounded,
                  tint: AppColors.g50,
                  value: dossierNumber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: compact ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: compact ? 1.35 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MetricCard(
                label: 'Ordonnances',
                value: '${_ordonnances.length}',
                icon: Icons.assignment_rounded,
                tint: AppColors.g100,
              ),
              _MetricCard(
                label: 'Historique',
                value: '${_consultations.length}',
                icon: Icons.folder_rounded,
                tint: AppColors.blueBg,
              ),
              _MetricCard(
                label: 'Analyses',
                value: '${_analyses.length}',
                icon: Icons.biotech_rounded,
                tint: AppColors.warningBg,
              ),
              _MetricCard(
                label: 'Rappels',
                value: '${activeOrdonnances.length}',
                icon: Icons.notifications_rounded,
                tint: AppColors.g50,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.s100),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ordonnance active',
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.s800,
                  ),
                ),
                const SizedBox(height: 12),
                if (activeOrdonnances.isEmpty)
                  Text(
                    'Aucune ordonnance active enregistrée pour le moment.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.g600,
                    ),
                  )
                else ...[
                  for (final item in (activeOrdonnances.take(2).toList()))
                    ..._medicamentsFromOrdonnance(item).map(
                      (medicine) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MedicineRow(
                          name: medicine,
                          dose: 'Prescription active',
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDossier(String userName) {
    if (_patient.isEmpty) {
      return _emptyState(
        'Aucun dossier patient disponible pour cet utilisateur.',
      );
    }

    final allergies = ((_patient['allergies'] as List?) ?? [])
        .map((e) => e.toString())
        .join(' · ');
    final patientName = userName.trim().isNotEmpty
        ? userName
        : '${_patient['prenom'] ?? ''} ${_patient['nom'] ?? ''}'.trim();
    final dossierNumber = (_patient['dossierNumber'] ?? '—').toString();
    final phone = (_patient['telephone'] ?? '—').toString();
    final group = (_patient['groupeSanguin'] ?? '—').toString();
    final qrData = (_patient['qrToken'] ?? dossierNumber).toString();

    final tabs = [
      'Antécédents',
      'Consultations',
      'Médicaments',
      'Ordonnances',
      'Analyses',
    ];
    final compact = MediaQuery.sizeOf(context).width < 720;
    final initials = patientName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _historyPeriodControls(),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? double.infinity : 300,
                child: Text(
                  'Dossier patient',
                  style: GoogleFonts.syne(
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.s800,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: OutlinedButton.icon(
                      onPressed: _printPatientDossier,
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Imprimer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.g700,
                        side: const BorderSide(color: AppColors.s200),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _selectedTabIndex = 4),
                      icon: const Icon(Icons.qr_code_rounded, size: 16),
                      label: const Text('Carte QR'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.g700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.s100),
              borderRadius: BorderRadius.circular(18),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final identity = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppColors.g700,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Text(
                              initials.isEmpty ? 'ST' : initials,
                              style: GoogleFonts.syne(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: compact ? constraints.maxWidth - 84 : 320,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patientName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.syne(
                                  fontSize: compact ? 22 : 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.s800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _DossierInfoPill(
                                    label: _ageLabel(_patient['dateNaissance']),
                                    icon: Icons.calendar_today_rounded,
                                  ),
                                  _DossierInfoPill(
                                    label: _sexLabel(_patient['sexe']),
                                    icon: Icons.person_rounded,
                                  ),
                                  _DossierInfoPill(
                                    label: 'Groupe $group',
                                    icon: Icons.favorite_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Dossier actif',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (allergies.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE9E7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEEB2B2)),
                        ),
                        child: Text(
                          'Allergies connues : $allergies',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        Text(
                          'N° dossier $dossierNumber',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.g600,
                          ),
                        ),
                        Text(
                          phone,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.g700,
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                final qrSide = compact ? 190.0 : 126.0;
                final qrCard = Container(
                  width: compact ? double.infinity : 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.g50,
                    border: Border.all(color: AppColors.s100),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: qrSide,
                        height: qrSide,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.s100),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: QrImageView(
                            data: qrData.isNotEmpty ? qrData : dossierNumber,
                            padding: EdgeInsets.zero,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.g700,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.g700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dossierNumber,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.syne(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.g800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Carte permanente',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.g600,
                        ),
                      ),
                    ],
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [identity, const SizedBox(height: 18), qrCard],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 18),
                    qrCard,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.s100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(compact ? 10 : 0),
                  child: compact
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(tabs.length, (index) {
                            final selected = index == _dossierTabIndex;
                            return ChoiceChip(
                              label: Text(tabs[index]),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _dossierTabIndex = index),
                              selectedColor: AppColors.g700,
                              labelStyle: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : AppColors.g700,
                              ),
                              side: const BorderSide(color: AppColors.s100),
                            );
                          }),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(tabs.length, (index) {
                              final selected = index == _dossierTabIndex;
                              return InkWell(
                                onTap: () =>
                                    setState(() => _dossierTabIndex = index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: selected
                                            ? AppColors.g700
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      tabs[index],
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? AppColors.g700
                                            : AppColors.g600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: _patientDossierTabContent(_dossierTabIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _patientDossierTabContent(int tabIndex) {
    Widget row(
      String label,
      String value, {
      IconData icon = Icons.info_outline_rounded,
    }) {
      final compact = MediaQuery.sizeOf(context).width < 520;
      return InkWell(
        onTap: () => _showDossierDetail(label, value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.g50,
            border: Border.all(color: AppColors.s100),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.g700),
              const SizedBox(width: 10),
              SizedBox(
                width: compact ? 92 : 120,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  maxLines: compact ? 3 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.g600),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.s400,
              ),
            ],
          ),
        ),
      );
    }

    switch (tabIndex) {
      case 0:
        final allergies = ((_patient['allergies'] as List?) ?? [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(
              'Allergies',
              allergies.isEmpty
                  ? 'Aucune allergie connue'
                  : allergies.join(', '),
              icon: Icons.warning_amber_rounded,
            ),
            row(
              'Groupe sanguin',
              _patient['groupeSanguin']?.toString() ?? '—',
              icon: Icons.bloodtype_rounded,
            ),
            row(
              'Téléphone',
              _patient['telephone']?.toString() ?? '—',
              icon: Icons.phone_rounded,
            ),
            row(
              'Adresse',
              _patient['adresse']?.toString() ?? '—',
              icon: Icons.place_rounded,
            ),
          ],
        );
      case 1:
        if (_consultations.isEmpty) {
          return row(
            'Aucune',
            'Aucune consultation enregistrée dans ce dossier.',
            icon: Icons.medical_information_rounded,
          );
        }
        return Column(
          children: [
            for (final item in _consultations)
              row(
                _formattedDate(item['date'] ?? item['createdAt']),
                [
                  item['motif'] ?? 'Consultation',
                  'Médecin : ${_relatedName(item['medecin'])}',
                  'Établissement : ${_relatedName(item['clinique'])}',
                  'Diagnostic : ${item['diagnostic'] ?? 'Non renseigné'}',
                  if ((item['notes'] ?? '').toString().trim().isNotEmpty)
                    'Notes : ${item['notes']}',
                  if (item['constantes'] is Map &&
                      (item['constantes'] as Map).isNotEmpty)
                    'Constantes : ${(item['constantes'] as Map).entries.map((entry) => '${entry.key}: ${entry.value}').join(', ')}',
                ].join(' · '),
                icon: Icons.medical_services_rounded,
              ),
          ],
        );
      case 2:
        final medicines = _activePrescriptionMedicines();
        if (medicines.isEmpty) {
          return row(
            'Aucun',
            'Aucun médicament actif dans ce dossier.',
            icon: Icons.medication_rounded,
          );
        }
        return Column(
          children: [
            for (final med in medicines) ...[
              _PrescriptionRow(
                name: med['nom']?.toString() ?? 'Médicament',
                posologie: med['dose']?.toString() ?? '—',
                interval: med['frequence']?.toString() ?? '—',
                duration: med['duree']?.toString() ?? '—',
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      case 3:
        if (_ordonnances.isEmpty) {
          return row(
            'Aucune',
            'Aucune ordonnance enregistrée dans ce dossier.',
            icon: Icons.receipt_long_rounded,
          );
        }
        return Column(
          children: [
            for (final item in _ordonnances)
              row(
                _formattedDate(item['emiseAt'] ?? item['createdAt']),
                '${item['status'] ?? 'active'} · ${(item['medicaments'] as List? ?? const []).length} médicament(s)',
                icon: Icons.receipt_long_rounded,
              ),
          ],
        );
      case 4:
        if (_analyses.isEmpty) {
          return row(
            'Aucune',
            'Aucune analyse enregistrée dans ce dossier.',
            icon: Icons.biotech_rounded,
          );
        }
        return Column(
          children: [
            for (final item in _analyses)
              row(
                '${item['type'] ?? 'Analyse'} · ${_formattedDate(item['date'] ?? item['createdAt'])}',
                ((item['resultats'] as List? ?? const []).isEmpty)
                    ? 'Résultat en attente'
                    : (item['resultats'] as List)
                          .map(
                            (result) =>
                                '${result['parametre'] ?? 'Paramètre'}: ${result['valeur'] ?? '—'} ${result['unite'] ?? ''} · statut: ${_analysisStatusLabel(result['statut']?.toString())}'
                                    .trim(),
                          )
                          .join(' · '),
                icon: Icons.biotech_rounded,
              ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildOrdonnances() {
    if (_filteredOrdonnances.isEmpty) {
      return _emptyState('Aucune ordonnance disponible pour ce dossier.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _historyPeriodControls(),
          Text(
            'Ordonnances',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 20),
          for (final item in _filteredOrdonnances)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PrescriptionDetailsCard(
                ordonnance: item,
                formattedDate: _formattedDate,
                medicaments: (item['medicaments'] as List? ?? const [])
                    .whereType<Map>()
                    .map((medicine) => Map<String, dynamic>.from(medicine))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyses() {
    if (_filteredAnalyses.isEmpty) {
      return _emptyState(
        'Aucune analyse ou résultat de consultation disponible.',
      );
    }

    final items = <_AnalysisItem>[];
    for (final item in _filteredAnalyses) {
      final resultats = item['resultats'] as List? ?? const [];
      if (resultats.isEmpty) {
        items.add(
          _AnalysisItem(
            label:
                '${item['type'] ?? 'Analyse'} · ${_formattedDate(item['date'])}',
            value: 'Résultat en attente',
            status: 'Normal',
          ),
        );
      } else {
        for (final result in resultats) {
          items.add(
            _AnalysisItem(
              label:
                  '${item['type'] ?? 'Analyse'} · ${result['parametre'] ?? 'Paramètre'} · ${_relatedName(item['clinique'])}',
              value: '${result['valeur'] ?? '—'} ${result['unite'] ?? ''}'
                  .trim(),
              status: _analysisStatusLabel(result['statut']?.toString()),
            ),
          );
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _historyPeriodControls(),
          Text(
            'Analyses',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 20),
          _AnalysisCard(title: 'Résultats du dossier', items: items),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    final qrValue = (_patient['qrToken'] ?? '').toString();
    final dossierNumber = (_patient['dossierNumber'] ?? '—').toString();
    final allergies = ((_patient['allergies'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Carte QR patient',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.s100),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.g50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.qr_code_rounded,
                        color: AppColors.g700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dossier $dossierNumber',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.g700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: QrDisplayWidget(
                    qrToken: qrValue.isNotEmpty ? qrValue : dossierNumber,
                    dossierId: dossierNumber,
                    groupeSanguin: _patient['groupeSanguin']?.toString(),
                    allergies: allergies,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.g50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.s100),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        size: 18,
                        color: AppColors.g700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          qrValue.isNotEmpty
                              ? 'QR sécurisé disponible hors ligne.'
                              : 'Numéro de dossier disponible hors ligne.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.s700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Montrer ce QR au médecin ou au pharmacien. Il permet d’ouvrir le dossier et vérifier les informations du patient.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.g600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _revokePatientQr,
                      icon: const Icon(Icons.block_rounded, size: 16),
                      label: const Text('Révoquer'),
                    ),
                    FilledButton.icon(
                      onPressed: _rotatePatientQr,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Nouveau QR'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.g700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _revokePatientQr() async {
    final patientId = ref.read(authStateProvider).valueOrNull?.patientId;
    if (patientId == null || patientId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Révoquer le QR ?'),
        content: const Text(
          'Le QR actuel ne pourra plus être utilisé par un professionnel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Révoquer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(apiServiceProvider).revokePatientQr(patientId);
      await _loadPatientData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR révoqué.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _rotatePatientQr() async {
    final patientId = ref.read(authStateProvider).valueOrNull?.patientId;
    if (patientId == null || patientId.isEmpty) return;
    try {
      await ref.read(apiServiceProvider).rotatePatientQr(patientId);
      await _loadPatientData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nouveau QR généré.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget _buildPharmacyHistory() {
    if (_filteredDelivrances.isEmpty) {
      return _emptyState('Aucun passage en pharmacie enregistré.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _historyPeriodControls(),
          Text(
            'Passages en pharmacie',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 20),
          for (final item in _filteredDelivrances)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.s100),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_pharmacy_rounded,
                        color: AppColors.g700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pharmacyName(item['pharmacie']),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.s800,
                          ),
                        ),
                      ),
                      _StatusPill(
                        label:
                            (item['status'] ?? 'delivered').toString() ==
                                'partial'
                            ? 'Partiel'
                            : 'Délivré',
                        tone:
                            (item['status'] ?? 'delivered').toString() ==
                                'partial'
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formattedDate(item['date']),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.s500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final med
                      in ((item['medicamentsDelivres'] as List?) ??
                          (item['medicaments'] as List?) ??
                          const []))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            med['delivre'] == false
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded,
                            size: 15,
                            color: med['delivre'] == false
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${med['nom'] ?? 'Médicament'}${med['delivre'] == false ? ' · ${med['raisonNonDelivrance'] ?? 'non délivré'}' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.s700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReminders() {
    final activeOrdonnances = _ordonnances.where(_isOrdonnanceActive).toList();
    if (activeOrdonnances.isEmpty) {
      return _emptyState(
        'Aucun rappel actif. Les rappels se créent depuis les ordonnances actives.',
      );
    }

    final reminders = <Map<String, String>>[];
    for (final ordonnance in activeOrdonnances) {
      for (final med in (ordonnance['medicaments'] as List? ?? const [])) {
        reminders.add({
          'name': (med['nom'] ?? 'Médicament').toString(),
          'dose': (med['dose'] ?? '').toString(),
          'time': (med['frequence'] ?? 'Selon ordonnance').toString(),
          'duration': (med['duree'] ?? '').toString(),
        });
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rappels de prise',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 20),
          for (final reminder in reminders)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.s100),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.g50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.g700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder['name']!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.s800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${reminder['dose']} · ${reminder['time']} · ${reminder['duration']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.s500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: true,
                    onChanged: (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rappel mis à jour en local.'),
                        ),
                      );
                    },
                    activeThumbColor: AppColors.g700,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DossierInfoPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _DossierInfoPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.g50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.g700),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.g700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color tone;

  const _StatusPill({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  final String name;
  final String posologie;
  final String interval;
  final String duration;

  const _PrescriptionRow({
    required this.name,
    required this.posologie,
    required this.interval,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.s100),
        color: AppColors.g50,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.s100),
            ),
            child: const Icon(
              Icons.medication_rounded,
              size: 16,
              color: AppColors.g700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniField(value: posologie),
                    _MiniField(value: interval),
                    _MiniField(value: duration),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  final String value;

  const _MiniField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.s200),
        color: Colors.white,
      ),
      child: Text(
        value,
        style: GoogleFonts.inter(fontSize: 10, color: AppColors.g700),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color tint;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.s100),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.g700),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.g700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.s500),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.s100),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.g700),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.s500),
          ),
        ],
      ),
    );
  }
}

class _MedicineRow extends StatelessWidget {
  final String name;
  final String dose;

  const _MedicineRow({required this.name, required this.dose});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.g50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.medication_rounded,
            size: 14,
            color: AppColors.g700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.s800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dose,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrescriptionDetailsCard extends StatelessWidget {
  final Map<String, dynamic> ordonnance;
  final String Function(dynamic) formattedDate;
  final List<Map<String, dynamic>> medicaments;

  const _PrescriptionDetailsCard({
    required this.ordonnance,
    required this.formattedDate,
    required this.medicaments,
  });

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Non renseigné' : text;
  }

  String _nestedName(dynamic value, {String fallback = 'Non renseigné'}) {
    if (value is Map && value['nom'] != null) {
      final name = value['nom'].toString().trim();
      if (name.isNotEmpty) return name;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final status = _value(ordonnance['status']);
    final expireAt = ordonnance['expireAt'];
    final expireDate = expireAt == null
        ? 'Non renseignée'
        : formattedDate(expireAt);
    final doctor = _nestedName(ordonnance['medecin']);
    final clinic = _nestedName(ordonnance['clinique']);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.s100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ordonnance du ${formattedDate(ordonnance['emiseAt'])}',
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.s800,
                  ),
                ),
              ),
              _StatusPill(
                label: status,
                tone: status == 'active'
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _MiniField(value: 'Médecin : $doctor'),
              _MiniField(value: 'Clinique : $clinic'),
              _MiniField(value: 'Expire : $expireDate'),
              _MiniField(
                value:
                    'Validité : ${_value(ordonnance['validiteJours'])} jour(s)',
              ),
              _MiniField(
                value: ordonnance['renouvelable'] == true
                    ? 'Renouvelable'
                    : 'Non renouvelable',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Médicaments prescrits',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.g700,
            ),
          ),
          const SizedBox(height: 8),
          if (medicaments.isEmpty)
            Text(
              'Aucun médicament renseigné.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.s500),
            )
          else
            for (final medicine in medicaments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PrescriptionRow(
                  name: _value(medicine['nom']),
                  posologie: _value(medicine['dose']),
                  interval: _value(medicine['frequence']),
                  duration: _value(medicine['duree']),
                ),
              ),
          if (_value(ordonnance['instructionsGenerales']) !=
              'Non renseigné') ...[
            const SizedBox(height: 8),
            Text(
              'Instructions : ${_value(ordonnance['instructionsGenerales'])}',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.g600),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final String title;
  final List<_AnalysisItem> items;

  const _AnalysisCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.s100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.s500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        item.value,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.s800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(item.status),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.status,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _statusTextColor(item.status),
                          ),
                        ),
                      ),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'Normal':
        return AppColors.successBg;
      case 'Bas':
        return AppColors.dangerBg;
      default:
        return AppColors.warningBg;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'Normal':
        return AppColors.success;
      case 'Bas':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }
}

class _AnalysisItem {
  final String label;
  final String value;
  final String status;

  const _AnalysisItem({
    required this.label,
    required this.value,
    required this.status,
  });
}
