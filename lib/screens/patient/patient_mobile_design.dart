import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/services/api_service.dart';
import 'package:sante/services/biometric_service.dart';
import 'package:sante/services/notification_service.dart';
import 'package:sante/widgets/sante_shell.dart';

class PatientMobileExperience extends StatefulWidget {
  final Map<String, dynamic> patient;
  final List<dynamic> ordonnances;
  final List<dynamic> consultations;
  final List<dynamic> analyses;
  final List<dynamic> delivrances;
  final List<dynamic> cardOrders;
  final String userName;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRotateQr;
  final Future<void> Function() onRevokeQr;
  final Future<void> Function() onShareQr;
  final Future<void> Function() onOrderCard;
  final Future<void> Function() onChangePassword;
  final Future<void> Function() onLogout;
  final bool biometricEnabled;
  final bool notificationsEnabled;

  const PatientMobileExperience({
    super.key,
    required this.patient,
    required this.ordonnances,
    required this.consultations,
    required this.analyses,
    required this.delivrances,
    required this.cardOrders,
    required this.userName,
    required this.onRefresh,
    required this.onRotateQr,
    required this.onRevokeQr,
    required this.onShareQr,
    required this.onOrderCard,
    required this.onChangePassword,
    required this.onLogout,
    required this.biometricEnabled,
    required this.notificationsEnabled,
  });

  @override
  State<PatientMobileExperience> createState() =>
      _PatientMobileExperienceState();
}

