import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/providers/auth_provider.dart';
import 'package:sante/widgets/qr_widgets.dart';
import 'package:sante/widgets/sante_shell.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  int _selectedTabIndex = 0;
  int _dossierTabIndex = 2;
  bool _loading = true;
  Map<String, dynamic> _patient = {};
  List<dynamic> _ordonnances = [];
  List<dynamic> _consultations = [];
  List<dynamic> _analyses = [];
  List<dynamic> _delivrances = [];

  Future<void> _copyPatientPrintSummary() async {
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
      'Ordonnances: ${_ordonnances.length}',
      'Consultations: ${_consultations.length}',
      'Analyses: ${_analyses.length}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dossier prêt : résumé copié pour impression.'),
        backgroundColor: AppColors.g700,
      ),
    );
  }

  void _showDossierDetail(String title, String value) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.syne(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.s800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: AppColors.g700,
              ),
            ),
          ],
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
    final currentUser = ref.read(authStateProvider).valueOrNull;
    final patientId = currentUser?.patientId;

    if (patientId == null || patientId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      final dossier = await api.getPatientDossier(patientId);
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
    } catch (_) {
      setState(() => _loading = false);
    }
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
      final status = (ordonnance['status'] ?? 'active').toString();
      if (status != 'active' && status != 'partial') continue;
      for (final med in (ordonnance['medicaments'] as List? ?? const [])) {
        if (med is Map) medicines.add(Map<String, dynamic>.from(med));
      }
    }
    return medicines;
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
        onTap: () => setState(() => _selectedTabIndex = 6),
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
      headerAction: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.g50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.qr_code_rounded, size: 14, color: AppColors.g700),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
    final activeOrdonnances = _ordonnances
        .where((entry) => (entry['status'] ?? 'active') == 'active')
        .toList();

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
                      onPressed: _copyPatientPrintSummary,
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
                '${item['motif'] ?? 'Consultation'} · ${item['diagnostic'] ?? 'Diagnostic non renseigné'}',
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
                                '${result['parametre'] ?? 'Paramètre'}: ${result['valeur'] ?? '—'} ${result['unite'] ?? ''}'
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
    if (_ordonnances.isEmpty) {
      return _emptyState('Aucune ordonnance disponible pour ce dossier.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ordonnances',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 20),
          for (final item in _ordonnances)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PrescriptionCard(
                doctor: 'Médecin',
                date: _formattedDate(item['emiseAt']),
                title: 'Ordonnance ${item['status'] ?? 'active'}',
                meds: _medicamentsFromOrdonnance(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyses() {
    if (_analyses.isEmpty) {
      return _emptyState(
        'Aucune analyse ou résultat de consultation disponible.',
      );
    }

    final items = <_AnalysisItem>[];
    for (final item in _analyses) {
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
                  '${item['type'] ?? 'Analyse'} · ${result['parametre'] ?? 'Paramètre'}',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacyHistory() {
    if (_delivrances.isEmpty) {
      return _emptyState('Aucun passage en pharmacie enregistré.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passages en pharmacie',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 20),
          for (final item in _delivrances)
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
                              '${med['nom'] ?? 'Médicament'}${med['delivre'] == false ? ' · rupture signalée' : ''}',
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
    final activeOrdonnances = _ordonnances
        .where((entry) => (entry['status'] ?? 'active') == 'active')
        .toList();
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

class _PrescriptionCard extends StatelessWidget {
  final String doctor;
  final String date;
  final String title;
  final List<String> meds;

  const _PrescriptionCard({
    required this.doctor,
    required this.date,
    required this.title,
    required this.meds,
  });

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.s800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Active',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$doctor · $date',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
          ),
          const SizedBox(height: 12),
          ...meds.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 12,
                    color: AppColors.g600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.s700,
                      ),
                    ),
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
