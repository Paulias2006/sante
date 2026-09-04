import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/models/user.dart';
import 'package:sante/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final User? user;

  const ProfileScreen({super.key, this.user});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _appearanceEnabled = false;
  bool _securityEnabled = true;

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrateur';
      case 'medecin':
        return 'Médecin';
      case 'secretaire':
        return 'Secrétaire';
      case 'pharmacien':
        return 'Pharmacien';
      case 'patient':
        return 'Patient';
      default:
        return 'Utilisateur';
    }
  }

  String _structureLabel(User currentUser) {
    if (currentUser.entite != null && currentUser.entite!.trim().isNotEmpty) {
      return currentUser.entite!.trim();
    }

    final entiteType = currentUser.entiteType?.trim();
    switch (entiteType?.toLowerCase()) {
      case 'clinique':
        return 'Clinique / structure médicale';
      case 'pharmacie':
        return 'Pharmacie / dispense';
      default:
        return currentUser.role.toLowerCase() == 'patient'
            ? 'Compte patient'
            : 'Structure principale';
    }
  }

  void _showToggleMessage(String label, bool value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label ${value ? 'activé' : 'désactivé'}.'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.user ?? ref.watch(authStateProvider).valueOrNull;
    final safeUser =
        currentUser ??
        User(
          id: '',
          email: 'non-renseigne@none',
          role: 'user',
          nom: 'Utilisateur',
          prenom: 'Compte',
          actif: true,
        );

    final displayName = safeUser.fullName.trim().isNotEmpty
        ? safeUser.fullName
        : safeUser.email.split('@').first;
    final initials = safeUser.initials.isNotEmpty ? safeUser.initials : 'ST';
    final roleLabel = _roleLabel(safeUser.role);
    final structureLabel = _structureLabel(safeUser);
    final email = safeUser.email.trim().isNotEmpty
        ? safeUser.email
        : 'non renseigné';
    final statusLabel = safeUser.actif
        ? 'Compte actif · vérifié'
        : 'Compte inactif';

    return Scaffold(
      backgroundColor: AppColors.s50,
      appBar: AppBar(
        title: Text(
          'Profil',
          style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.s800,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.s800,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.s100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.g700,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.syne(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
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
                                displayName,
                                style: GoogleFonts.syne(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.s800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.g50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  roleLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.g700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _InfoTile(title: 'Email', value: email),
                  const SizedBox(height: 10),
                  _InfoTile(title: 'Structure', value: structureLabel),
                  const SizedBox(height: 10),
                  _InfoTile(title: 'Statut', value: statusLabel),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.s100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paramètres',
                          style: GoogleFonts.syne(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.s800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Sécurité',
                          subtitle: 'Mot de passe et authentification',
                          value: _securityEnabled,
                          onChanged: (value) {
                            setState(() => _securityEnabled = value);
                            _showToggleMessage('Sécurité', value);
                          },
                        ),
                        _SettingRow(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notifications',
                          subtitle: 'Alertes et rappels',
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                            _showToggleMessage('Notifications', value);
                          },
                        ),
                        _SettingRow(
                          icon: Icons.brightness_6_outlined,
                          label: 'Apparence',
                          subtitle: 'Palette claire et accès rapide',
                          value: _appearanceEnabled,
                          onChanged: (value) {
                            setState(() => _appearanceEnabled = value);
                            _showToggleMessage('Apparence', value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.s100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.s500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.s800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.s50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.g50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.g700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.s800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.s500),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.g700,
          ),
        ],
      ),
    );
  }
}
