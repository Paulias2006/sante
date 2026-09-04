import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/config/app_constants.dart';
import 'package:sante/widgets/common_widgets.dart';
import 'package:sante/widgets/sante_shell.dart';
import 'package:sante/screens/auth/login_screen.dart';
import 'package:sante/services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _villeController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _numeroAutorisationController =
      TextEditingController();
  final TextEditingController _responsableController = TextEditingController();
  DateTime? _dateAutorisation;
  String _type = 'clinique_privee';
  String _entityKind = 'clinique';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _numeroAutorisationController.dispose();
    _responsableController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateAutorisation = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final api = ApiService();
    try {
      final payload = {
        'nom': _nomController.text.trim(),
        'type': _type,
        'adresse': _adresseController.text.trim(),
        'ville': _villeController.text.trim(),
        'telephone': _telephoneController.text.trim(),
        'email': _emailController.text.trim(),
        'numeroAutorisation': _numeroAutorisationController.text.trim(),
        'responsable': _responsableController.text.trim(),
        'dateAutorisation': _dateAutorisation?.toIso8601String(),
      };

      final res = _entityKind == 'pharmacie'
          ? await api.registerPharmacie(payload)
          : await api.registerClinique(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inscription envoyée : ${res['message'] ?? 'demande en attente de validation admin.'}',
          ),
          backgroundColor: AppColors.g700,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inscription échouée : ${message.isNotEmpty ? message : 'vérifiez les champs et le serveur.'}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _entityKind == 'pharmacie'
                ? 'Inscrire ma pharmacie'
                : 'Inscrire mon établissement',
            style: GoogleFonts.syne(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.s800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dossier vérifié par l’administration avant activation',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.s500),
          ),
          const SizedBox(height: 20),
          _buildEntityToggle(),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepTile('1', 'Informations', true),
              Expanded(child: Divider()),
              _stepTile('2', 'Documents', false),
              Expanded(child: Divider()),
              _stepTile('3', 'Validation', false),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle(
            _entityKind == 'pharmacie'
                ? 'Informations de la pharmacie'
                : 'Informations de l’établissement',
          ),
          const SizedBox(height: 10),
          _buildTextField(
            _nomController,
            _entityKind == 'pharmacie'
                ? 'Nom de la pharmacie'
                : 'Nom de l’établissement',
            required: true,
          ),
          if (_entityKind != 'pharmacie') ...[
            const SizedBox(height: 10),
            _buildTypeDropdown(),
          ],
          const SizedBox(height: 10),
          _buildTextField(
            _adresseController,
            'Adresse complète',
            required: true,
          ),
          const SizedBox(height: 10),
          _buildResponsivePair(
            _buildTextField(_villeController, 'Ville', required: true),
            _buildTextField(_telephoneController, 'Téléphone', required: true),
          ),
          const SizedBox(height: 10),
          _buildTextField(
            _emailController,
            'Email professionnel',
            required: true,
          ),
          const SizedBox(height: 12),
          _sectionTitle('Autorisation officielle'),
          const SizedBox(height: 10),
          _buildResponsivePair(
            _buildTextField(
              _numeroAutorisationController,
              'N° Autorisation Ministère Santé',
              required: true,
            ),
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Date d\'autorisation',
                    hintText: _dateAutorisation == null
                        ? 'Choisir une date'
                        : DateFormat('dd/MM/yyyy').format(_dateAutorisation!),
                    filled: true,
                    fillColor: AppColors.s50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _responsableController,
            'Responsable (nom complet)',
            required: true,
          ),
          const SizedBox(height: 12),
          _sectionTitle('Documents requis pour validation'),
          const SizedBox(height: 8),
          _buildResponsivePair(
            _documentRequirementBox('Autorisation officielle'),
            _documentRequirementBox("Pièce d'identité responsable"),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Soumettre ma demande',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'La demande apparaîtra dans l’espace admin pour validation.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.s500),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Text(
                  'Vous avez déjà un compte ?',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.s500),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Text(
                    'Connexion',
                    style: GoogleFonts.inter(
                      color: AppColors.g600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );

    return SanteAuthShell(
      title: 'Inscription',
      subtitle: 'Validation établissement et pharmacie',
      child: formContent,
    );
  }

  Widget _stepTile(String num, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active ? AppColors.g500 : AppColors.s50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              num,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppColors.s600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.s600),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Icon(Icons.local_hospital, color: AppColors.g600, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.s700,
          ),
        ),
      ],
    );
  }

  Widget _buildEntityToggle() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'clinique',
          label: Text('Clinique / hôpital'),
          icon: Icon(Icons.local_hospital_rounded),
        ),
        ButtonSegment(
          value: 'pharmacie',
          label: Text('Pharmacie'),
          icon: Icon(Icons.local_pharmacy_rounded),
        ),
      ],
      selected: {_entityKind},
      onSelectionChanged: (values) =>
          setState(() => _entityKind = values.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.g700,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.g700
              : AppColors.g50,
        ),
      ),
    );
  }

  Widget _buildResponsivePair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [first, const SizedBox(height: 10), second]);
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController c,
    String label, {
    bool required = false,
  }) {
    return TextFormField(
      controller: c,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.s50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _type,
      items: const [
        DropdownMenuItem(
          value: 'clinique_privee',
          child: Text('Clinique privée'),
        ),
        DropdownMenuItem(value: 'hopital', child: Text('Hôpital')),
        DropdownMenuItem(value: 'centre_sante', child: Text('Centre de santé')),
      ],
      onChanged: (v) => setState(() => _type = v ?? _type),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.s50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
      ),
    );
  }

  Widget _documentRequirementBox(String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.s50,
        border: Border.all(color: AppColors.s100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.description_rounded, color: AppColors.g400, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.s600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Requis par l’administrateur avant approbation',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.s500),
          ),
        ],
      ),
    );
  }
}
