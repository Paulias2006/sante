import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/providers/auth_provider.dart';
import 'package:sante/widgets/sante_shell.dart';

class PharmacyDashboardScreen extends ConsumerStatefulWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  ConsumerState<PharmacyDashboardScreen> createState() =>
      _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState
    extends ConsumerState<PharmacyDashboardScreen> {
  int _selectedTabIndex = 0;
  bool _loading = true;
  List<dynamic> _deliveries = [];
  Map<String, dynamic> _stats = {};
  final TextEditingController _qrController = TextEditingController();
  Map<String, dynamic> _scanResult = {};
  bool _scanning = false;
  bool _delivering = false;
  final Map<int, bool> _medicineStock = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.getPharmacyDeliveries(),
        api.getPharmacyStats(),
      ]);
      setState(() {
        _deliveries = results[0] as List<dynamic>;
        _stats = Map<String, dynamic>.from(results[1] as Map<String, dynamic>);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _scanCode() async {
    final qr = _qrController.text.trim();
    if (qr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez un QR code valide')),
      );
      return;
    }

    setState(() => _scanning = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.scanOrdonnance(qr);
      setState(() {
        _scanResult = Map<String, dynamic>.from(result);
        _medicineStock
          ..clear()
          ..addEntries(
            _medicineListForScan().asMap().entries.map(
              (entry) => MapEntry(entry.key, true),
            ),
          );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _confirmDelivery() async {
    final ordonnanceId = _scanResult['ordonnance']?['_id'];
    if (ordonnanceId == null) return;

    final meds = <Map<String, dynamic>>[];
    final ordonnanceMeds =
        (_scanResult['ordonnance']?['medicaments'] as List? ?? const []);
    for (var index = 0; index < ordonnanceMeds.length; index++) {
      final item = ordonnanceMeds[index];
      if (item is Map) {
        final inStock = _medicineStock[index] ?? true;
        meds.add({
          'nom': item['nom'] ?? 'Médicament',
          'delivre': inStock,
          'raisonNonDelivrance': inStock ? '' : 'Rupture de stock pharmacie',
        });
      }
    }

    setState(() => _delivering = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.deliverOrdonnance(ordonnanceId.toString(), meds);
      _qrController.clear();
      setState(() {
        _scanResult = {};
        _medicineStock.clear();
      });
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            meds.any((item) => item['delivre'] == false)
                ? 'Délivrance partielle confirmée dans le dossier.'
                : 'Délivrance complète confirmée dans le dossier.',
          ),
          backgroundColor: AppColors.g700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _delivering = false);
      }
    }
  }

  List<Map<String, dynamic>> _medicineListForScan() {
    final items =
        _scanResult['ordonnance']?['medicaments'] as List? ?? const [];
    return items.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> _openCameraScanner() async {
    var captured = false;
    final code = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 520,
          height: 560,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Scanner QR ordonnance',
                        style: GoogleFonts.syne(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.s800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    onDetect: (capture) {
                      if (captured) return;
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final rawValue = barcodes.first.rawValue;
                      if (rawValue == null || rawValue.trim().isEmpty) return;
                      captured = true;
                      Navigator.of(context).pop(rawValue.trim());
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Si la caméra est bloquée par le navigateur, collez le token QR réel ou le numéro de dossier dans le champ manuel.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.s500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (code == null || code.isEmpty) return;
    _qrController.text = code;
    await _scanCode();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final userName = currentUser?.fullName.trim().isNotEmpty == true
        ? currentUser!.fullName
        : 'Pharmacie';

    final navItems = [
      SanteDashboardNavItem(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Scanner',
        selected: _selectedTabIndex == 0,
        onTap: () => setState(() => _selectedTabIndex = 0),
      ),
      SanteDashboardNavItem(
        icon: Icons.local_shipping_rounded,
        label: 'Délivrances',
        selected: _selectedTabIndex == 1,
        onTap: () => setState(() => _selectedTabIndex = 1),
      ),
      SanteDashboardNavItem(
        icon: Icons.bar_chart_rounded,
        label: 'Statistiques',
        selected: _selectedTabIndex == 2,
        onTap: () => setState(() => _selectedTabIndex = 2),
      ),
    ];

    return SanteDashboardShell(
      title: 'Pharmacie',
      subtitle: '— gestion des ordonnances',
      navItems: navItems,
      userName: userName,
      userRole: 'Pharmacien',
      headerAction: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.g50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: AppColors.g700,
            ),
            const SizedBox(width: 6),
            Text(
              'Système connecté',
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
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _scannerView();
      case 1:
        return _deliveriesView();
      default:
        return _statsView();
    }
  }

  Widget _scannerView() {
    final patient =
        _scanResult['patient'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final ordonnance =
        _scanResult['ordonnance'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final meds = _medicineListForScan();
    final allergies = (patient['allergies'] as List? ?? const [])
        .map((e) => e.toString())
        .join(' · ');
    final total = _stats['count'] ?? _deliveries.length;
    final valid = _deliveries
        .where((item) => item['status'] == 'delivered')
        .length;
    final partial = _deliveries
        .where((item) => item['status'] == 'partial')
        .length;
    final invalid = _stats['invalid'] ?? 0;
    final recentDeliveries = _deliveries.take(3).toList();
    final compact = MediaQuery.sizeOf(context).width < 720;
    final statItems = [
      _MiniStat(value: '$total', label: 'Total traitées', tint: AppColors.g100),
      _MiniStat(value: '$valid', label: 'Complètes', tint: AppColors.successBg),
      _MiniStat(
        value: '$partial',
        label: 'Partielles',
        tint: AppColors.warningBg,
      ),
      _MiniStat(
        value: '$invalid',
        label: 'QR invalides',
        tint: AppColors.dangerBg,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 540 ? 2 : 4;
              final itemWidth =
                  (constraints.maxWidth - (12 * (columns - 1))) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: statItems
                    .map((item) => SizedBox(width: itemWidth, child: item))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: compact ? 760 : constraints.maxWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.s100),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.g50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.g500,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.qr_code_2_rounded,
                                      size: 52,
                                      color: AppColors.g700,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Scanner la carte ou l\'app patient',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.g800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Pointer la caméra vers le QR code',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.g600,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        SizedBox(
                                          width: compact
                                              ? double.infinity
                                              : null,
                                          child: ElevatedButton.icon(
                                            onPressed: _openCameraScanner,
                                            icon: const Icon(
                                              Icons.photo_camera_rounded,
                                              size: 16,
                                            ),
                                            label: const Text('Caméra'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.g600,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: compact
                                              ? double.infinity
                                              : 260,
                                          child: TextField(
                                            controller: _qrController,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'QR ordonnance ou numéro dossier',
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide(
                                                  color: AppColors.s200,
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: compact
                                              ? double.infinity
                                              : null,
                                          child: ElevatedButton.icon(
                                            onPressed: _scanning
                                                ? null
                                                : _scanCode,
                                            icon: _scanning
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.check_rounded,
                                                    size: 16,
                                                  ),
                                            label: const Text('Valider'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.g700,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'DERNIÈRES LIVRAISONS',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.g700,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (recentDeliveries.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.g50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.s100),
                                  ),
                                  child: Text(
                                    'Aucune livraison récente.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.g600,
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: recentDeliveries.map((item) {
                                    final name =
                                        '${item['patient']?['prenom'] ?? ''} ${item['patient']?['nom'] ?? ''}'
                                            .trim();
                                    final time = item['date'] != null
                                        ? DateTime.tryParse(
                                                item['date'].toString(),
                                              )?.toLocal().toString().substring(
                                                11,
                                                16,
                                              ) ??
                                              '?'
                                        : '?';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: AppColors.s100,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors.g800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            time,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: AppColors.g600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 2,
                        child: _scanResult.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: AppColors.s100),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    'Aucune ordonnance scannée',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.g600,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
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
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: AppColors.success,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Ordonnance valide · ${(ordonnance['_id'] ?? 'ID inconnu').toString()}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: AppColors.g700,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              ((patient['prenom'] ?? 'P')
                                                          .toString()
                                                          .substring(0, 1) +
                                                      (patient['nom'] ?? ' ')
                                                          .toString()
                                                          .substring(0, 1))
                                                  .toUpperCase(),
                                              style: GoogleFonts.syne(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${patient['prenom'] ?? ''} ${patient['nom'] ?? ''}'
                                                    .trim(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.g800,
                                                ),
                                              ),
                                              Text(
                                                '${patient['age'] ?? '?'} ans • ${patient['groupeSanguin'] ?? '?'}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: AppColors.g600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${ordonnance['medecin'] ?? 'Médecin'} • ${ordonnance['clinique'] ?? 'Clinique'}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: AppColors.g600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (allergies.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.dangerBg,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 14,
                                              color: AppColors.danger,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'ALLERGIE • $allergies',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.danger,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 18),
                                    Text(
                                      'MÉDICAMENTS À LIVRER',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.g700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ...meds.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final med = entry.value;
                                      final inStock =
                                          _medicineStock[index] ?? true;
                                      return _PharmaMedicineRow(
                                        label:
                                            med['nom']?.toString() ??
                                            'Médicament',
                                        subtitle:
                                            [
                                                  med['dose'],
                                                  med['frequence'],
                                                  med['duree'],
                                                ]
                                                .where(
                                                  (part) =>
                                                      part != null &&
                                                      part
                                                          .toString()
                                                          .trim()
                                                          .isNotEmpty,
                                                )
                                                .join(' • '),
                                        inStock: inStock,
                                        onChanged: (value) => setState(
                                          () => _medicineStock[index] = value,
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _delivering
                                            ? null
                                            : _confirmDelivery,
                                        icon: _delivering
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                              ),
                                        label: const Text(
                                          'Confirmer la livraison',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.g700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _deliveriesView() {
    if (_deliveries.isEmpty) {
      return const Center(child: Text('Aucune délivrance enregistrée.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Délivrances du jour',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.s100),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (final item in _deliveries)
                  _DeliveryRow(
                    name:
                        '${item['patient']?['prenom'] ?? ''} ${item['patient']?['nom'] ?? ''}'
                            .trim(),
                    time: item['date'] != null
                        ? DateTime.tryParse(
                                item['date'].toString(),
                              )?.toLocal().toString().substring(11, 16) ??
                              '—'
                        : '—',
                    status:
                        (item['status'] ?? 'delivered').toString() == 'partial'
                        ? 'Partiel'
                        : 'Délivré',
                    ok: (item['status'] ?? 'delivered').toString() != 'partial',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsView() {
    final deliveredCount = _deliveries
        .where((item) => item['status'] == 'delivered')
        .length;
    final partialCount = _deliveries
        .where((item) => item['status'] == 'partial')
        .length;
    final rate = _deliveries.isEmpty
        ? 0
        : ((deliveredCount / _deliveries.length) * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiques',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MiniStat(
                value: (_stats['count'] ?? _deliveries.length).toString(),
                label: 'Dossiers',
                tint: AppColors.g100,
              ),
              _MiniStat(
                value: '$rate%',
                label: 'Taux',
                tint: AppColors.successBg,
              ),
              _MiniStat(
                value: '$partialCount',
                label: 'Alertes',
                tint: AppColors.warningBg,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color tint;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.tint,
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.g800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.g600),
          ),
        ],
      ),
    );
  }
}

class _PharmaMedicineRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool inStock;
  final ValueChanged<bool> onChanged;

  const _PharmaMedicineRow({
    required this.label,
    required this.subtitle,
    required this.inStock,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.s50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: inStock,
            onChanged: (value) => onChanged(value ?? false),
            activeColor: AppColors.g700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.s800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: inStock ? AppColors.successBg : AppColors.warningBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              inStock ? 'En stock' : 'À réapprovisionner',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: inStock ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  final String name;
  final String time;
  final String status;
  final bool ok;

  const _DeliveryRow({
    required this.name,
    required this.time,
    required this.status,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.s100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.s800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            time,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ok ? AppColors.successBg : AppColors.warningBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: ok ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
