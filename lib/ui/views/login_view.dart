import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../atoms/app_button.dart';
import '../atoms/app_input.dart';
import 'main_navigation_view.dart';

/// LingoDev Giriş / Kayıt Ekranı
/// Firebase Auth entegrasyonlu, premium dark tema
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isRegisterMode = false; // Giriş ↔ Kayıt modu geçişi

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Firebase Auth: Giriş Yap ─────────────────────────────
  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      debugPrint('İşlem Başarılı: ${credential.user?.uid}');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationView()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showErrorSnackBar(_mapFirebaseError(e.code));
    } catch (e) {
      if (mounted) _showErrorSnackBar('Beklenmeyen bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Firebase Auth: Kayıt Ol ──────────────────────────────
  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      debugPrint('İşlem Başarılı: ${credential.user?.uid}');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationView()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showErrorSnackBar(_mapFirebaseError(e.code));
    } catch (e) {
      if (mounted) _showErrorSnackBar('Beklenmeyen bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Şifremi Unuttum ──────────────────────────────────────
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showErrorSnackBar('Lütfen önce e-posta adresinizi girin.');
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        _showSuccessSnackBar('Şifre sıfırlama bağlantısı gönderildi 📧');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showErrorSnackBar(_mapFirebaseError(e.code));
    } catch (e) {
      if (mounted) _showErrorSnackBar('Beklenmeyen bir hata oluştu.');
    }
  }

  // ── Mod Geçişi ────────────────────────────────────────────
  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _formKey.currentState?.reset();
    });
  }

  // ── Firebase Hata Kodlarını Türkçeleştirme ────────────────
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta adresiyle kayıtlı bir hesap bulunamadı.';
      case 'wrong-password':
        return 'Girdiğiniz şifre yanlış.';
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter kullanın.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi formatı.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yaptınız. Lütfen biraz bekleyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
      case 'operation-not-allowed':
        return 'Bu giriş yöntemi aktif değil.';
      default:
        return 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }

  // ── Hata SnackBar ─────────────────────────────────────────
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Başarı SnackBar ───────────────────────────────────────
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Logo / Başlık ────────────────────────
                        _buildLogo(),
                        const SizedBox(height: 12),
                        Text(
                          'LingoDev',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isRegisterMode
                                ? 'Hemen ücretsiz hesap oluştur'
                                : 'İngilizce öğrenmenin en akıllı yolu',
                            key: ValueKey(_isRegisterMode),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // ── E-posta ──────────────────────────────
                        AppInput(
                          labelText: 'E-posta',
                          hintText: 'ornek@email.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline_rounded,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen e-posta adresinizi girin';
                            }
                            if (!value.contains('@')) {
                              return 'Geçerli bir e-posta adresi girin';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // ── Şifre ────────────────────────────────
                        AppInput(
                          labelText: 'Şifre',
                          hintText: '••••••••',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textHint,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen şifrenizi girin';
                            }
                            if (value.length < 6) {
                              return 'Şifre en az 6 karakter olmalı';
                            }
                            return null;
                          },
                        ),

                        // ── Şifremi Unuttum (sadece Giriş modunda) ──
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          crossFadeState: _isRegisterMode
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              child: Text(
                                'Şifremi Unuttum',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          secondChild: const SizedBox(height: 16),
                        ),

                        const SizedBox(height: 8),

                        // ── Ana Buton (Giriş / Kayıt) ────────────
                        AppButton(
                          text: _isRegisterMode ? 'Kayıt Ol' : 'Giriş Yap',
                          icon: _isRegisterMode
                              ? Icons.person_add_rounded
                              : Icons.arrow_forward_rounded,
                          isLoading: _isLoading,
                          onPressed:
                              _isRegisterMode ? _handleRegister : _handleLogin,
                        ),

                        const SizedBox(height: 24),

                        // ── Veya Ayırıcı ─────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color:
                                    AppColors.textHint.withValues(alpha: 0.3),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'veya',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color:
                                    AppColors.textHint.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Google ile Giriş ─────────────────────
                        AppButton(
                          text: 'Google ile Giriş',
                          isOutlined: true,
                          onPressed: () {
                            // TODO: Google sign-in
                          },
                        ),

                        const SizedBox(height: 32),

                        // ── Mod Geçişi (Giriş ↔ Kayıt) ──────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isRegisterMode
                                  ? 'Zaten hesabın var mı? '
                                  : 'Hesabın yok mu? ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: _toggleMode,
                              child: Text(
                                _isRegisterMode ? 'Giriş Yap' : 'Kayıt Ol',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Marka Logosu
  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo_monogram.png',
      height: 140,
      fit: BoxFit.contain,
    );
  }
}
