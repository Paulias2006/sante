import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/config/app_constants.dart';

class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String? deltaText;
  final bool deltaPositive;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    this.deltaText,
    this.deltaPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        side: const BorderSide(color: AppColors.s100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: AppConstants.paddingL),
            Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.s800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.s400,
              ),
            ),
            if (deltaText != null) ...[
              const SizedBox(height: AppConstants.paddingM),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: deltaPositive
                      ? AppColors.successBg
                      : AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      deltaPositive ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: deltaPositive
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      deltaText!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: deltaPositive
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PatientHeaderCard extends StatelessWidget {
  final String nom;
  final String prenom;
  final String? age;
  final String groupeSanguin;
  final List<String> allergies;
  final VoidCallback? onTapQr;

  const PatientHeaderCard({
    super.key,
    required this.nom,
    required this.prenom,
    this.age,
    required this.groupeSanguin,
    required this.allergies,
    this.onTapQr,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        side: const BorderSide(color: AppColors.s100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.g500, AppColors.g700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Text(
                  '${prenom[0]}${nom[0]}'.toUpperCase(),
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.paddingL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$prenom $nom',
                    style: GoogleFonts.syne(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.s800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (age != null) ...[
                        Text(
                          'Âge: $age ans',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.s400,
                          ),
                        ),
                        const SizedBox(width: 11),
                      ],
                      Text(
                        'Groupe: $groupeSanguin',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.s400,
                        ),
                      ),
                    ],
                  ),
                  if (allergies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppConstants.paddingM,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingM,
                          vertical: AppConstants.paddingS,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          border: Border.all(color: AppColors.dangerBorder),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_rounded,
                              size: 14,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                allergies.join(', '),
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.danger,
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
          ],
        ),
      ),
    );
  }
}
