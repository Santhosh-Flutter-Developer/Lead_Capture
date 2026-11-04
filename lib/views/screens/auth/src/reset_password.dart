import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';

/// Shared brand gradient - identical to the rest of the auth flow so the
/// whole app feels like a single, consistent product.
const List<Color> _kBrandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];

/// Width at which this screen switches from a single centered card
/// (phones/tablets) to a two-pane branding + form layout (web/desktop/windows).
const double _kWideLayoutBreakpoint = 900;

class ResetPassword extends StatefulWidget {
  final Map<String, dynamic> emailData;
  const ResetPassword({super.key, required this.emailData});

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmVisible = false;
  bool _isSubmitting = false;

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

  @override
  void dispose() {
    _entranceController.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_isSubmitting) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        futureLoading(context);

        await AuthService.resetPassword(
          emailData: widget.emailData,
          newPassword: _newPassword.text.trim(),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        FlushBar.show(
          context,
          "Password reset successfully! Please login again.",
          isSuccess: true,
        );

        if (widget.emailData['email'] != null) {
          await EmailService.sendEmail(
            to: [widget.emailData['email'].toString().trim()],
            toName: ["${widget.emailData['name'] ?? 'User'}"],
            subject: "Password Reset Successfully",
            message: EmailTemplates.successResetPassword,
          );
        }

        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          Navigate.routeReplace(context, const Login());
        });
      } catch (e, st) {
        await ErrorService.recordError(e, st);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        FlushBar.show(
          context,
          "Something went wrong. Try again.",
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
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
                child: _ResetPasswordFormCard(
                  formKey: _formKey,
                  newPasswordController: _newPassword,
                  confirmPasswordController: _confirmPassword,
                  passwordVisible: _passwordVisible,
                  confirmVisible: _confirmVisible,
                  isSubmitting: _isSubmitting,
                  onTogglePasswordVisibility: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  onToggleConfirmVisibility: () =>
                      setState(() => _confirmVisible = !_confirmVisible),
                  onSubmit: _resetPassword,
                  onBackToLogin: () =>
                      Navigate.routeReplace(context, const Login()),
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

/// The new/confirm password form. Rendered as an elevated card on
/// phones/tablets, and as a flush (card-less) block on wide screens where
/// the branding panel already provides the visual separation.
class _ResetPasswordFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool passwordVisible;
  final bool confirmVisible;
  final bool isSubmitting;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleConfirmVisibility;
  final VoidCallback onSubmit;
  final VoidCallback onBackToLogin;
  final bool showBrandHeader;

  const _ResetPasswordFormCard({
    required this.formKey,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.passwordVisible,
    required this.confirmVisible,
    required this.isSubmitting,
    required this.onTogglePasswordVisibility,
    required this.onToggleConfirmVisibility,
    required this.onSubmit,
    required this.onBackToLogin,
    required this.showBrandHeader,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            "Reset Password",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 26,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Enter your new password below and confirm it to complete "
            "the reset process.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),
          _LabeledField(
            label: "New Password",
            child: FormFields(
              controller: newPasswordController,
              enabled: !isSubmitting,
              valid: (value) => Validation.passwordValidation(
                input: value ?? '',
                isReq: true,
              ),
              keyboardType: TextInputType.visiblePassword,
              hintText: "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022",
              obsecureText: !passwordVisible,
              prefixIcon: const Icon(Iconsax.lock, size: 20),
              suffixIcon: IconButton(
                onPressed: isSubmitting ? null : onTogglePasswordVisibility,
                icon: Icon(
                  passwordVisible ? Iconsax.eye : Iconsax.eye_slash,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _LabeledField(
            label: "Confirm Password",
            child: FormFields(
              controller: confirmPasswordController,
              enabled: !isSubmitting,
              valid: (value) {
                if ((value ?? '').isEmpty) {
                  return "Confirm password is required";
                } else if (value != newPasswordController.text) {
                  return "Passwords do not match";
                }
                return null;
              },
              keyboardType: TextInputType.visiblePassword,
              hintText: "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022",
              obsecureText: !confirmVisible,
              prefixIcon: const Icon(Iconsax.lock, size: 20),
              suffixIcon: IconButton(
                onPressed: isSubmitting ? null : onToggleConfirmVisibility,
                icon: Icon(
                  confirmVisible ? Iconsax.eye : Iconsax.eye_slash,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _GradientButton(
            label: "Reset Password",
            isLoading: isSubmitting,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: isSubmitting ? null : onBackToLogin,
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
/// setting a new password.
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
                    "Create a new password",
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
                      "Choose a strong new password to keep your account "
                      "safe and secure.",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const _BrandBullet(
                    icon: Iconsax.lock,
                    text: "Use a strong, unique password",
                  ),
                  const SizedBox(height: 14),
                  const _BrandBullet(
                    icon: Iconsax.shield_tick,
                    text: "Keep your account protected",
                  ),
                  const SizedBox(height: 14),
                  const _BrandBullet(
                    icon: Iconsax.flash_1,
                    text: "Sign back in right away",
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
                      key: const ValueKey('label'),
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