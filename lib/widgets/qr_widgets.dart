import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/config/app_constants.dart';

class QrDisplayWidget extends StatelessWidget {
  final String qrToken;
  final String? dossierId;
  final String? groupeSanguin;
  final List<String>? allergies;

  const QrDisplayWidget({
    super.key,
    required this.qrToken,
    this.dossierId,
    this.groupeSanguin,
    this.allergies,
  });

  @override
  Widget build(BuildContext context) {
    final qrSize = MediaQuery.sizeOf(context).width < 420 ? 220.0 : 240.0;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        side: const BorderSide(color: AppColors.s100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (dossierId != null)
              Text(
                dossierId!,
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.s800,
                ),
              ),
            if (dossierId != null)
              const SizedBox(height: AppConstants.paddingL),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.g400),
                borderRadius: BorderRadius.circular(10),
              ),
              width: qrSize,
              height: qrSize,
              child: QrImageView(data: qrToken, padding: EdgeInsets.zero),
            ),
            if (groupeSanguin != null) ...[
              const SizedBox(height: AppConstants.paddingL),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.g50,
                  border: Border.all(color: AppColors.g200),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Groupe: $groupeSanguin',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.g700,
                  ),
                ),
              ),
            ],
            if (allergies != null && allergies!.isNotEmpty) ...[
              const SizedBox(height: AppConstants.paddingM),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingM,
                  vertical: AppConstants.paddingS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  border: Border.all(color: AppColors.dangerBorder),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          size: 14,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ALLERGIES',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...allergies!.map(
                      (allergy) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $allergy',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
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

class ScanZoneWidget extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const ScanZoneWidget({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.g400,
            width: 2,
            strokeAlign: BorderSide.strokeAlignCenter,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.g50.withAlpha(128),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.g600,
                    ),
                  ),
                )
              else
                Icon(Icons.camera_alt_rounded, size: 48, color: AppColors.g600),
              const SizedBox(height: AppConstants.paddingL),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.g600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
