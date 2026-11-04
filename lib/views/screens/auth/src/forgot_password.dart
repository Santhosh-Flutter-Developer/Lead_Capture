import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:pinput/pinput.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';

/// Shared brand gradient - identical to the login and registration screens
/// so the whole auth flow feels like one consistent product.
const List<Color> _kBrandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];

/// Width at which this screen switches from a single centered card
/// (phones/tablets) to a two-pane branding + form layout (web/desktop/windows).
const double _kWideLayoutBreakpoint = 900;

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword>
    with SingleTickerProviderStateMixin {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _otp = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _emailVerified = false;
  Map<String, dynamic>? _emailData;
  bool _otpSent = false;
  String? _generatedOtp;
  Timer? _timer;
  int _remainingTime = 0;
  bool _isProcessing = false;

  // One-shot entrance animation for the card, identical approach to the
  // rest of the auth flow. Plays once on load and is fully disposed
  // afterwards, so it has no ongoing performance cost.
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _entranceController.forward();
  }

  Future<void> _verifyEmail() async {
    if (_isProcessing) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_emailVerified) {
      setState(() => _isProcessing = true);
      try {
        futureLoading(context);

        final emailData = await AuthService.checkEmailExists(
          email: _email.text.trim(),
        );
        if (emailData == null) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          FlushBar.show(
            context,
            "Email not found. Please check and try again.",
            isSuccess: false,
          );
          return;
        } else {
          setState(() {
            _emailVerified = true;
            _emailData = emailData;
          });
        }
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } catch (e, st) {
        await ErrorService.recordError(e, st);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        FlushBar.show(
          context,
          e.toString(),
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  /// Send OTP via email
  Future<void> _sendOtp() async {
    if (_isProcessing) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);
    try {
      futureLoading(context);

      final otp = (100000 + Random().nextInt(900000)).toString();
      _generatedOtp = otp;

      final response = await EmailService.sendEmail(
        to: [_email.text.trim()],
        toName: ["${_emailData?['name'] ?? 'User'}"],
        subject: "OTP for Password Reset",
        message: EmailTemplates.otpEmail.replaceAll("{otp_code}", otp),
      );

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (response) {
        setState(() {
          _otpSent = true;
          _remainingTime = 120; // 2 minutes
        });
        _startTimer();

        FlushBar.show(context, 'OTP sent successfully to your email.');
      } else {
        FlushBar.show(
          context,
          "Failed to send OTP. Try again.",
          isSuccess: false,
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Timer countdown for OTP expiry
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime == 0) {
        timer.cancel();
        setState(() {
          _generatedOtp = null;
        });
      } else {
        setState(() => _remainingTime--);
      }
    });
  }

  /// Verify OTP entered by user
  void _verifyOtp() {
    if (_generatedOtp == null) {
      FlushBar.show(context, "OTP expired. Please resend.", isSuccess: false);
      return;
    }

    if (_otp.text.trim() == _generatedOtp) {
      FlushBar.show(context, "OTP verified successfully!");
      _timer?.cancel();
      Navigate.route(context, ResetPassword(emailData: _emailData ?? {}));
    } else {
      FlushBar.show(
        context,
        "Invalid OTP. Please try again.",
        isSuccess: false,
      );
    }
  }

  /// Resend OTP after cooldown (only after 60s)
  Future<void> _resendOtp() async {
    if (_remainingTime > 60) {
      FlushBar.show(
        context,
        "Please wait before resending OTP.",
        isSuccess: false,
      );
      return;
    }
    await _sendOtp();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _timer?.cancel();
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= _kWideLayoutBreakpoint;

            final Widget animatedFormCard = FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _ForgotPasswordFormCard(
                  formKey: _formKey,
                  emailController: _email,
                  otpController: _otp,
                  emailVerified: _emailVerified,
                  otpSent: _otpSent,
                  generatedOtpActive: _generatedOtp != null,
                  remainingTime: _remainingTime,
                  isProcessing: _isProcessing,
                  onPrimaryAction: _emailVerified
                      ? (_otpSent ? _verifyOtp : _sendOtp)
                      : _verifyEmail,
                  onResendOtp: _resendOtp,
                  onBackToLogin: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  showBrandHeader: !isWide,
                ),
              ),
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _BrandingPanel(fadeAnimation: _fadeAnimation),
                  ),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 32,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: animatedFormCard,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return _MobileBackdrop(
              child: Center(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: animatedFormCard,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The email -> verify -> OTP form. Rendered as an elevated card on
/// phones/tablets, and as a flush (card-less) block on wide screens where
/// the branding panel already provides the visual separation.
class _ForgotPasswordFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController otpController;
  final bool emailVerified;
  final bool otpSent;
  final bool generatedOtpActive;
  final int remainingTime;
  final bool isProcessing;
  final VoidCallback onPrimaryAction;
  final VoidCallback onResendOtp;
  final VoidCallback onBackToLogin;
  final bool showBrandHeader;

  const _ForgotPasswordFormCard({
    required this.formKey,
    required this.emailController,
    required this.otpController,
    required this.emailVerified,
    required this.otpSent,
    required this.generatedOtpActive,
    required this.remainingTime,
    required this.isProcessing,
    required this.onPrimaryAction,
    required this.onResendOtp,
    required this.onBackToLogin,
    required this.showBrandHeader,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String buttonLabel = emailVerified
        ? (otpSent ? "Verify OTP" : "Send OTP")
        : "Verify User";

    final Widget content = Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBrandHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  ImageAssets.logoTransparent,
                  height: 44,
                  width: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Lead Capture CRM",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        "Sales & lead management",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 26),
          ],
          Text(
            "Forgot Password",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 26,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Enter your registered email to receive a one-time "
            "verification code.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 26),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LabeledField(
                  label: "Email",
                  child: FormFields(
                    controller: emailController,
                    enabled: !isProcessing,
                    valid: (value) =>
                        Validation.validEmail(input: value, isReq: true),
                    keyboardType: TextInputType.emailAddress,
                    hintText: "example@domain.com",
                    prefixIcon: const Icon(Iconsax.sms, size: 20),
                  ),
                ),
                if (emailVerified) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "User verified",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (otpSent) ...[
                  const SizedBox(height: 24),
                  Text(
                    "Enter OTP",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Pinput(
                      length: 6,
                      controller: otpController,
                      enabled: !isProcessing,
                      keyboardType: TextInputType.number,
                      defaultPinTheme: PinTheme(
                        width: 50,
                        height: 56,
                        textStyle: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.grey100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey400),
                        ),
                      ),
                      focusedPinTheme: PinTheme(
                        width: 50,
                        height: 56,
                        textStyle: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!generatedOtpActive)
                        TextButton(
                          onPressed: isProcessing ? null : onResendOtp,
                          child: Text(
                            "Resend OTP",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Text(
                          "Expires in ${remainingTime}s",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
          _GradientButton(
            label: buttonLabel,
            isLoading: isProcessing,
            onPressed: onPrimaryAction,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: isProcessing ? null : onBackToLogin,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Iconsax.login, size: 18),
              label: Text("Back to Login", style: theme.textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );

    if (!showBrandHeader) {
      // Wide-screen right pane: no extra card box, the branding panel on the
      // left already provides the visual separation.
      return content;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: content,
    );
  }
}

/// Small reusable "label above field" wrapper, styled identically across
/// the whole auth flow.
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Subtle, static, brand-tinted backdrop used behind the card on
/// phones/tablets - identical treatment across the auth flow. No animation,
/// no ongoing rendering cost.
class _MobileBackdrop extends StatelessWidget {
  final Widget child;

  const _MobileBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5],
                colors: [
                  AppColors.primary.withValues(alpha: 0.07),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
        ),
        Positioned(top: -70, right: -60, child: _softCircle(200)),
        Positioned(top: 60, left: -80, child: _softCircle(140)),
        child,
      ],
    );
  }

  Widget _softCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.05),
      ),
    );
  }
}

