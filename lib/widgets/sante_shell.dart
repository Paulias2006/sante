import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/config/app_constants.dart';
import 'package:sante/providers/auth_provider.dart';
import 'package:sante/screens/profile/profile_screen.dart';

class SanteBrandLogo extends StatelessWidget {
  final bool withWordmark;
  final bool onDark;
  final double emblemSize;
  final double titleFontSize;

  const SanteBrandLogo({
    super.key,
    this.withWordmark = true,
    this.onDark = false,
    this.emblemSize = 64,
    this.titleFontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (withWordmark) {
      final width = emblemSize * 3.4;
      return SizedBox(
        width: width,
        height: width / (2048 / 768),
        child: Image.asset(
          'assets/logo_sante.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _fallbackLogo(onDark),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(emblemSize * 0.24),
      child: SizedBox(
        width: emblemSize,
        height: emblemSize,
        child: Image.asset(
          'assets/logo_sante.png',
          fit: BoxFit.cover,
          alignment: Alignment.centerLeft,
          errorBuilder: (context, error, stack) =>
              _fallbackLogo(onDark, compact: true),
        ),
      ),
    );
  }

  Widget _fallbackLogo(bool onDark, {bool compact = false}) {
    final emblem = Container(
      width: emblemSize,
      height: emblemSize,
      decoration: BoxDecoration(
        color: onDark ? Colors.white : AppColors.g700,
        borderRadius: BorderRadius.circular(emblemSize * 0.24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: onDark ? 0.18 : 0.08),
            blurRadius: onDark ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        Icons.local_hospital_rounded,
        size: emblemSize * 0.5,
        color: onDark ? AppColors.g700 : Colors.white,
      ),
    );

    if (!withWordmark) {
      return emblem;
    }

    if (compact) return emblem;

    final titleColor = onDark ? Colors.white : AppColors.g800;
    final subtitleColor = onDark
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.g600;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        emblem,
        SizedBox(width: emblemSize * 0.22),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Santé\nTogo',
              style: GoogleFonts.syne(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w800,
                color: titleColor,
                height: 0.95,
              ),
            ),
            Text(
              'DOSSIER MÉDICAL NUMÉRIQUE',
              style: GoogleFonts.inter(
                fontSize: titleFontSize * 0.33,
                letterSpacing: 0,
                fontWeight: FontWeight.w700,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SanteDashboardNavItem {
  final IconData icon;
  final String label;
  final bool selected;
  final void Function() onTap;

  const SanteDashboardNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
}

class SanteDashboardShell extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final List<SanteDashboardNavItem> navItems;
  final String userName;
  final String userRole;
  final Widget body;
  final Widget? headerAction;

  const SanteDashboardShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.navItems,
    required this.userName,
    required this.userRole,
    required this.body,
    this.headerAction,
  });

  Widget _buildSidebarContent(BuildContext context, WidgetRef ref) {
    return Container(
      width: AppConstants.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.g800,
        border: Border(right: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const SanteBrandLogo(
                  withWordmark: false,
                  onDark: true,
                  emblemSize: 60,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SantéTogo',
                      style: GoogleFonts.syne(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Dossier Patient',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        letterSpacing: 0,
                        color: Colors.white.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...navItems.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: item.selected
                          ? Colors.white.withValues(alpha: 0.09)
                          : null,
                      border: item.selected
                          ? const Border(
                              left: BorderSide(color: AppColors.g400, width: 3),
                            )
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: item.selected
                        ? const EdgeInsets.only(left: 4)
                        : null,
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 15,
                          color: item.selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: item.selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.60),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(11),
            child: PopupMenuButton<String>(
              offset: const Offset(0, -8),
              tooltip: 'Profil et déconnexion',
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) async {
                switch (value) {
                  case 'profile':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          user: ref.read(authStateProvider).valueOrNull,
                        ),
                      ),
                    );
                    break;
                  case 'logout':
                    await ref.read(authStateProvider.notifier).logout();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Profil'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Déconnexion'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.g500,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Center(
                        child: Text(
                          (() {
                            final normalized = userName.trim();
                            if (normalized.isEmpty) return 'ST';
                            final parts = normalized
                                .split(RegExp(r'\s+'))
                                .where((part) => part.isNotEmpty)
                                .toList();
                            if (parts.isEmpty) return 'ST';
                            final initials = parts
                                .take(2)
                                .map((part) => part[0])
                                .join();
                            return initials.isEmpty
                                ? 'ST'
                                : initials.toUpperCase();
                          })(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            userRole,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              color: Colors.white.withValues(alpha: 0.38),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final subtitleWidget = subtitle == null
        ? const SizedBox.shrink()
        : Row(
            children: [
              const SizedBox(width: 8),
              Text(
                subtitle!,
                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.s400),
              ),
            ],
          );

    final mainContent = Expanded(
      child: Column(
        children: [
          Container(
            height: AppConstants.topbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.s100)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.syne(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.s800,
                  ),
                ),
                subtitleWidget,
                const Spacer(),
                headerAction ?? const SizedBox.shrink(),
              ],
            ),
          ),
          Expanded(
            child: Container(color: AppColors.s50, child: body),
          ),
        ],
      ),
    );

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppColors.s50,
      drawer: !isDesktop
          ? Drawer(child: _buildSidebarContent(context, ref))
          : null,
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                title,
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.s800,
                ),
              ),
              leading: IconButton(
                onPressed: () => scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: AppColors.g700),
              ),
              actions: headerAction != null
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: headerAction!,
                      ),
                    ]
                  : null,
            )
          : null,
      body: SafeArea(
        child: isDesktop
            ? Center(
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width > 1500
                      ? 1500
                      : MediaQuery.sizeOf(context).width - 32,
                  child: Row(
                    children: [
                      _buildSidebarContent(context, ref),
                      Expanded(child: mainContent),
                    ],
                  ),
                ),
              )
            : Container(color: AppColors.s50, child: body),
      ),
    );
  }
}

