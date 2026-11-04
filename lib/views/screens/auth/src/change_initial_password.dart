import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';

/// First-login "Change Initial Password" screen.
///
/// Mirrors the Login screen's design:
///  * Wide screens (web / desktop / windows): branding panel on the left and
///    a flush form on the right.
///  * Phones / tablets: brand-tinted backdrop with a single elevated card.
class ChangeInitialPassword extends StatefulWidget {
  final String companyId;
  final EmployeeModel employee;
  const ChangeInitialPassword({
    super.key,
    required this.employee,
    required this.companyId,
  });

  @override
  State<ChangeInitialPassword> createState() => _ChangeInitialPasswordState();
}

class _ChangeInitialPasswordState extends State<ChangeInitialPassword>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmVisible = false;
  bool _isSubmitting = false;

  // Same short, one-shot entrance animation used by the Login screen.
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      futureLoading(context);

      await AuthService.resetPassword(
        emailData: {
          'companyId': widget.companyId,
          'employeeId': widget.employee.uid,
          'name': widget.employee.name,
          'email': widget.employee.email,
        },
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

      if (widget.employee.receiveEmailNotifications) {
        await EmailService.sendEmail(
          to: [widget.employee.email.toString().trim()],
          toName: [widget.employee.name],
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
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        FlushBar.show(
          context,
          "Something went wrong. Try again.",
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _backToLogin() {
    // The Login screen was replaced by this one, so there is nothing to pop
    // back to - go to a fresh Login instead.
    Navigate.routeReplace(context, const Login());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= kAuthWideBreakpoint;

            final Widget animatedFormCard = FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _ChangePasswordFormCard(
                  formKey: _formKey,
                  newPasswordController: _newPassword,
                  confirmPasswordController: _confirmPassword,
                  newPasswordVisible: _passwordVisible,
                  confirmPasswordVisible: _confirmVisible,
                  isSubmitting: _isSubmitting,
                  onToggleNewPassword: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  onToggleConfirmPassword: () =>
                      setState(() => _confirmVisible = !_confirmVisible),
                  onSubmit: _resetPassword,
                  onBackToLogin: _backToLogin,
                  showBrandHeader: !isWide,
                ),
              ),
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: AuthBrandingPanel(fadeAnimation: _fadeAnimation),
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

            return AuthMobileBackdrop(
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

/// The new-password form. Elevated card with a brand header on phones and
/// tablets; flush (card-less) block on wide screens where the branding panel
/// already provides the visual separation.
class _ChangePasswordFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool newPasswordVisible;
  final bool confirmPasswordVisible;
  final bool isSubmitting;
  final VoidCallback onToggleNewPassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onSubmit;
  final VoidCallback onBackToLogin;
  final bool showBrandHeader;

  const _ChangePasswordFormCard({
    required this.formKey,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.newPasswordVisible,
    required this.confirmPasswordVisible,
    required this.isSubmitting,
    required this.onToggleNewPassword,
    required this.onToggleConfirmPassword,
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
            "Change Initial Password",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Enter your new password below and confirm it to complete the "
            "reset process.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            "New Password",
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FormFields(
            controller: newPasswordController,
            enabled: !isSubmitting,
            valid: (value) =>
                Validation.passwordValidation(input: value ?? '', isReq: true),
            keyboardType: TextInputType.visiblePassword,
            hintText: "Enter new password",
            obsecureText: !newPasswordVisible,
            prefixIcon: const Icon(Iconsax.lock, size: 20),
            suffixIcon: IconButton(
              onPressed: isSubmitting ? null : onToggleNewPassword,
              icon: Icon(
                newPasswordVisible ? Iconsax.eye : Iconsax.eye_slash,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Confirm Password",
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FormFields(
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
            hintText: "Re-enter new password",
            obsecureText: !confirmPasswordVisible,
            prefixIcon: const Icon(Iconsax.lock, size: 20),
            suffixIcon: IconButton(
              onPressed: isSubmitting ? null : onToggleConfirmPassword,
              icon: Icon(
                confirmPasswordVisible ? Iconsax.eye : Iconsax.eye_slash,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 26),
          AuthGradientButton(
            label: "Reset Password",
            isLoading: isSubmitting,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: isSubmitting ? null : onBackToLogin,
              icon: const Icon(Iconsax.login, size: 18),
              label: Text("Back to Login", style: theme.textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );

    if (!showBrandHeader) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 36),
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