/// Left-hand branding panel shown on wide (web/desktop/windows) screens -
/// same visual language as the rest of the auth flow, with copy tailored to
/// password recovery.
class _BrandingPanel extends StatelessWidget {
  final Animation<double> fadeAnimation;

  const _BrandingPanel({required this.fadeAnimation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _kBrandGradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -60, right: -40, child: _softCircle(180)),
          Positioned(bottom: -90, left: -70, child: _softCircle(230)),
          Positioned(bottom: 130, right: 50, child: _softCircle(90)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
            child: FadeTransition(
              opacity: fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      ImageAssets.logoTransparent,
                      height: 46,
                      width: 46,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Reset your password",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Text(
                      "We'll send a secure one-time code to your email so "
                      "you can safely get back into your account.",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const _BrandBullet(
                    icon: Iconsax.sms,
                    text: "Verify with your registered email",
                  ),
                  const SizedBox(height: 14),
                  const _BrandBullet(
                    icon: Iconsax.shield_tick,
                    text: "Secure one-time password verification",
                  ),
                  const SizedBox(height: 14),
                  const _BrandBullet(
                    icon: Iconsax.flash_1,
                    text: "Get back into your account in minutes",
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 56,
            bottom: 28,
            child: Text(
              "\u00A9 ${DateTime.now().year} Lead Capture CRM. All rights reserved.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}

class _BrandBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BrandBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient button with a subtle press-scale micro-interaction and an
/// inline loading/disabled state - the exact same component style used
/// throughout the auth flow.
class _GradientButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  double _scale = 1;

  void _setPressed(bool pressed) {
    if (widget.isLoading) return;
    setState(() => _scale = pressed ? 0.97 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.isLoading;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => _setPressed(true),
        onTapCancel: disabled ? null : () => _setPressed(false),
        onTapUp: disabled ? null : (_) => _setPressed(false),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: disabled
                    ? [AppColors.grey400, AppColors.grey300]
                    : _kBrandGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: disabled
                  ? const []
                  : [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.label,
                      key: ValueKey(widget.label),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}