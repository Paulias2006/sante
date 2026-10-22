import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/widgets/sante_shell.dart';

class PharmacyMobileExperience extends StatefulWidget {
  final String userName;
  final List<dynamic> deliveries;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> scanResult;
  final Future<void> Function() onRefresh;
  final VoidCallback onScan;
  final Future<void> Function() onConfirmDelivery;
  final VoidCallback onSettings;
  final Future<void> Function() onLogout;
  final Future<void> Function() onExport;

  const PharmacyMobileExperience({
    super.key,
    required this.userName,
    required this.deliveries,
    required this.stats,
    required this.scanResult,
    required this.onRefresh,
    required this.onScan,
    required this.onConfirmDelivery,
    required this.onSettings,
    required this.onLogout,
    required this.onExport,
  });

  @override
  State<PharmacyMobileExperience> createState() =>
      _PharmacyMobileExperienceState();
}

class _PharmacyMobileExperienceState extends State<PharmacyMobileExperience> {
  String _page = 'home';

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
        onPressed: widget.onScan,
        backgroundColor: AppColors.g700,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scanner'),
      ),
    );
  }

  Widget _content() {
    switch (_page) {
      case 'deliveries':
        return _deliveriesPage();
      case 'stats':
        return _statsPage();
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
                Text(subtitle, style: _body(10, AppColors.s500)),
              ],
            ),
          ),
          if (back == null)
            IconButton(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.g700,
            ),
        ],
      ),
    );
  }

  Widget _homePage() {
    return RefreshIndicator(
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
          _header('Espace pharmacie', 'Délivrance sécurisée des ordonnances'),
          Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.g800, AppColors.g600],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_pharmacy_rounded,
                  color: Colors.white,
                  size: 40,
                ),
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
                        'Prêt à servir vos patients.',
                        style: _title(20, Colors.white),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric(
                '${widget.deliveries.length}',
                'Délivrances',
                Icons.local_shipping_rounded,
                AppColors.g100,
              ),
              const SizedBox(width: 8),
              _metric(
                '${widget.stats['count'] ?? 0}',
                'Aujourd’hui',
                Icons.today_rounded,
                AppColors.blueBg,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _action(
            Icons.qr_code_scanner_rounded,
            'Scanner une ordonnance',
            'Vérifier le patient et les médicaments',
            widget.onScan,
            AppColors.g100,
          ),
          _action(
            Icons.history_rounded,
            'Historique des délivrances',
            'Consulter les opérations réalisées',
            () => _go('deliveries'),
            AppColors.blueBg,
          ),
          _action(
            Icons.bar_chart_rounded,
            'Statistiques',
            'Suivre l’activité de la pharmacie',
            () => _go('stats'),
            const Color(0xFFF0E8FF),
          ),
          if (widget.scanResult.isNotEmpty) ...[
            const SizedBox(height: 14),
            _scanCard(),
          ],
                ],
              ),
            ),
          ],
      ),
      ),
    );
  }

  Widget _scanCard() {
    final patient = widget.scanResult['patient'] as Map? ?? const {};
    final ordonnance = widget.scanResult['ordonnance'] as Map? ?? const {};
    final count = (ordonnance['medicaments'] as List? ?? const []).length;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3D58B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${patient['prenom'] ?? ''} ${patient['nom'] ?? ''}'.trim(),
                  style: _title(16, AppColors.g900),
                ),
              ),
              _tag('À délivrer', AppColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${patient['groupeSanguin'] ?? '—'} · $count médicament(s)',
            style: _body(11, AppColors.s600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onConfirmDelivery,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Confirmer la délivrance'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.g700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveriesPage() => _pageScaffold(
    'Délivrances',
    'Historique de la pharmacie',
    [
      if (widget.deliveries.isEmpty)
        _empty('Aucune délivrance enregistrée.')
      else
        ...widget.deliveries.map((item) {
          final patient = item['patient'] as Map? ?? const {};
          return _detail(
            '${patient['prenom'] ?? ''} ${patient['nom'] ?? ''}'.trim().isEmpty
                ? 'Patient'
                : '${patient['prenom'] ?? ''} ${patient['nom'] ?? ''}',
            '${item['date'] ?? 'Date inconnue'} · ${item['status'] ?? 'Délivrée'}',
            Icons.local_shipping_rounded,
          );
        }),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: widget.onExport,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Exporter le rapport'),
      ),
    ],
  );

  Widget
  _statsPage() => _pageScaffold('Statistiques', 'Activité de votre pharmacie', [
    _detail(
      'Délivrances enregistrées',
      '${widget.stats['count'] ?? widget.deliveries.length}',
      Icons.local_shipping_rounded,
    ),
    _detail(
      'Activité du jour',
      '${widget.stats['dailyStats'] is List ? (widget.stats['dailyStats'] as List).length : 0} journée(s) suivie(s)',
      Icons.today_rounded,
    ),
    _detail(
      'Sécurité',
      'Chaque ordonnance est vérifiée avant délivrance',
      Icons.verified_user_rounded,
    ),
  ]);

  Widget _settingsPage() => _pageScaffold('Paramètres', 'Compte et pharmacie', [
    _action(
      Icons.settings_rounded,
      'Paramètres de la pharmacie',
      'Modifier les informations et le compte',
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
  Widget _pageScaffold(String title, String subtitle, List<Widget> children) =>
      LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(title, subtitle, back: () => _go('home')),
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
  Widget _metric(String value, String label, IconData icon, Color tint) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.g700, size: 19),
              const SizedBox(height: 7),
              Text(value, style: _title(20, AppColors.g900)),
              Text(label, style: _body(9, AppColors.s500)),
            ],
          ),
        ),
      );
  Widget _empty(String text) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _surface(),
    child: Text(text, style: _body(12, AppColors.s500)),
  );
  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(text, style: _body(9, Colors.white, weight: FontWeight.w800)),
  );
  BoxDecoration _surface() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    border: Border.all(color: const Color(0xFFE5F0EC)),
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
      ('home', Icons.qr_code_scanner_rounded, 'Scanner'),
      ('deliveries', Icons.local_shipping_rounded, 'Délivrances'),
      ('stats', Icons.bar_chart_rounded, 'Stats'),
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
          final selected = _page == item.$1;
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
