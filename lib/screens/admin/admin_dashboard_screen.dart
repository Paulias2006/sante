import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/providers/auth_provider.dart';
import 'package:sante/widgets/sante_shell.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;

  final Map<String, dynamic> _stats = {
    'totalPatients': 0,
    'totalClinics': 0,
    'totalOrdonnances': 0,
    'totalCartes': 0,
    'pendingClinics': 0,
    'pendingPharmacies': 0,
  };

  List<Map<String, dynamic>> _clinics = [];
  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _cartes = [];
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.getAdminStats(),
        api.getAdminClinics(),
        api.getAdminPharmacies(),
        api.getAdminPatients(),
        api.getAdminCartes(),
        api.getAdminLogs(),
      ]);

      final stats = Map<String, dynamic>.from(
        results[0] as Map<String, dynamic>,
      );
      final clinics = List<Map<String, dynamic>>.from(
        results[1] as List<dynamic>,
      );
      final pharmacies = List<Map<String, dynamic>>.from(
        results[2] as List<dynamic>,
      );
      final patients = List<Map<String, dynamic>>.from(
        results[3] as List<dynamic>,
      );
      final cartes = List<Map<String, dynamic>>.from(
        results[4] as List<dynamic>,
      );
      final logs = List<Map<String, dynamic>>.from(results[5] as List<dynamic>);

      setState(() {
        _stats.clear();
        _stats.addAll(stats);
        _clinics = clinics;
        _pharmacies = pharmacies;
        _patients = patients;
        _cartes = cartes;
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _recordId(Map<String, dynamic> item) {
    return (item['_id'] ?? item['id'] ?? '').toString();
  }

  String _displayDate(dynamic raw) {
    if (raw == null) return '—';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  Future<void> _exportDashboardReport() async {
    final lines = [
      'SantéTogo - Export admin',
      'Date: ${DateTime.now().toIso8601String()}',
      'Patients: ${_stats['totalPatients'] ?? _patients.length}',
      'Cliniques: ${_stats['totalClinics'] ?? _clinics.length}',
      'Pharmacies: ${_pharmacies.length}',
      'Ordonnances: ${_stats['totalOrdonnances'] ?? 0}',
      'Cartes: ${_stats['totalCartes'] ?? _cartes.length}',
      'Cliniques en attente: ${_stats['pendingClinics'] ?? 0}',
      'Pharmacies en attente: ${_stats['pendingPharmacies'] ?? 0}',
      'Logs: ${_logs.length}',
      '',
      'Cliniques',
      ..._clinics.map(
        (item) =>
            '${_clinicName(item)};${item['email'] ?? '—'};${item['status'] ?? item['statut'] ?? '—'}',
      ),
      '',
      'Pharmacies',
      ..._pharmacies.map(
        (item) =>
            '${item['nom'] ?? 'Pharmacie'};${item['email'] ?? '—'};${item['status'] ?? item['statut'] ?? '—'}',
      ),
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: lines));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export admin copié.'),
        backgroundColor: AppColors.g700,
      ),
    );
  }

  String _clinicName(Map<String, dynamic> item) {
    final clinique = item['clinique'];
    if (clinique is Map) {
      return (clinique['nom'] ?? 'Clinique non renseignée').toString();
    }
    return (item['cliniqueNom'] ?? item['nom'] ?? 'Clinique non renseignée')
        .toString();
  }

  int _cardCount(Map<String, dynamic> item) {
    final explicit = item['nombreCartes'] ?? item['nbCartes'] ?? item['total'];
    if (explicit is num) return explicit.toInt();
    if (explicit != null) return int.tryParse(explicit.toString()) ?? 0;
    final patients = item['patients'];
    return patients is List ? patients.length : 0;
  }

  Map<String, dynamic>? _patientFromCard(Map<String, dynamic>? card) {
    final patients = card?['patients'];
    if (patients is List && patients.isNotEmpty) {
      final first = patients.first;
      if (first is Map) return Map<String, dynamic>.from(first);
      final id = first.toString();
      for (final patient in _patients) {
        if (_recordId(patient) == id) return patient;
      }
    }
    return _patients.isNotEmpty ? _patients.first : null;
  }

  String _patientFullName(Map<String, dynamic> patient) {
    final fullName = patient['fullName'];
    if (fullName != null && fullName.toString().trim().isNotEmpty) {
      return fullName.toString();
    }
    return '${patient['prenom'] ?? ''} ${patient['nom'] ?? ''}'.trim();
  }

  void _showInfoDialog(String title, Map<String, dynamic> item) {
    final info = item.map((key, value) => MapEntry(key, value ?? '—'));
    final rows = info.entries
        .map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    entry.key,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.s500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.s800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.syne(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: Column(children: rows)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveClinic(Map<String, dynamic> clinic) async {
    final id = _recordId(clinic);
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’approuver : identifiant introuvable.'),
        ),
      );
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.approveClinique(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clinique approuvée avec succès.')),
      );
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur approbation : ${e.toString()}')),
      );
    }
  }

  Future<void> _rejectClinic(Map<String, dynamic> clinic) async {
    final id = _recordId(clinic);
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de rejeter : identifiant introuvable.'),
        ),
      );
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.rejectClinique(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clinique rejetée.')));
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur rejet : ${e.toString()}')));
    }
  }

  Future<void> _approvePharmacy(Map<String, dynamic> pharmacy) async {
    final id = _recordId(pharmacy);
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’approuver : identifiant introuvable.'),
        ),
      );
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.approvePharmacie(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pharmacie approuvée.')));
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur approbation pharmacie : ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _rejectPharmacy(Map<String, dynamic> pharmacy) async {
    final id = _recordId(pharmacy);
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de rejeter : identifiant introuvable.'),
        ),
      );
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.rejectPharmacie(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pharmacie rejetée.')));
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur rejet pharmacie : ${e.toString()}')),
      );
    }
  }

  Future<void> _updateCardStatus(
    Map<String, dynamic> carte,
    String status,
  ) async {
    final id = _recordId(carte);
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Commande introuvable.')));
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateCarteStatus(id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut mis à jour : ${_formatStatus(status)}')),
      );
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur mise à jour : ${e.toString()}')),
      );
    }
  }

  List<Map<String, dynamic>> get _hospitals {
    return _clinics
        .where(
          (item) =>
              (item['type'] as String?) == 'hopital' ||
              (item['type'] as String?) == 'centre_sante',
        )
        .toList();
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'approved':
        return 'Approuvé';
      case 'pending':
        return 'En attente';
      case 'suspended':
        return 'Suspendu';
      case 'delivered':
        return 'Livrée';
      case 'printing':
        return 'Impression';
      case 'shipped':
        return 'Expédiée';
      default:
        return status ?? 'Inconnu';
    }
  }

  Widget _buildStatusChip(String? status, {Color? overrideColor}) {
    final color =
        overrideColor ??
        switch (status) {
          'approved' => AppColors.successBg,
          'pending' => AppColors.warningBg,
          'suspended' => AppColors.dangerBg,
          'delivered' => AppColors.successBg,
          'printing' => AppColors.warningBg,
          'shipped' => AppColors.g50,
          _ => AppColors.g50,
        };

    final textColor = overrideColor != null
        ? Colors.white
        : switch (status) {
            'approved' => AppColors.success,
            'pending' => AppColors.warning,
            'suspended' => AppColors.danger,
            'delivered' => AppColors.success,
            'printing' => AppColors.warning,
            'shipped' => AppColors.g700,
            _ => AppColors.g700,
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formatStatus(status),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDashboardStats() {
    final statCards = [
      _StatCard(
        label: 'Patients enregistrés',
        value: (_stats['totalPatients'] ?? 0).toString(),
        delta: '${_patients.length} dossiers chargés',
        color: AppColors.g100,
        icon: Icons.people_rounded,
      ),
      _StatCard(
        label: 'Cliniques actives',
        value: (_stats['totalClinics'] ?? 0).toString(),
        delta: '${_stats['pendingClinics'] ?? 0} en attente',
        color: AppColors.g50,
        icon: Icons.local_hospital_rounded,
      ),
      _StatCard(
        label: 'Ordonnances émises',
        value: (_stats['totalOrdonnances'] ?? 0).toString(),
        delta: 'Total backend',
        color: AppColors.g50,
        icon: Icons.assignment_rounded,
      ),
      _StatCard(
        label: 'Cartes produites',
        value: (_stats['totalCartes'] ?? 0).toString(),
        delta:
            '${_cartes.where((item) => (item['status'] ?? '').toString() == 'pending').length} en attente',
        color: AppColors.g50,
        icon: Icons.credit_card_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth < 760;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: statCards
              .map(
                (card) => SizedBox(
                  width: twoColumns
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 36) / 4,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedIndex) {
      case 1:
        return _buildEntityList(
          title: 'Clinique',
          data: _clinics,
          emptyMessage: 'Aucune clinique enregistrée.',
          itemBuilder: (item) => [
            Text(
              (item['nom'] ?? 'Clinique sans nom').toString(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.s800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item['ville'] ?? 'Ville inconnue'} · ${item['type'] ?? 'clinique'}',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
            ),
          ],
        );
      case 2:
        return _buildEntityList(
          title: 'Hôpital',
          data: _hospitals,
          emptyMessage: 'Aucun hôpital ou centre de santé enregistré.',
          itemBuilder: (item) => [
            Text(
              (item['nom'] ?? 'Hôpital sans nom').toString(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.s800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item['ville'] ?? 'Ville inconnue'} · ${item['responsable'] ?? 'Responsable inconnu'}',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
            ),
          ],
        );
      case 3:
        return _buildEntityList(
          title: 'Pharmacies',
          data: _pharmacies,
          emptyMessage: 'Aucune pharmacie enregistrée.',
          actionsBuilder: (item) {
            final status = (item['status'] ?? '').toString();
            if (status != 'pending') return const [];
            return [
              IconButton(
                onPressed: () => _approvePharmacy(item),
                icon: const Icon(Icons.check_rounded, size: 18),
                color: AppColors.success,
                tooltip: 'Approuver',
              ),
              IconButton(
                onPressed: () => _rejectPharmacy(item),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.danger,
                tooltip: 'Rejeter',
              ),
            ];
          },
          itemBuilder: (item) => [
            Text(
              (item['nom'] ?? 'Pharmacie sans nom').toString(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.s800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item['ville'] ?? 'Ville inconnue'} · ${item['telephone'] ?? 'Téléphone non renseigné'}',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
            ),
          ],
        );
      case 4:
        return _buildEntityList(
          title: 'Patients',
          data: _patients,
          emptyMessage: 'Aucun patient dans la base.',
          itemBuilder: (item) => [
            Text(
              '${item['prenom'] ?? ''} ${item['nom'] ?? ''}'.trim().isNotEmpty
                  ? '${item['prenom'] ?? ''} ${item['nom'] ?? ''}'.trim()
                  : 'Patient sans nom',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.s800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dossier ${item['dossierNumber'] ?? '?'} · ${item['telephone'] ?? 'Téléphone non renseigné'}',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
            ),
          ],
        );
      case 5:
        return _buildCartePVCView();
      case 6:
        return _buildEntityList(
          title: 'Journaux',
          data: _logs,
          emptyMessage: 'Aucun journal d\'activité enregistré.',
          itemBuilder: (item) => [
            Text(
              (item['action'] ?? 'Action inconnue').toString(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.s800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item['details'] ?? 'Aucune description'}',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
            ),
          ],
        );
      case 0:
      default:
        final pendingClinics = _clinics
            .where(
              (item) => (item['status'] ?? 'pending').toString() == 'pending',
            )
            .take(2)
            .toList();

        final recentCards = _cartes.take(3).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tableau de bord',
                        style: GoogleFonts.syne(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.g800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vue système global',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.g600,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _exportDashboardReport,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Exporter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.g700,
                      side: const BorderSide(color: AppColors.s200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDashboardStats(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.s100),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: AppColors.g700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cliniques en attente de vérification',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.g800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '— ${pendingClinics.length} dossiers',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.g600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (pendingClinics.isEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.s100),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Aucune clinique en attente.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.g600,
                    ),
                  ),
                ),
              ...pendingClinics.map((clinique) {
                final name = (clinique['nom'] ?? 'Clinique sans nom')
                    .toString();
                final ville = (clinique['ville'] ?? 'Ville inconnue')
                    .toString();
                final type = (clinique['type'] ?? 'centre_sante').toString();
                final status = (clinique['status'] ?? 'pending').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.s100),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.g50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          size: 18,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '© $ville',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.g600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '• ${type == 'hopital' ? 'Hôpital' : 'Centre de santé'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.g600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _approveClinic(clinique),
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                  ),
                                  label: const Text('Approuver'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.g700,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _rejectClinic(clinique),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                  ),
                                  label: const Text('Rejeter'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(
                                      color: AppColors.dangerBorder,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _showInfoDialog(
                                    'Dossier clinique',
                                    clinique,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.g700,
                                    side: const BorderSide(
                                      color: AppColors.s200,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Voir dossier'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status == 'pending'
                              ? 'En attente'
                              : _formatStatus(status),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.s100),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.credit_card_rounded,
                              size: 18,
                              color: AppColors.g700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Commandes de cartes récentes',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 230,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Rechercher clinique...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: AppColors.g50,
                              hintStyle: GoogleFonts.inter(
                                color: AppColors.g600,
                                fontSize: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: AppColors.g600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.g50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'CLINIQUE',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'NB CARTES',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'DATE',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'STATUT',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'ACTION',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (recentCards.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Aucune commande de carte enregistrée.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.g600,
                          ),
                        ),
                      ),
                    ...recentCards.map((item) {
                      final clinicName = _clinicName(item);
                      final nb = _cardCount(item).toString();
                      final date = _displayDate(
                        item['createdAt'] ?? item['date'],
                      );
                      final status = (item['status'] ?? 'pending').toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.s100),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                clinicName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.g800,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                nb,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.g800,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                date,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.g800,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'pending'
                                      ? AppColors.warningBg
                                      : AppColors.g50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status == 'pending'
                                      ? 'En attente'
                                      : _formatStatus(status),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: status == 'pending'
                                        ? AppColors.warning
                                        : AppColors.g700,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _showInfoDialog('Commande carte', item),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.g700,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                    ),
                                    child: const Text('Voir'),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Changer le statut',
                                    onSelected: (value) =>
                                        _updateCardStatus(item, value),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'pending',
                                        child: Text('En attente'),
                                      ),
                                      PopupMenuItem(
                                        value: 'printing',
                                        child: Text('Impression'),
                                      ),
                                      PopupMenuItem(
                                        value: 'shipped',
                                        child: Text('Expédiée'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delivered',
                                        child: Text('Livrée'),
                                      ),
                                    ],
                                    child: const Icon(
                                      Icons.more_horiz_rounded,
                                      size: 18,
                                      color: AppColors.g700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildCartePVCView() {
    final selectedCard = _cartes.isNotEmpty ? _cartes.first : null;
    final patient = _patientFromCard(selectedCard);
    final patientName = patient == null ? '' : _patientFullName(patient);
    final fullName = patientName.isEmpty
        ? 'Aucun patient sélectionné'
        : patientName;
    final dossierNumber = patient?['dossierNumber']?.toString() ?? '—';
    final group = patient?['groupeSanguin']?.toString() ?? '—';
    final birthDate = _displayDate(patient?['dateNaissance']);
    final allergies = (patient?['allergies'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final allergyText = allergies.isEmpty
        ? 'Aucune allergie connue'
        : allergies.join(', ');
    final emergencyPhone =
        patient?['telephoneUrgence']?.toString() ??
        patient?['telephone']?.toString() ??
        '—';
    final qrToken = patient?['qrToken']?.toString() ?? '';
    final clinicName = selectedCard == null ? '—' : _clinicName(selectedCard);
    final cardCount = selectedCard == null ? 0 : _cardCount(selectedCard);
    final cardStatus = selectedCard == null
        ? '—'
        : _formatStatus(selectedCard['status']?.toString() ?? 'pending');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              'Carte physique patient — format bancaire PVC (85.6 × 54 mm)',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'RECTO',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 360,
              height: 220,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A7F67), Color(0xFF0D5C4C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SantéTogo',
                            style: GoogleFonts.syne(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'DOSSIER MÉDICAL NUMÉRIQUE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'PATIENT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fullName,
                    style: GoogleFonts.syne(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Né(e) $birthDate · Groupe $group',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'N° DOSSIER',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dossierNumber,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 66,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Container(
                            width: 50,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: qrToken.isEmpty
                                ? const SizedBox()
                                : QrImageView(
                                    data: qrToken,
                                    padding: EdgeInsets.zero,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'VERSO',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 360,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.s100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.g100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            size: 20,
                            color: AppColors.g700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Infos d\'urgence',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.g800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _InfoLine(
                                icon: Icons.bloodtype_rounded,
                                label: 'Groupe : $group',
                              ),
                              _InfoLine(
                                icon: Icons.warning_amber_rounded,
                                label: 'Allergies : $allergyText',
                              ),
                              _InfoLine(
                                icon: Icons.medical_services_rounded,
                                label: 'Clinique : $clinicName',
                              ),
                              _InfoLine(
                                icon: Icons.phone_rounded,
                                label: 'Urgence : $emergencyPhone',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scanner le QR pour l\'historique complet',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.g700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'sante-togo.com · Valable à vie',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.g600,
                        ),
                      ),
                      Text(
                        dossierNumber,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.g700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 360,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Text(
                selectedCard == null
                    ? 'Aucune commande de carte disponible dans le backend.'
                    : 'Commande backend : $clinicName · $cardCount carte(s) · $cardStatus',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityList({
    required String title,
    required List<Map<String, dynamic>> data,
    required String emptyMessage,
    required List<Widget> Function(Map<String, dynamic> item) itemBuilder,
    List<Widget> Function(Map<String, dynamic> item)? actionsBuilder,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Données provenant de l\'API backend SantéTogo.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.s500),
          ),
          const SizedBox(height: 20),
          if (data.isEmpty)
            _Panel(
              title: title,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    emptyMessage,
                    style: TextStyle(color: AppColors.s400),
                  ),
                ),
              ),
            )
          else
            _Panel(
              title: '$title · ${data.length}',
              child: Column(
                children: data.map((item) {
                  final status = (item['status'] ?? '').toString();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.s100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.g50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            title == 'Pharmacies'
                                ? Icons.local_pharmacy_rounded
                                : title == 'Patients'
                                ? Icons.person_rounded
                                : title == 'Cartes PVC'
                                ? Icons.credit_card_rounded
                                : title == 'Journaux'
                                ? Icons.history_rounded
                                : Icons.local_hospital_rounded,
                            size: 18,
                            color: AppColors.g700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: itemBuilder(item),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (status.isNotEmpty) _buildStatusChip(status),
                        const SizedBox(width: 8),
                        if (actionsBuilder != null) ...actionsBuilder(item),
                        IconButton(
                          onPressed: () => _showInfoDialog(title, item),
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          color: AppColors.g700,
                          tooltip: 'Voir le dossier',
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = [
      SanteDashboardNavItem(
        icon: Icons.grid_view_rounded,
        label: 'Tableau de bord',
        selected: _selectedIndex == 0,
        onTap: () => setState(() => _selectedIndex = 0),
      ),
      SanteDashboardNavItem(
        icon: Icons.local_hospital_rounded,
        label: 'Clinique',
        selected: _selectedIndex == 1,
        onTap: () => setState(() => _selectedIndex = 1),
      ),
      SanteDashboardNavItem(
        icon: Icons.local_hospital_rounded,
        label: 'Hôpital',
        selected: _selectedIndex == 2,
        onTap: () => setState(() => _selectedIndex = 2),
      ),
      SanteDashboardNavItem(
        icon: Icons.local_pharmacy_rounded,
        label: 'Pharmacies',
        selected: _selectedIndex == 3,
        onTap: () => setState(() => _selectedIndex = 3),
      ),
      SanteDashboardNavItem(
        icon: Icons.people_alt_rounded,
        label: 'Patients',
        selected: _selectedIndex == 4,
        onTap: () => setState(() => _selectedIndex = 4),
      ),
      SanteDashboardNavItem(
        icon: Icons.credit_card_rounded,
        label: 'Cartes PVC',
        selected: _selectedIndex == 5,
        onTap: () => setState(() => _selectedIndex = 5),
      ),
      SanteDashboardNavItem(
        icon: Icons.history_rounded,
        label: 'Journaux',
        selected: _selectedIndex == 6,
        onTap: () => setState(() => _selectedIndex = 6),
      ),
    ];

    final compactHeader = MediaQuery.sizeOf(context).width < 720;
    final topAction = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compactHeader) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.g50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: AppColors.g600, size: 8),
                const SizedBox(width: 6),
                Text(
                  'Système actif',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.g700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (compactHeader)
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.g700),
            tooltip: 'Rafraîchir',
          )
        else
          ElevatedButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Rafraîchir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.g600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );

    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final userName = currentUser?.fullName.trim().isNotEmpty == true
        ? currentUser!.fullName
        : 'Admin';
    final userRole = switch (currentUser?.role.toLowerCase()) {
      'admin' => 'Administrateur',
      'medecin' => 'Médecin',
      'secretaire' => 'Secrétaire',
      'pharmacien' => 'Pharmacien',
      'patient' => 'Patient',
      _ => 'Fondateur',
    };

    return SanteDashboardShell(
      title: 'Tableau de bord',
      subtitle: '— vue d\'ensemble santé',
      navItems: navItems,
      userName: userName,
      userRole: userRole,
      headerAction: topAction,
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 42,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Impossible de charger les données backend.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.s800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.s500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDashboard,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildSectionContent();
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.s100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.g700),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.s500),
          ),
          const SizedBox(height: 4),
          Text(
            delta,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: AppColors.g600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.s100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.s800,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.s100),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.g700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.g700),
            ),
          ),
        ],
      ),
    );
  }
}