class _PatientMobileExperienceState extends State<PatientMobileExperience>
    with SingleTickerProviderStateMixin {
  String _page = 'home';
  String _directoryKind = 'cliniques';
  String? _directoryDetailKind;
  Map<String, dynamic>? _selectedDirectoryItem;
  String? _documentDetailType;
  Map<String, dynamic>? _selectedDocument;
  Map<String, dynamic>? _scannedPatient;
  List<Map<String, dynamic>> _directoryItems = [];
  bool _directoryLoading = false;
  String? _directoryError;
  bool _scanBusy = false;
  late bool _biometricEnabled;
  late bool _notificationsEnabled;
  final TextEditingController _directorySearchController =
      TextEditingController();
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _biometricEnabled = widget.biometricEnabled;
    _notificationsEnabled = widget.notificationsEnabled;
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _directorySearchController.dispose();
    super.dispose();
  }

  String get _name =>
      widget.userName.trim().isEmpty ? 'Patient' : widget.userName;
  String get _dossier => (widget.patient['dossierNumber'] ?? '—').toString();
  String get _qrValue =>
      (widget.patient['qrToken'] ?? widget.patient['dossierNumber'] ?? '')
          .toString();

  List<String> get _allergies =>
      ((widget.patient['allergies'] as List?) ?? const [])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList();

  void _go(String page) => setState(() => _page = page);

  Future<void> _openDirectory(String kind) async {
    setState(() {
      _directoryKind = kind;
      _directoryDetailKind = null;
      _selectedDirectoryItem = null;
      _directorySearchController.clear();
      _page = 'directory';
    });
    await _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _directoryLoading = true;
      _directoryError = null;
    });
    try {
      final items = await ApiService().getPatientDirectory(
        _directoryKind,
        search: _directorySearchController.text,
      );
      if (!mounted) return;
      setState(() => _directoryItems = items);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _directoryItems = [];
        _directoryError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _directoryLoading = false);
    }
  }

  Future<void> _handleScan(String code) async {
    if (_scanBusy) return;
    setState(() => _scanBusy = true);
    try {
      final result = await ApiService().getPatientByQrToken(code);
      if (!mounted) return;
      setState(() {
        _scannedPatient = result;
        _scanBusy = false;
        _page = 'scan_result';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _scanBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst(
              'Exception: ',
              'QR invalide ou accès non autorisé',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _setBiometric(bool enabled) async {
    final result = await BiometricService.instance.setEnabled(enabled);
    if (!mounted) return;
    if (!result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La biométrie n’est pas disponible sur cet appareil.'),
        ),
      );
      return;
    }
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _setNotifications(bool enabled) async {
    try {
      if (enabled) {
        final granted = await NotificationService.instance.requestPermission();
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Autorisation des notifications refusée.'),
            ),
          );
          return;
        }
      }
      await ApiService().updateMyProfile({'notificationsEnabled': enabled});
      if (!mounted) return;
      setState(() => _notificationsEnabled = enabled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Notifications activées.' : 'Notifications désactivées.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openHelp() async {
    final uri = Uri.parse('tel:93014749');
    if (await launchUrl(uri)) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assistance SantéTogo : 93014749')),
    );
  }

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
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(key: ValueKey(_page), child: _buildPage()),
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openHelp,
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
        tooltip: 'Assistance',
        child: const Icon(Icons.headset_mic_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case 'qr':
        return _buildQrPage();
      case 'scanner':
        return _buildScannerPage();
      case 'scan_result':
        return _buildScanResultPage();
      case 'health':
        return _buildHealthPage();
      case 'documents':
        return _buildDocumentsPage();
      case 'prescriptions':
        return _buildPrescriptionsPage();
      case 'analyses':
        return _buildAnalysesPage();
      case 'document_detail':
        return _buildDocumentDetailPage();
      case 'statistics':
        return _buildHistoryPage();
      case 'notifications':
        return _buildNotificationsPage();
      case 'directory':
        return _directoryDetailKind == null
            ? _buildDirectoryPage()
            : _buildDirectoryDetailPage();
      case 'settings':
        return _buildSettingsPage();
      case 'profile':
        return _buildProfilePage();
      case 'services':
        return _buildServicesPage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHeader({
    required String title,
    String? subtitle,
    bool dark = false,
    VoidCallback? onBack,
  }) {
    final foreground = dark ? Colors.white : AppColors.g800;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: foreground,
              tooltip: 'Retour',
            )
          else
            const SanteBrandLogo(
              emblemSize: 36,
              titleFontSize: 16,
              withWordmark: true,
              wordmarkWidth: 156,
            ),
          if (onBack != null) ...[
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _titleStyle(20, foreground)),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: _bodyStyle(12, foreground.withValues(alpha: .72)),
                    ),
                ],
              ),
            ),
          ] else ...[
            const Spacer(),
            IconButton(
              onPressed: () => _go('notifications'),
              icon: const Icon(Icons.notifications_none_rounded),
              color: AppColors.g700,
              tooltip: 'Notifications',
            ),
            _avatar(40),
          ],
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    final activeTreatments = widget.ordonnances
        .where((item) => (item['status'] ?? 'active').toString() == 'active')
        .length;
    final greeting = _name.split(' ').first;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _introController, curve: Curves.easeOut),
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppColors.g700,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          children: [
            _buildHeader(title: 'Accueil'),
            _buildHeroCard(greeting),
            const SizedBox(height: 16),
            _buildServiceGrid(),
            const SizedBox(height: 16),
            _buildScanBanner(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    '${widget.consultations.length}',
                    'Consultations',
                    AppColors.g100,
                    Icons.groups_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statCard(
                    '${widget.ordonnances.length}',
                    'Ordonnances',
                    AppColors.blueBg,
                    Icons.medication_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statCard(
                    '$activeTreatments',
                    'Traitements',
                    AppColors.warningBg,
                    Icons.favorite_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionHeading('Mes informations', onTap: () => _go('profile')),
            const SizedBox(height: 8),
            _buildInfoGrid(),
            const SizedBox(height: 12),
            _buildPrivacyBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(String greeting) {
    return Container(
      height: 202,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF07594D), Color(0xFF0D9A7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.g700.withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -38,
            child: _heroCircle(170, Colors.white.withValues(alpha: .08)),
          ),
          Positioned(right: 22, top: 14, child: _healthPill()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour 👋',
                  style: _bodyStyle(13, Colors.white.withValues(alpha: .82)),
                ),
                const SizedBox(height: 4),
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _titleStyle(25, Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Votre dossier médical, toujours\navec vous.',
                  style: _bodyStyle(
                    12,
                    Colors.white.withValues(alpha: .82),
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _go('profile'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Voir mon profil'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF19A98D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(right: 22, bottom: 18, child: _miniPatientCard()),
        ],
      ),
    );
  }

  Widget _heroCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _healthPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.favorite_rounded, size: 15, color: AppColors.g600),
        const SizedBox(width: 6),
        Text(
          'En bonne santé',
          style: _bodyStyle(10, AppColors.g700, weight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _miniPatientCard() => Transform.rotate(
    angle: -.12,
    child: Container(
      width: 122,
      height: 78,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          _avatar(26, background: AppColors.g100),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CARTE PATIENT',
                  style: _bodyStyle(6, AppColors.g700, weight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 35,
                  height: 35,
                  child: QrImageView(
                    data: _qrValue.isEmpty ? _dossier : _qrValue,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.local_hospital_rounded,
            color: AppColors.g500,
            size: 22,
          ),
        ],
      ),
    ),
  );

  Widget _buildServiceGrid() => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
    decoration: _surfaceDecoration(),
    child: Row(
      children: [
        _serviceItem(
          Icons.local_hospital_rounded,
          'Cliniques &\nHôpitaux',
          AppColors.g600,
          () => _openDirectory('cliniques'),
        ),
        _serviceItem(
          Icons.medical_services_rounded,
          'Médecins',
          AppColors.blue,
          () => _openDirectory('medecins'),
        ),
        _serviceItem(
          Icons.local_pharmacy_rounded,
          'Pharmacies',
          const Color(0xFF8B4EDB),
          () => _openDirectory('pharmacies'),
        ),
        _serviceItem(
          Icons.receipt_long_rounded,
          'Mes ordonnances',
          const Color(0xFFE69A10),
          () => _go('prescriptions'),
        ),
      ],
    ),
  );

  Widget _serviceItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: _bodyStyle(
              10,
              AppColors.s800,
              weight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text('Voir', style: _bodyStyle(9, AppColors.s500)),
        ],
      ),
    ),
  );

  Widget _buildScanBanner() => Container(
    height: 176,
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFE0F8F1), Color(0xFFF5FFFC)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.g200),
    ),
    child: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tag('⚡ Accès rapide', AppColors.g100, AppColors.g700),
            const SizedBox(height: 8),
            Text(
              'Scannez votre\ncarte patient',
              style: _titleStyle(20, AppColors.g900, height: 1.08),
            ),
            const SizedBox(height: 8),
            Text(
              'Accédez instantanément à vos\ninformations médicales.',
              style: _bodyStyle(11, AppColors.s600, height: 1.35),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _go('scanner'),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
              label: const Text('Scanner maintenant'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.g700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: -5,
          bottom: -14,
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: QrImageView(
                data: _qrValue.isEmpty ? _dossier : _qrValue,
                size: 88,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _statCard(String value, String label, Color tint, IconData icon) =>
      Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: AppColors.g700),
            const SizedBox(height: 8),
            Text(value, style: _titleStyle(19, AppColors.g900)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(9, AppColors.s600),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 11,
                  color: AppColors.success,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    'En activité',
                    style: _bodyStyle(
                      8,
                      AppColors.success,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _sectionHeading(String title, {VoidCallback? onTap}) => Row(
    children: [
      Expanded(child: Text(title, style: _titleStyle(16, AppColors.g900))),
      if (onTap != null)
        TextButton(
          onPressed: onTap,
          child: Text(
            'Tout voir',
            style: _bodyStyle(11, AppColors.g700, weight: FontWeight.w700),
          ),
        ),
    ],
  );

  Widget _buildInfoGrid() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _infoTile(
              Icons.person_rounded,
              'Mon profil',
              'Informations personnelles',
              AppColors.g100,
              () => _go('profile'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _infoTile(
              Icons.receipt_long_rounded,
              'Mes ordonnances',
              '${widget.ordonnances.length} prescription(s)',
              const Color(0xFFF0E8FF),
              () => _go('documents'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _infoTile(
              Icons.medical_services_rounded,
              'Mes traitements',
              'En cours et à venir',
              const Color(0xFFFFECEA),
              () => _go('health'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _infoTile(
              Icons.bar_chart_rounded,
              'Mes antécédents',
              'Voir mon historique',
              AppColors.blueBg,
              () => _go('statistics'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _infoTile(
    IconData icon,
    String title,
    String subtitle,
    Color tint,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: _surfaceDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.g700, size: 19),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    11,
                    AppColors.s800,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(9, AppColors.s500, height: 1.2),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.s400,
          ),
        ],
      ),
    ),
  );

  Widget _buildPrivacyBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.g100,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: const BoxDecoration(
            color: AppColors.g700,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre confidentialité est notre engagement',
                style: _bodyStyle(10, AppColors.g800, weight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                'Vos données sont sécurisées et accessibles uniquement aux professionnels autorisés.',
                style: _bodyStyle(9, AppColors.s600, height: 1.25),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.g600),
      ],
    ),
  );

  Widget _buildQrPage() => Container(
    color: const Color(0xFFE9F8F4),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          decoration: const BoxDecoration(
            color: AppColors.g800,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
          ),
          child: Column(
            children: [
              _buildHeader(
                title: 'Mon QR Code santé',
                subtitle:
                    'Accédez rapidement à vos informations médicales en toute sécurité.',
                dark: true,
                onBack: () => _go('home'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _tag('✓ Sécurisé', AppColors.g600, Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 112),
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Column(
                children: [
                  _buildQrIdentityCard(),
                  const SizedBox(height: 12),
                  _noticeCard(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _go('scanner'),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scanner mon QR code'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.g700,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _qrAction(
                          Icons.refresh_rounded,
                          'Régénérer le QR',
                          'Nouveau code',
                          widget.onRotateQr,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _qrAction(
                          Icons.share_rounded,
                          'Partager',
                          'Par lien sécurisé',
                          widget.onShareQr,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _qrAction(
                          Icons.visibility_rounded,
                          'Voir les accès',
                          'Historique et autorisations',
                          () => _go('statistics'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildQrIdentityCard() => Container(
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
    decoration: _surfaceDecoration(radius: 24),
    child: Column(
      children: [
        Row(
          children: [
            _avatar(52, background: AppColors.g100),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name, style: _titleStyle(20, AppColors.g900)),
                  const SizedBox(height: 4),
                  _tag('● Patient actif', AppColors.g100, AppColors.g700),
                  const SizedBox(height: 4),
                  Text(
                    'Dossier $_dossier',
                    style: _bodyStyle(11, AppColors.s500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.s600),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5FFFC),
            border: Border.all(color: AppColors.g200),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(_dossier, style: _titleStyle(16, AppColors.g700)),
              const SizedBox(height: 8),
              QrImageView(
                data: _qrValue.isEmpty ? _dossier : _qrValue,
                size: 190,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 10),
              _tag(
                '✓ QR sécurisé · Accès temporaire',
                AppColors.g100,
                AppColors.g700,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _noticeCard() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFDDF8F1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.verified_user_rounded,
          color: AppColors.g700,
          size: 28,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre QR code est prêt',
                style: _bodyStyle(12, AppColors.g800, weight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                'Il permet aux professionnels autorisés d’accéder à votre dossier médical.',
                style: _bodyStyle(10, AppColors.s600, height: 1.25),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.g700),
      ],
    ),
  );

  Widget _qrAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 88,
      padding: const EdgeInsets.all(8),
      decoration: _surfaceDecoration(radius: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.g700, size: 20),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(10, AppColors.s800, weight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(8, AppColors.s500),
          ),
        ],
      ),
    ),
  );

  Widget _buildScannerPage() => Column(
    children: [
      _buildHeader(
        title: 'Scanner une carte',
        subtitle: 'Cadrez le QR code de la carte patient',
        onBack: () => _go('home'),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final value = capture.barcodes
                        .map((barcode) => barcode.rawValue?.trim() ?? '')
                        .firstWhere(
                          (code) => code.isNotEmpty,
                          orElse: () => '',
                        );
                    if (value.isNotEmpty) _handleScan(value);
                  },
                ),
                Center(
                  child: Container(
                    width: 232,
                    height: 232,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(26),
                      color: Colors.transparent,
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .62),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _scanBusy
                          ? 'Vérification sécurisée en cours…'
                          : 'Placez le QR code dans le cadre',
                      textAlign: TextAlign.center,
                      style: _bodyStyle(
                        12,
                        Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildScanResultPage() {
    final patient = _scannedPatient;
    if (patient == null) {
      return _pageScaffold('Résultat du scan', 'Aucun dossier trouvé', [
        _emptyPanel(
          'Scannez une carte patient valide pour afficher son dossier.',
        ),
      ]);
    }
    final allergies = (patient['allergies'] as List? ?? const [])
        .map((value) => value.toString())
        .join(' · ');
    return _pageScaffold(
      'Carte vérifiée',
      'Informations autorisées par le QR sécurisé',
      [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.g800, AppColors.g600],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: Colors.white,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${patient['prenom'] ?? ''} ${patient['nom'] ?? ''}'.trim(),
                  style: _titleStyle(19, Colors.white),
                ),
              ),
              _tag('Vérifié', AppColors.g500, Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _profileField(
          'Numéro de dossier',
          patient['dossierNumber']?.toString() ?? '—',
          Icons.badge_rounded,
        ),
        _profileField(
          'Groupe sanguin',
          patient['groupeSanguin']?.toString() ?? 'Non renseigné',
          Icons.favorite_rounded,
        ),
        _detailBlock(
          'Allergies connues',
          allergies.isEmpty ? 'Aucune allergie renseignée' : allergies,
          Icons.warning_amber_rounded,
          allergies.isEmpty ? AppColors.g100 : AppColors.dangerBg,
        ),
      ],
    );
  }

  Widget _buildNotificationsPage() {
    final medicines = widget.ordonnances
        .expand((item) => (item['medicaments'] as List? ?? const []))
        .whereType<Map>()
        .toList();
    final hasCardUpdate = widget.cardOrders.isNotEmpty;
    return _pageScaffold(
      'Notifications',
      'Les informations importantes de votre dossier',
      [
        if (medicines.isEmpty && !hasCardUpdate)
          _emptyPanel('Aucune notification médicale pour le moment.')
        else ...[
          ...medicines.map(
            (medicine) => _notificationCard(
              Icons.medication_rounded,
              'Rappel de traitement',
              '${medicine['nom'] ?? 'Médicament'} · ${medicine['frequence'] ?? 'Selon ordonnance'}',
              AppColors.warningBg,
              () => _go('prescriptions'),
            ),
          ),
          if (hasCardUpdate)
            _notificationCard(
              Icons.credit_card_rounded,
              'Carte patient',
              _cardStatus(),
              AppColors.g100,
              () => _go('documents'),
            ),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _setNotifications(true),
          icon: const Icon(Icons.notifications_active_rounded),
          label: const Text('Autoriser les notifications'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.g700),
        ),
      ],
    );
  }

  Widget _notificationCard(
    IconData icon,
    String title,
    String message,
    Color tint,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _surfaceDecoration(radius: 17),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
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
                    style: _bodyStyle(
                      12,
                      AppColors.s800,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: _bodyStyle(10, AppColors.s500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.s400),
          ],
        ),
      ),
    ),
  );

  Widget _buildDirectoryPage() {
    final title = switch (_directoryKind) {
      'pharmacies' => 'Pharmacies',
      'medecins' => 'Médecins',
      _ => 'Cliniques & Hôpitaux',
    };
    final icon = switch (_directoryKind) {
      'pharmacies' => Icons.local_pharmacy_rounded,
      'medecins' => Icons.medical_services_rounded,
      _ => Icons.local_hospital_rounded,
    };
    return _pageScaffold(
      title,
      'Recherchez un établissement ou un professionnel',
      [
        Container(
          decoration: _surfaceDecoration(radius: 16),
          child: TextField(
            controller: _directorySearchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadDirectory(),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou ville…',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.g700,
              ),
              suffixIcon: IconButton(
                onPressed: _loadDirectory,
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: 'Rechercher',
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_directoryLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_directoryError != null)
          _emptyPanel(_directoryError!)
        else if (_directoryItems.isEmpty)
          _emptyPanel('Aucun résultat pour cette recherche.')
        else
          ..._directoryItems.map((item) => _directoryCard(item, icon)),
      ],
    );
  }

  Widget _directoryCard(Map<String, dynamic> item, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () => setState(() {
        _selectedDirectoryItem = item;
        _directoryDetailKind = _directoryKind;
      }),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _surfaceDecoration(radius: 18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.g100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.g700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _directoryName(item),
                    style: _bodyStyle(
                      13,
                      AppColors.s800,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _directoryLocation(item),
                    style: _bodyStyle(10, AppColors.s500),
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

  String _directoryName(Map<String, dynamic> item) {
    if (_directoryKind == 'medecins') {
      return 'Dr. ${item['prenom'] ?? ''} ${item['nom'] ?? ''}'.trim();
    }
    return item['nom']?.toString() ?? 'Établissement de santé';
  }

  String _directoryLocation(Map<String, dynamic> item) {
    final entity = item['clinique'] is Map ? item['clinique'] as Map : item;
    final city = entity['ville']?.toString() ?? '';
    final address = entity['adresse']?.toString() ?? '';
    return [
          address,
          city,
        ].where((value) => value.trim().isNotEmpty).join(' · ').isEmpty
        ? 'Informations de contact disponibles'
        : [address, city].where((value) => value.trim().isNotEmpty).join(' · ');
  }

  Widget _buildDirectoryDetailPage() {
    final item = _selectedDirectoryItem ?? const <String, dynamic>{};
    final entity = item['clinique'] is Map
        ? Map<String, dynamic>.from(item['clinique'])
        : item;
    final title = _directoryName(item);
    return _pageScaffold(
      title,
      _directoryKind == 'medecins'
          ? 'Professionnel de santé'
          : 'Établissement approuvé',
      [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.g800, AppColors.g600],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: _titleStyle(18, Colors.white)),
              ),
              _tag('Actif', AppColors.g500, Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _profileField(
          'Adresse',
          entity['adresse']?.toString() ?? 'Non renseignée',
          Icons.location_on_rounded,
        ),
        _profileField(
          'Ville',
          entity['ville']?.toString() ?? 'Non renseignée',
          Icons.location_city_rounded,
        ),
        _profileField(
          'Téléphone',
          item['telephone']?.toString() ??
              entity['telephone']?.toString() ??
              'Non renseigné',
          Icons.phone_rounded,
        ),
        if ((entity['email'] ?? item['email']) != null)
          _profileField(
            'Email',
            (entity['email'] ?? item['email']).toString(),
            Icons.email_rounded,
          ),
        if ((item['telephone'] ?? entity['telephone'])
                ?.toString()
                .trim()
                .isNotEmpty ==
            true)
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('tel:${item['telephone'] ?? entity['telephone']}'),
            ),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Appeler'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.g700),
          ),
      ],
      backPage: 'directory',
    );
  }

  Widget _buildPrescriptionsPage() => _pageScaffold(
    'Mes ordonnances',
    'Toutes vos prescriptions enregistrées',
    widget.ordonnances.isEmpty
        ? [_emptyPanel('Aucune ordonnance enregistrée.')]
        : widget.ordonnances
              .map(
                (item) => _documentListItem(
                  'Ordonnance',
                  item,
                  Icons.receipt_long_rounded,
                  const Color(0xFFF0E8FF),
                  () => _openDocument('Ordonnance', item),
                ),
              )
              .toList(),
  );

  Widget _buildAnalysesPage() => _pageScaffold(
    'Mes analyses',
    'Vos résultats et examens médicaux',
    widget.analyses.isEmpty
        ? [_emptyPanel('Aucune analyse enregistrée.')]
        : widget.analyses
              .map(
                (item) => _documentListItem(
                  'Analyse',
                  item,
                  Icons.biotech_rounded,
                  AppColors.blueBg,
                  () => _openDocument('Analyse', item),
                ),
              )
              .toList(),
  );

  Widget _documentListItem(
    String label,
    dynamic item,
    IconData icon,
    Color tint,
    VoidCallback onTap,
  ) {
    final map = item is Map
        ? Map<String, dynamic>.from(item)
        : <String, dynamic>{};
    final date = map['emiseAt'] ?? map['date'] ?? map['createdAt'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _surfaceDecoration(radius: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.g700),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      map['type']?.toString() ?? label,
                      style: _bodyStyle(
                        12,
                        AppColors.s800,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date?.toString().split('T').first ??
                          'Date non renseignée',
                      style: _bodyStyle(10, AppColors.s500),
                    ),
                  ],
                ),
              ),
              _tag(
                (map['status'] ?? 'Enregistrée').toString(),
                AppColors.g100,
                AppColors.g700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDocument(String type, dynamic item) {
    setState(() {
      _documentDetailType = type;
      _selectedDocument = item is Map ? Map<String, dynamic>.from(item) : null;
      _page = 'document_detail';
    });
  }

  Widget _buildDocumentDetailPage() {
    final item = _selectedDocument ?? const <String, dynamic>{};
    final isPrescription = _documentDetailType == 'Ordonnance';
    final medicines = (item['medicaments'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return _pageScaffold(
      _documentDetailType ?? 'Document',
      isPrescription
          ? 'Détail de votre prescription'
          : 'Détail de votre analyse',
      [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _surfaceDecoration(radius: 20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.g100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPrescription
                      ? Icons.receipt_long_rounded
                      : Icons.biotech_rounded,
                  color: AppColors.g700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPrescription
                      ? 'Ordonnance médicale'
                      : (item['type']?.toString() ?? 'Analyse médicale'),
                  style: _titleStyle(17, AppColors.g900),
                ),
              ),
              _tag(
                (item['status'] ?? 'Enregistrée').toString(),
                AppColors.g100,
                AppColors.g700,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _profileField(
          'Date',
          (item['emiseAt'] ??
                  item['date'] ??
                  item['createdAt'] ??
                  'Non renseignée')
              .toString()
              .split('T')
              .first,
          Icons.calendar_today_rounded,
        ),
        if (isPrescription) ...[
          Text('Médicaments prescrits', style: _titleStyle(15, AppColors.g900)),
          const SizedBox(height: 8),
          if (medicines.isEmpty)
            _emptyPanel('Aucun médicament renseigné.')
          else
            ...medicines.map(
              (medicine) => _detailBlock(
                medicine['nom']?.toString() ?? 'Médicament',
                '${medicine['dose'] ?? 'Dose non renseignée'} · ${medicine['frequence'] ?? 'Fréquence non renseignée'}',
                Icons.medication_rounded,
                AppColors.warningBg,
              ),
            ),
          if ((item['instructionsGenerales'] ?? '')
              .toString()
              .trim()
              .isNotEmpty)
            _detailBlock(
              'Instructions',
              item['instructionsGenerales'].toString(),
              Icons.info_outline_rounded,
              AppColors.blueBg,
            ),
        ] else ...[
          _detailBlock(
            'Résultat',
            (item['resultat'] ??
                    item['resultats'] ??
                    'Résultat enregistré dans votre dossier')
                .toString(),
            Icons.analytics_rounded,
            AppColors.blueBg,
          ),
          _detailBlock(
            'Type d’examen',
            item['type']?.toString() ?? 'Analyse médicale',
            Icons.science_rounded,
            AppColors.g100,
          ),
        ],
      ],
      backPage: isPrescription ? 'prescriptions' : 'analyses',
    );
  }

  Widget _buildDocumentsPage() => _pageScaffold(
    'Documents',
    'Vos ordonnances, analyses et carte patient',
    [
      _documentCard(
        Icons.receipt_long_rounded,
        'Mes ordonnances',
        '${widget.ordonnances.length} prescription(s) enregistrée(s)',
        const Color(0xFFF0E8FF),
        () => _go('prescriptions'),
      ),
      _documentCard(
        Icons.biotech_rounded,
        'Mes analyses',
        '${widget.analyses.length} résultat(s) disponible(s)',
        AppColors.blueBg,
        () => _go('analyses'),
      ),
      _documentCard(
        Icons.history_rounded,
        'Historique médical',
        '${widget.consultations.length + widget.delivrances.length} événement(s)',
        AppColors.g100,
        () => _go('statistics'),
      ),
      _documentCard(
        Icons.credit_card_rounded,
        'Carte physique',
        _cardStatus(),
        const Color(0xFFFFF2D8),
        widget.onOrderCard,
      ),
    ],
  );

  Widget _documentCard(
    IconData icon,
    String title,
    String subtitle,
    Color tint,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _surfaceDecoration(radius: 18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.g700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _bodyStyle(
                      13,
                      AppColors.g900,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: _bodyStyle(10, AppColors.s500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.s400),
          ],
        ),
      ),
    ),
  );

  Widget _buildHealthPage() => _pageScaffold(
    'Ma santé',
    'Les informations importantes de votre dossier',
    [
      _healthSummaryCard(),
      const SizedBox(height: 12),
      _detailBlock(
        'Allergies connues',
        _allergies.isEmpty
            ? 'Aucune allergie renseignée'
            : _allergies.join(' · '),
        Icons.warning_amber_rounded,
        _allergies.isEmpty ? AppColors.g100 : AppColors.dangerBg,
      ),
      _detailBlock(
        'Antécédents médicaux',
        _patientValue('antecedents', 'Aucun antécédent renseigné'),
        Icons.history_edu_rounded,
        AppColors.blueBg,
      ),
      _detailBlock(
        'Traitements en cours',
        widget.ordonnances.isEmpty
            ? 'Aucun traitement en cours'
            : '${widget.ordonnances.length} ordonnance(s) à consulter',
        Icons.medication_rounded,
        const Color(0xFFFFF2D8),
      ),
    ],
  );

  Widget _healthSummaryCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.g800, AppColors.g600]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(Icons.favorite_rounded, color: Colors.white, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profil santé', style: _titleStyle(18, Colors.white)),
              const SizedBox(height: 3),
              Text(
                'Groupe sanguin : ${widget.patient['groupeSanguin'] ?? 'Non renseigné'}',
                style: _bodyStyle(11, Colors.white.withValues(alpha: .82)),
              ),
            ],
          ),
        ),
        _tag('Actif', AppColors.g500, Colors.white),
      ],
    ),
  );

  Widget _detailBlock(
    String title,
    String value,
    IconData icon,
    Color tint,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: _surfaceDecoration(radius: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
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
                style: _bodyStyle(12, AppColors.s800, weight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(value, style: _bodyStyle(11, AppColors.s600, height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildHistoryPage() =>
      _pageScaffold('Statistiques', 'Votre activité médicale récente', [
        Row(
          children: [
            Expanded(
              child: _metricBox(
                '${widget.consultations.length}',
                'Consultations',
                Icons.medical_services_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricBox(
                '${widget.analyses.length}',
                'Analyses',
                Icons.biotech_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricBox(
                '${widget.delivrances.length}',
                'Délivrances',
                Icons.local_pharmacy_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Activité récente', style: _titleStyle(16, AppColors.g900)),
        const SizedBox(height: 8),
        if (widget.consultations.isEmpty && widget.delivrances.isEmpty)
          _emptyPanel('Aucun événement médical enregistré.')
        else ...[
          ...widget.consultations
              .take(8)
              .map(
                (item) => _timelineItem(
                  'Consultation',
                  item['motif']?.toString() ?? 'Consultation médicale',
                  Icons.medical_services_rounded,
                ),
              ),
          ...widget.delivrances
              .take(8)
              .map(
                (item) => _timelineItem(
                  'Pharmacie',
                  'Délivrance enregistrée',
                  Icons.local_pharmacy_rounded,
                ),
              ),
        ],
      ]);

  Widget _metricBox(String value, String label, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: _surfaceDecoration(radius: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.g700, size: 20),
        const SizedBox(height: 8),
        Text(value, style: _titleStyle(20, AppColors.g900)),
        Text(label, style: _bodyStyle(9, AppColors.s500)),
      ],
    ),
  );

  Widget _timelineItem(String title, String subtitle, IconData icon) =>
      Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: _surfaceDecoration(radius: 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.g100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.g700, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _bodyStyle(
                      12,
                      AppColors.s800,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: _bodyStyle(10, AppColors.s500)),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 18,
            ),
          ],
        ),
      );

  Widget _buildProfilePage() =>
      _pageScaffold('Mon profil', 'Vos informations personnelles', [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _surfaceDecoration(radius: 20),
          child: Row(
            children: [
              _avatar(66, background: AppColors.g100),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name, style: _titleStyle(20, AppColors.g900)),
                    const SizedBox(height: 4),
                    Text(
                      'Patient SantéTogo',
                      style: _bodyStyle(11, AppColors.g600),
                    ),
                    const SizedBox(height: 7),
                    _tag('Dossier $_dossier', AppColors.g100, AppColors.g700),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _profileField(
          'Date de naissance',
          widget.patient['dateNaissance']?.toString() ?? 'Non renseignée',
          Icons.cake_rounded,
        ),
        _profileField(
          'Téléphone',
          widget.patient['telephone']?.toString() ?? 'Non renseigné',
          Icons.phone_rounded,
        ),
        _profileField(
          'Adresse',
          widget.patient['adresse']?.toString() ?? 'Non renseignée',
          Icons.location_on_rounded,
        ),
        _profileField(
          'Sexe',
          widget.patient['sexe']?.toString() ?? 'Non renseigné',
          Icons.person_rounded,
        ),
      ]);

  Widget _profileField(String label, String value, IconData icon) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: _surfaceDecoration(radius: 16),
    child: Row(
      children: [
        Icon(icon, color: AppColors.g700, size: 19),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _bodyStyle(10, AppColors.s500)),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Non renseigné' : value,
                style: _bodyStyle(12, AppColors.s800, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildServicesPage() => _pageScaffold(
    'Services de santé',
    'Trouvez l’aide adaptée à vos besoins',
    [
      _serviceDetail(
        Icons.local_hospital_rounded,
        'Cliniques & Hôpitaux',
        'Consulter les établissements disponibles',
        AppColors.g100,
      ),
      _serviceDetail(
        Icons.medical_services_rounded,
        'Médecins',
        'Retrouver les professionnels de santé',
        AppColors.blueBg,
      ),
      _serviceDetail(
        Icons.local_pharmacy_rounded,
        'Pharmacies',
        'Présenter votre carte patient en pharmacie',
        const Color(0xFFF0E8FF),
      ),
    ],
  );

  Widget _serviceDetail(
    IconData icon,
    String title,
    String subtitle,
    Color tint,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: _surfaceDecoration(radius: 18),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.g700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _bodyStyle(13, AppColors.s800, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: _bodyStyle(10, AppColors.s500)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.s400),
      ],
    ),
  );

  Widget _buildSettingsPage() =>
      _pageScaffold('Paramètres', 'Sécurité et préférences', [
        _settingsTile(
          Icons.lock_outline_rounded,
          'Modifier le mot de passe',
          'Sécuriser votre compte',
          widget.onChangePassword,
        ),
        _settingsTile(
          Icons.fingerprint_rounded,
          'Verrouillage biométrique',
          _biometricEnabled
              ? 'Activé sur cet appareil'
              : 'Utiliser votre empreinte ou Face ID',
          () => _setBiometric(!_biometricEnabled),
          trailing: Switch(
            value: _biometricEnabled,
            onChanged: _setBiometric,
            activeThumbColor: AppColors.g700,
          ),
        ),
        _settingsTile(
          Icons.notifications_none_rounded,
          'Notifications',
          _notificationsEnabled
              ? 'Rappels et mises à jour activés'
              : 'Notifications désactivées',
          () => _setNotifications(!_notificationsEnabled),
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: _setNotifications,
            activeThumbColor: AppColors.g700,
          ),
        ),
        _settingsTile(
          Icons.help_outline_rounded,
          'Besoin d’aide ?',
          'Contacter l’assistance au 93014749',
          _openHelp,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Se déconnecter'),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        ),
      ]);

  Widget _settingsTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _surfaceDecoration(radius: 17),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.g100,
                shape: BoxShape.circle,
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
                    style: _bodyStyle(
                      12,
                      AppColors.s800,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: _bodyStyle(10, AppColors.s500)),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right_rounded, color: AppColors.s400),
          ],
        ),
      ),
    ),
  );

  Widget _pageScaffold(
    String title,
    String subtitle,
    List<Widget> children, {
    String backPage = 'home',
  }) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
    children: [
      _buildHeader(
        title: title,
        subtitle: subtitle,
        onBack: () => _go(backPage),
      ),
      const SizedBox(height: 8),
      ...children,
    ],
  );

  Widget _buildBottomNavigation() {
    final items = [
      ('home', Icons.home_rounded, 'Accueil'),
      ('health', Icons.favorite_rounded, 'Santé'),
      ('documents', Icons.description_rounded, 'Documents'),
      ('statistics', Icons.bar_chart_rounded, 'Statistiques'),
      ('settings', Icons.person_rounded, 'Profil'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: items.map((item) {
          final selected =
              _page == item.$1 || (_page == 'profile' && item.$1 == 'settings');
          return Expanded(
            child: InkWell(
              onTap: () => _go(item.$1),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.g100 : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        item.$2,
                        size: 21,
                        color: selected ? AppColors.g700 : AppColors.s500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$3,
                      style: _bodyStyle(
                        9,
                        selected ? AppColors.g700 : AppColors.s500,
                        weight: selected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _patientValue(String key, String fallback) {
    final value = widget.patient[key];
    if (value is List) return value.isEmpty ? fallback : value.join(' · ');
    return value?.toString().trim().isEmpty ?? true
        ? fallback
        : value.toString();
  }

  String _cardStatus() {
    if (widget.cardOrders.isEmpty) return 'Commander une carte physique';
    final status = (widget.cardOrders.first as Map)['status']?.toString();
    return switch (status) {
      'printing' => 'Carte en impression',
      'shipped' => 'Carte expédiée',
      'delivered' => 'Carte livrée',
      _ => 'Commande en attente',
    };
  }

  Widget _emptyPanel(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: _surfaceDecoration(radius: 16),
    child: Text(message, style: _bodyStyle(12, AppColors.s500)),
  );

  Widget _avatar(double size, {Color? background}) {
    ImageProvider<Object>? image;
    final encoded = widget.patient['photo']?.toString() ?? '';
    if (encoded.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(encoded));
      } catch (_) {
        image = null;
      }
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: background ?? AppColors.g700,
      backgroundImage: image,
      child: image == null
          ? Text(_initials(_name), style: _titleStyle(size * .28, Colors.white))
          : null,
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ST';
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }

  Widget _tag(String text, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: _bodyStyle(9, foreground, weight: FontWeight.w800),
    ),
  );

  BoxDecoration _surfaceDecoration({double radius = 18}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFE5F0EC)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .025),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  );

  TextStyle _titleStyle(double size, Color color, {double height = 1.1}) =>
      GoogleFonts.syne(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: height,
      );
  TextStyle _bodyStyle(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w500,
    double height = 1.15,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}
