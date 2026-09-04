import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/providers/auth_provider.dart';
import 'package:sante/widgets/common_widgets.dart';
import 'package:sante/widgets/sante_shell.dart';
import 'package:sante/screens/auth/register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        throw Exception('Adresse email invalide.');
      }

      await ref.read(authStateProvider.notifier).login(email, password);
      if (!mounted) return;

      final current = ref.read(authStateProvider);
      final user = current.value;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connexion réussie : bienvenue ${user.fullName.trim().isNotEmpty ? user.fullName : user.email}.',
            ),
            backgroundColor: AppColors.g700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion échouée : identifiants non retrouvés.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connexion échouée : ${message.isNotEmpty ? message : 'identifiants invalides ou serveur indisponible.'}',
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
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adresse email',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.s800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.s100),
            color: const Color(0xFFFAFAFA),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 15,
                  color: AppColors.s400,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'nom@structure.tg',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: AppColors.s400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppColors.s800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Mot de passe',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.s800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.s100),
            color: const Color(0xFFFAFAFA),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: AppColors.s400,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: AppColors.s400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppColors.s800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 15,
                  color: AppColors.s400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'Se connecter',
            isLoading: _isSubmitting,
            onPressed: () => _submitLogin(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: Divider(color: AppColors.s100)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Nouvelle structure ?',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.s400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.s100)),
          ],
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.g100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withAlpha(45)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inscrire clinique ou pharmacie',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.g700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Validation admin requise',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.s400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.g700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return SanteAuthShell(
      title: 'Connexion',
      subtitle: 'Accédez à votre compte SantéTogo',
      child: form,
    );
  }
}