class SanteAuthShell extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBrand;

  const SanteAuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBrand = true,
  });

  @override
  State<SanteAuthShell> createState() => _SanteAuthShellState();
}

class _SanteAuthShellState extends State<SanteAuthShell> {
  late final ScrollController _formScrollController;

  @override
  void initState() {
    super.initState();
    _formScrollController = ScrollController();
  }

  @override
  void dispose() {
    _formScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final useNativeAppLayout = !isWeb || screenWidth < 900;

    if (useNativeAppLayout) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.showBrand)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: const SanteBrandLogo(
                                withWordmark: true,
                                emblemSize: 84,
                              ),
                            ),
                          ),
                        Text(
                          widget.title,
                          style: GoogleFonts.syne(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.s800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.s400,
                          ),
                        ),
                        const SizedBox(height: 22),
                        widget.child,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.s100,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentHeight = (constraints.maxHeight - 56)
                .clamp(520.0, 820.0)
                .toDouble();

            return Center(
              child: Container(
                width: 1200,
                height: contentHeight,
                margin: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1E0A3D2E),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(48, 48, 52, 40),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.g900,
                              AppColors.g800,
                              AppColors.g700,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                          ),
                        ),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SanteBrandLogo(
                                withWordmark: false,
                                onDark: true,
                                emblemSize: 104,
                              ),
                              const SizedBox(height: 28),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.g400,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Plateforme active au Togo',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.g400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Dossier médical\nnumérique\npour tous',
                                style: GoogleFonts.syne(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.15,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Une solution sécurisée connectant cliniques, patients et pharmacies au Togo. Accédez à l\'historique complet en un scan de carte.',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  color: Colors.white.withValues(alpha: 0.55),
                                  height: 1.7,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.qr_code_scanner_rounded,
                                                  color: Colors.white,
                                                  size: 26,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'QR sécurisé',
                                                  style: GoogleFonts.syne(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Lecture patient et ordonnance',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.55,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            width: 54,
                                            height: 54,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.verified_user_rounded,
                                              color: Colors.white,
                                              size: 26,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Données réelles',
                                            style: GoogleFonts.syne(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Backend, MongoDB et rôles métier',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: Colors.white.withValues(
                                                alpha: 0.55,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 20,
                        ),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: Scrollbar(
                            controller: _formScrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            interactive: true,
                            thickness: 9,
                            radius: const Radius.circular(8),
                            child: SingleChildScrollView(
                              controller: _formScrollController,
                              primary: false,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 0),
                                child: Center(
                                  child: SizedBox(
                                    width: 420,
                                    child: widget.child,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
