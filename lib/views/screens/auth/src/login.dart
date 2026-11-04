import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/theme/src/app_colors.dart';
import 'package:leadcapture/views/screens/auth/src/company_registration.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';

/// Shared brand gradient used by the login button and the wide-screen
/// branding panel so both stay visually consistent across the app.
const List<Color> kAuthBrandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];

/// Width at which the login screen switches from a single centered card
/// (phones/tablets) to a two-pane branding + form layout (web/desktop/windows).
const double kAuthWideBreakpoint = 900;

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  bool _passwordVisible = false;
  bool _isSubmitting = false;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // A single, short-lived entrance animation for the form card. It plays
  // once when the screen first builds and is disposed with the widget, so
  // there is no ongoing animation cost / battery or CPU impact afterwards.
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
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        futureLoading(context);
        String input = _email.text.trim();
        var result = await AuthService.checkLogin(
          email: input,
          password: _password.text.trim(),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (!result["status"]) {
          FlushBar.show(context, result['error'], isSuccess: false);
          return;
        }
        String? companyLogo = result["companyLogo"];
        FlushBar.show(context, "Login Successful");

        bool isEmployee = result.containsKey("userData");
        if (isEmployee) {
          var data = result["userData"];
          var uid = result["uid"];
          EmployeeModel emp = EmployeeModel.fromMap(uid, data);
          if (emp.isInitialPasswordChanged == false) {
            Navigate.routeReplace(
              context,
              ChangeInitialPassword(
                companyId: result["collectionId"],
                employee: emp,
              ),
            );
            return;
          }
          if (emp.receiveEmailNotifications) {
            LoginAlertModel alertInfo =
                await LoginAlertDeviceInfo.getLoginAlertInfo();
            await EmailService.sendEmail(
              to: [emp.email.trim()],
              toName: [emp.name],
              subject: "New login alert",
              message: EmailTemplates.loginAlert
                  .replaceAll("{ip_address}", alertInfo.ipAddress)
                  .replaceAll("{location}", alertInfo.location)
                  .replaceAll("{datetime}", alertInfo.dateTime.listingDateTime)
                  .replaceAll("{device}", alertInfo.device),
            );
          }
          await Spdb.setEmployeeLogin(
            model: emp,
            cid: result["collectionId"],
            logoUrl: companyLogo,
          );
          RoleModel role = await RoleService.getRole(uid: emp.role);
          await PermissionService.savePermissions(role.permissions);
          await CacheService.syncAllCollections();
          if (kIsDesktop) {
            FirestoreNotificationListener.listenForNotifications();
          }
          Navigate.routeReplace(context, MainScreen(isAdmin: false));
          return;
        }

        var data = result["adminData"];
        var uid = result["uid"];
        AdminModel admin = AdminModel.fromMap(uid, data);
        await Spdb.setAdminLogin(
          model: admin,
          cid: result["collectionId"],
          logoUrl: companyLogo,
        );
        // await _storeDeviceLocationOnLogin();
        await PermissionService.savePermissions(AppStrings.permissionsTrueMap);
         // Admin branch was missing this - the employee branch above already
        // syncs lookup data (lead/deal statuses, categories, employees,
        // etc.) before navigating in. Without it here too, an admin's
        // first-ever login of a session lands on a Leads/Deals page with
        // empty filter dropdowns until something else (browser refresh,
        // manual sync, 6-hour timer) triggers a real sync.
        await CacheService.syncAllCollections();
        await AuthService.saveLoginLogs(
          log: LoginLogsModel(
            loginAlert: (await LoginAlertDeviceInfo.getLoginAlertInfo()),
            user: await Spdb.getUser(),
          ),
        );
        if (kIsDesktop) {
          FirestoreNotificationListener.listenForNotifications();
        }
        Navigate.routeReplace(context, MainScreen(isAdmin: true));
      } catch (e, st) {
        // if (Navigator.canPop(context)) {
        //   Navigator.pop(context);
        // }
        await ErrorService.recordError(e, st);
        FlushBar.show(context, e.toString(), isSuccess: false);
      } finally {
        // Always re-enable the button, whether login succeeded, failed, or
        // navigated away and this widget got disposed in between.
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
            final bool isWide = constraints.maxWidth >= kAuthWideBreakpoint;

            final Widget animatedFormCard = FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _LoginFormCard(
                  formKey: _formKey,
                  emailController: _email,
                  passwordController: _password,
                  passwordVisible: _passwordVisible,
                  isSubmitting: _isSubmitting,
                  onTogglePasswordVisibility: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  onSubmit: _submitForm,
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

/// The actual email/password form. Rendered as an elevated card on
/// phones/tablets, and as a flush (card-less) block inside the right pane on
/// wide screens where the branding panel already provides visual separation.
class _LoginFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final bool isSubmitting;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;
  final bool showBrandHeader;

  const _LoginFormCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.isSubmitting,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
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
            "Login",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Sign in to continue to your dashboard.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: isSubmitting
                    ? null
                    : () =>
                          Navigate.route(context, const CompanyRegistration()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 2,
                  ),
                  child: Text(
                    "Register",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "Email ID",
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FormFields(
            controller: emailController,
            enabled: !isSubmitting,
            autofocus: false,
            valid: (value) =>
                Validation.validEmail(input: value ?? '', isReq: true),
            keyboardType: TextInputType.emailAddress,
            hintText: "Enter Email ID",
            prefixIcon: const Icon(Iconsax.user, size: 20),
          ),
          const SizedBox(height: 18),
          Text(
            "Password",
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FormFields(
            valid: (value) => Validation.commonValidation(
              input: value ?? '',
              isReq: true,
              label: "Password",
            ),
            controller: passwordController,
            enabled: !isSubmitting,
            keyboardType: TextInputType.visiblePassword,
            hintText: "Enter password",
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
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigate.route(context, const ForgotPassword()),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                "Forgot Password?",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          AuthGradientButton(
            label: "Login",
            isLoading: isSubmitting,
            onPressed: onSubmit,
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

/// Subtle, static, brand-tinted backdrop used behind the login card on
/// phones/tablets so the screen doesn't feel flat and empty. Purely
/// decorative — a gradient wash plus two soft circles, no animation and no
/// ongoing rendering cost.
class AuthMobileBackdrop extends StatelessWidget {
  final Widget child;

  const AuthMobileBackdrop({super.key, required this.child});

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

/// Left-hand branding panel shown on wide (web/desktop/windows) screens.
/// Purely decorative and static aside from a single shared fade-in, so it
/// adds no meaningful rendering cost.
class AuthBrandingPanel extends StatelessWidget {
  final Animation<double> fadeAnimation;

  const AuthBrandingPanel({super.key, required this.fadeAnimation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: kAuthBrandGradient,
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
                    "Lead Capture CRM",
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
                      "Manage your leads, deals, tasks and teams in one "
                      "professional workspace built for growing businesses.",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const AuthBrandBullet(
                    icon: Iconsax.graph,
                    text: "Track leads & deals in real time",
                  ),
                  const SizedBox(height: 14),
                  const AuthBrandBullet(
                    icon: Iconsax.task,
                    text: "Assign & monitor team tasks",
                  ),
                  const SizedBox(height: 14),
                  const AuthBrandBullet(
                    icon: Iconsax.shield_tick,
                    text: "Secure, role-based access",
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

class AuthBrandBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const AuthBrandBullet({super.key, required this.icon, required this.text});

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

/// Login button with the app's brand gradient, a subtle press-scale
/// micro-interaction, and an inline loading/disabled state. The animation is
/// driven purely by local widget state (no timers, no repeating animation),
/// so it costs nothing once idle.
class AuthGradientButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const AuthGradientButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<AuthGradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<AuthGradientButton> {
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
                    : kAuthBrandGradient,
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