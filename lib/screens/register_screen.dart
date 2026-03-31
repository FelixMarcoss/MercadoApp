import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthState>();
    final success = await auth.register(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (success && mounted) {
      Navigator.of(context).pop(); // back to login; main.dart will redirect
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7), // Same off-white
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── Header ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Spacer for centering
                  Text(
                    'MercadoApp',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFE94E1B), // Dark orange
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                       color: Colors.white,
                       shape: BoxShape.circle,
                       boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))
                       ]
                    ),
                    child: IconButton(
                       icon: const Icon(Icons.help, color: Color(0xFF2D2D2D)),
                       onPressed: () {
                          // Could show a snackbar or FAQ dialog
                       },
                    ),
                  )
                ],
              ),
              const SizedBox(height: 48),

              // ─── Titles ─────────────────────────────────────────
              Text(
                'Crie sua conta',
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: const Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Comece a transformar sua rotina de\ncompras hoje.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF757575),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // ─── Forms (No card wrapper) ─────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome Completo
                    _buildLabel('Nome Completo'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameCtrl,
                      hint: 'Como podemos te chamar?',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 24),

                    // E-mail
                    _buildLabel('E-mail'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: 'seu@email.com',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                        if (!v.contains('@')) return 'E-mail inválido';
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 24),

                    // Senha
                    _buildLabel('Senha'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passCtrl,
                      hint: 'Mínimo 8 caracteres',
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe a senha';
                        if (v.length < 8) return 'Mínimo de 8 caracteres';
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),

                    // Espaço de Erro
                    Consumer<AuthState>(
                      builder: (_, auth, __) {
                        if (auth.errorMessage == null) return const SizedBox(height: 32);
                        return Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 16),
                          child: Center(
                            child: Text(
                              auth.errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),

                    // Botão Cadastrar
                    Consumer<AuthState>(
                      builder: (_, auth, __) => SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration( // Optional gradient for rich UI, matching image glow
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE94E1B), Color(0xFFF37549)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            boxShadow: [
                               BoxShadow(color: const Color(0xFFE94E1B).withAlpha(80), blurRadius: 20, offset: const Offset(0, 10))
                            ]
                          ),
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent, // Let gradient show
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Text(
                                    'Cadastrar',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // ─── Benefícios Familia Card ────────────────────────
              Container(
                 padding: const EdgeInsets.all(28),
                 decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F4), // Light greenish-grey
                    borderRadius: BorderRadius.circular(24)
                 ),
                 child: Column(
                    children: [
                       Text('Benefícios Família', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF2D2D2D))),
                       const SizedBox(height: 24),
                       _buildBenefitRow('Listas compartilhadas em tempo real'),
                       const SizedBox(height: 16),
                       _buildBenefitRow('Gestão financeira familiar'),
                    ],
                 )
              ),

              const SizedBox(height: 48),

              // ─── Footer Já tenho conta ─────────────────────────
              Center(
                 child: GestureDetector(
                    onTap: () {
                       context.read<AuthState>().clearError();
                       Navigator.pop(context); // returns to LoginScreen
                    },
                    child: Text.rich(
                       TextSpan(
                          text: 'Já tenho uma conta? ',
                          style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
                          children: [
                             TextSpan(
                                text: 'Entrar',
                                style: GoogleFonts.inter(color: const Color(0xFFE94E1B), fontWeight: FontWeight.w900)
                             )
                          ]
                       )
                    )
                 ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
     return Text(
        text,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF555555)),
     );
  }

  Widget _buildTextField({
     required TextEditingController controller,
     required String hint,
     bool obscureText = false,
     TextInputType? keyboardType,
     TextInputAction? textInputAction,
     String? Function(String?)? validator,
     void Function(String)? onFieldSubmitted,
  }) {
     return TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: const Color(0xFF333333)),
        decoration: InputDecoration(
           hintText: hint,
           hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
           filled: true,
           fillColor: Colors.white,
           contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
           enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(30),
             borderSide: const BorderSide(color: Color(0xFFB3B3B3), width: 1.0),
           ),
           focusedBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(30),
             borderSide: const BorderSide(color: Color(0xFFE94E1B), width: 1.5),
           ),
           errorBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(30),
             borderSide: const BorderSide(color: Colors.red, width: 1.5),
           ),
           focusedErrorBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(30),
             borderSide: const BorderSide(color: Colors.red, width: 1.5),
           ),
        ),
        validator: validator,
     );
  }

  Widget _buildBenefitRow(String text) {
     return Row(
        children: [
           Container(
              decoration: const BoxDecoration(
                 color: Color(0xFF1B8573), // Dark green
                 shape: BoxShape.circle
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
           ),
           const SizedBox(width: 12),
           Expanded(
             child: Text(text, style: GoogleFonts.inter(color: const Color(0xFF555555), fontSize: 13, fontWeight: FontWeight.w500)),
           )
        ],
     );
  }
}
