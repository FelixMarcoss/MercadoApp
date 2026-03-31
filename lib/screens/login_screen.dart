import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthState>();
    await auth.login(_emailCtrl.text, _passCtrl.text);
    // Navigation is handled by main.dart's Consumer<AuthState>
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7), // Fundo Off-white puxando pro pêssego clarinho
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header Logo ───────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE94E1B), // Laranja marca principal
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE94E1B).withAlpha(80),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ]
                    ),
                    child: const Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'MercadoApp',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // ─── Boas Vindas Textos ─────────────────────────────
              Text(
                'Bem-vindo ao\nMercadoApp',
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -0.5,
                  color: const Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gerencie as compras da sua casa de\nforma inteligente e compartilhada.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF757575),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // ─── Login Card Branco ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    )
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email Label + Field
                      Text(
                        'EMAIL',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: const Color(0xFF555555),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: const Color(0xFF333333)),
                        decoration: InputDecoration(
                          hintText: 'nome@exemplo.com',
                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE94E1B), width: 1.5),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                          if (!v.contains('@')) return 'E-mail inválido';
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),

                      // Senha Label + Esqueceu + Field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SENHA',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: const Color(0xFF555555),
                            ),
                          ),
                          Text(
                            'Esqueceu?',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE94E1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        textInputAction: TextInputAction.done,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: const Color(0xFF333333)),
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, letterSpacing: 2.0),
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          suffixIcon: IconButton( // mantendo pro usuario poder ver a senha ocultamente
                            icon: Icon(
                              _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE94E1B), width: 1.5),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Informe a senha';
                          return null;
                        },
                      ),

                      // Espaço de Erro
                      Consumer<AuthState>(
                        builder: (_, auth, __) {
                          if (auth.errorMessage == null) return const SizedBox(height: 24);
                          return Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 12),
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

                      // Botão Entrar
                      Consumer<AuthState>(
                        builder: (_, auth, __) => SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE94E1B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Text(
                                    'Entrar',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade100, thickness: 1.5),
                      const SizedBox(height: 20),

                      // Criar Nova Conta TextButton
                      Center(
                        child: GestureDetector(
                           onTap: () {
                              context.read<AuthState>().clearError();
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                           },
                           child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                 const Icon(Icons.person_add_alt_1, color: Color(0xFF1E1E1E), size: 20),
                                 const SizedBox(width: 8),
                                 Text(
                                   'Criar nova conta',
                                   style: GoogleFonts.inter(
                                      color: const Color(0xFF1E1E1E),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                   ),
                                 )
                              ],
                           ),
                        )
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ─── Highlight Feature Cards Inferiores ──────────────
              Row(
                children: [
                   Expanded(
                      child: _buildFeatureCard(
                         icon: Icons.qr_code_scanner, 
                         color: const Color(0xFF4EEACE), // light cyan
                         iconColor: const Color(0xFF1B8573), 
                         title: 'Scan Rápido', 
                         desc: 'Adicione itens escaneando o código de barras.'
                      )
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                      child: _buildFeatureCard(
                         icon: Icons.fact_check, // checklist or sync 
                         color: const Color(0xFF86EA96), // light green
                         iconColor: const Color(0xFF195522), 
                         title: 'Sincronismo', 
                         desc: 'Todos conseguem ter acesso a lista em tempo real'
                      )
                   )
                ],
              ),

              const SizedBox(height: 48),

              // ─── Footer Legals ──────────────────────────────────
              Center(
                 child: Text.rich(
                    TextSpan(
                       text: 'Ao entrar, você concorda com nossos\n',
                       children: [
                          TextSpan(text: 'Termos de Uso', style: TextStyle(decoration: TextDecoration.underline, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          const TextSpan(text: ' e '),
                          TextSpan(text: 'Privacidade', style: TextStyle(decoration: TextDecoration.underline, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                       ]
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                       color: Colors.grey.shade500,
                       fontSize: 11,
                       height: 1.5
                    ),
                 )
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required Color color, required Color iconColor, required String title, required String desc}) {
     return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.circular(24),
           boxShadow: [
              BoxShadow(
                 color: Colors.black.withAlpha(5),
                 blurRadius: 15,
                 offset: const Offset(0, 5),
              )
           ]
        ),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           mainAxisSize: MainAxisSize.min, // ensures strict hugging of items
           children: [
              Container(
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                 ),
                 child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 20),
              Text(
                title, 
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF2D2D2D)),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF888888), height: 1.4),
              )
           ],
        ),
     );
  }
}
