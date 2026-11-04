import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:leadcapture/theme/src/app_colors.dart';
import 'package:leadcapture/utils/src/assets.dart';
import 'package:leadcapture/utils/src/validation.dart';
import 'package:leadcapture/views/screens/auth/src/login.dart';
import 'package:leadcapture/views/ui/src/flush_bar.dart';
import 'package:leadcapture/views/ui/src/form_fields.dart';
import 'package:leadcapture/views/ui/src/loading.dart';
import '/services/services.dart';

/// Shared brand gradient - kept identical to the one used on the login
/// screen so the whole auth flow feels like a single, consistent product.
const List<Color> _kBrandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];

/// Width at which this screen switches from a single centered card
/// (phones/tablets) to a two-pane branding + form layout (web/desktop/windows).
const double _kWideLayoutBreakpoint = 900;

class CompanyRegistration extends StatefulWidget {
  const CompanyRegistration({super.key});

  @override
  State<CompanyRegistration> createState() => _CompanyRegistrationState();
}

class _CompanyRegistrationState extends State<CompanyRegistration>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Controllers
  final TextEditingController _companyName = TextEditingController();
  final TextEditingController _companyEmail = TextEditingController();
  final TextEditingController _adminName = TextEditingController();
  final TextEditingController _adminEmail = TextEditingController();
  final TextEditingController _password = TextEditingController();

  File? _logo;
  Uint8List? _logoBytes;
  bool _passwordVisible = false;
  bool _isSubmitting = false;

  // One-shot entrance animation for the card, identical approach to the
  // login screen. Plays once on load and is fully disposed afterwards, so
  // it has no ongoing performance cost.
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
    _companyName.dispose();
    _companyEmail.dispose();
    _adminName.dispose();
    _adminEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearForm() {
    _companyName.clear();
    _companyEmail.clear();
    _adminName.clear();
    _adminEmail.clear();
    _password.clear();

    setState(() {
      _logo = null;
      _logoBytes = null;
      _passwordVisible = false;
      _currentStep = 0;
    });

    _formKey.currentState?.reset();
  }

  Future<void> _pickImage() async {
    if (_isSubmitting) return;
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        if (!kIsWeb) {
          _logo = File(image.path);
        } else {
          _logoBytes = bytes;
        }
      });
    }
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        futureLoading(context);
        final existingAdmin = await AuthService.checkEmailExists(
          email: _adminEmail.text.trim(),
        );

        if (existingAdmin != null) {
          if (Navigator.canPop(context)) Navigator.pop(context);

          FlushBar.show(
            context,
            "Admin email already exists",
            isSuccess: false,
          );

          return;
        }

        var result = await AuthService.registerCompany(
          name: _companyName.text.trim(),
          adminEmail: _adminEmail.text.trim(),
          adminName: _adminName.text.trim(),
          password: _password.text.trim(),
          logo: kIsWeb ? null : _logo,
          logoBytes: kIsWeb ? _logoBytes : null,
        );

        if (Navigator.canPop(context)) Navigator.pop(context);

        if (result["status"]) {
          FlushBar.show(context, result["message"], isSuccess: true);
          _clearForm();
          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Login()),
            );
          });
        } else {
          FlushBar.show(context, result['error'], isSuccess: false);
        }
      } catch (e, st) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        await ErrorService.recordError(e, st);
        FlushBar.show(context, e.toString(), isSuccess: false);
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  void _goToNextStep() {
    if (_isSubmitting) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _currentStep++);
    }
  }

  void _goToPreviousStep() {
    if (_isSubmitting) return;
    setState(() => _currentStep--);
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
                child: _RegistrationFormCard(
                  formKey: _formKey,
                  currentStep: _currentStep,
                  isSubmitting: _isSubmitting,
                  logo: _logo,
                  logoBytes: _logoBytes,
                  passwordVisible: _passwordVisible,
                  companyNameController: _companyName,
                  companyEmailController: _companyEmail,
                  adminNameController: _adminName,
                  adminEmailController: _adminEmail,
                  passwordController: _password,
                  onPickImage: _pickImage,
                  onTogglePasswordVisibility: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  onNext: _goToNextStep,
                  onBack: _goToPreviousStep,
                  onSubmit: _handleRegister,
                  onBackToLogin: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
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
                            constraints: const BoxConstraints(maxWidth: 460),
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
                      constraints: const BoxConstraints(maxWidth: 460),
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

/// The registration form itself: header, stepper, step content and
/// navigation buttons. Rendered as an elevated card on phones/tablets, and
/// as a flush (card-less) block on wide screens where the branding panel
/// already provides the visual separation.
class _RegistrationFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final int currentStep;
  final bool isSubmitting;
  final File? logo;
  final Uint8List? logoBytes;
  final bool passwordVisible;
  final TextEditingController companyNameController;
  final TextEditingController companyEmailController;
  final TextEditingController adminNameController;
  final TextEditingController adminEmailController;
  final TextEditingController passwordController;
  final VoidCallback onPickImage;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final VoidCallback onBackToLogin;
  final bool showBrandHeader;

  const _RegistrationFormCard({
    required this.formKey,
    required this.currentStep,
    required this.isSubmitting,
    required this.logo,
    required this.logoBytes,
    required this.passwordVisible,
    required this.companyNameController,
    required this.companyEmailController,
    required this.adminNameController,
    required this.adminEmailController,
    required this.passwordController,
    required this.onPickImage,
    required this.onTogglePasswordVisibility,
    required this.onNext,
    required this.onBack,
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
            "Register Company",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 26,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Set up your company and admin account to get started.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 26),
          _RegistrationStepper(currentStep: currentStep),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: currentStep == 0
                ? _CompanyDetailsStep(
                    key: const ValueKey('company-step'),
                    isSubmitting: isSubmitting,
                    logo: logo,
                    logoBytes: logoBytes,
                    onPickImage: onPickImage,
                    companyNameController: companyNameController,
                    companyEmailController: companyEmailController,
                  )
                : _AdminSetupStep(
                    key: const ValueKey('admin-step'),
                    isSubmitting: isSubmitting,
                    passwordVisible: passwordVisible,
                    onTogglePasswordVisibility: onTogglePasswordVisibility,
                    adminNameController: adminNameController,
                    adminEmailController: adminEmailController,
                    passwordController: passwordController,
                  ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              if (currentStep > 0) ...[
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onBack,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        foregroundColor: theme.colorScheme.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Back",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: currentStep > 0 ? 1 : 1,
                child: _GradientButton(
                  label: currentStep < 1 ? "Next" : "Create Account",
                  isLoading: isSubmitting,
                  onPressed: currentStep < 1 ? onNext : onSubmit,
                ),
              ),
            ],
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

/// Step 1 fields: logo picker + company details.
class _CompanyDetailsStep extends StatelessWidget {
  final bool isSubmitting;
  final File? logo;
  final Uint8List? logoBytes;
  final VoidCallback onPickImage;
  final TextEditingController companyNameController;
  final TextEditingController companyEmailController;

  const _CompanyDetailsStep({
    super.key,
    required this.isSubmitting,
    required this.logo,
    required this.logoBytes,
    required this.onPickImage,
    required this.companyNameController,
    required this.companyEmailController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasImage = logoBytes != null || logo != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: GestureDetector(
            onTap: isSubmitting ? null : onPickImage,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                    image: hasImage
                        ? DecorationImage(
                            image: logoBytes != null
                                ? MemoryImage(logoBytes!)
                                : FileImage(logo!) as ImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? null
                      : Icon(
                          Iconsax.camera,
                          color: AppColors.primary,
                          size: 26,
                        ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Iconsax.edit_2,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            "Company logo (optional)",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SectionLabel("Company Details"),
        const SizedBox(height: 4),
        _LabeledField(
          label: "Company Name",
          child: FormFields(
            controller: companyNameController,
            enabled: !isSubmitting,
            hintText: "Enter Company Name",
            prefixIcon: const Icon(Iconsax.box, size: 20),
            valid: (value) => Validation.commonValidation(
              input: value?.trim() ?? '',
              isReq: true,
              label: "Company Name",
            ),
          ),
        ),
        const SizedBox(height: 18),
        _LabeledField(
          label: "Business Email",
          child: FormFields(
            controller: companyEmailController,
            enabled: !isSubmitting,
            keyboardType: TextInputType.emailAddress,
            hintText: "Enter Business Email",
            prefixIcon: const Icon(Iconsax.sms, size: 20),
            valid: (value) => Validation.validEmail(input: value, isReq: true),
          ),
        ),
      ],
    );
  }
}

/// Step 2 fields: admin account setup.
class _AdminSetupStep extends StatelessWidget {
  final bool isSubmitting;
  final bool passwordVisible;
  final VoidCallback onTogglePasswordVisibility;
  final TextEditingController adminNameController;
  final TextEditingController adminEmailController;
  final TextEditingController passwordController;

  const _AdminSetupStep({
    super.key,
    required this.isSubmitting,
    required this.passwordVisible,
    required this.onTogglePasswordVisibility,
    required this.adminNameController,
    required this.adminEmailController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel("Super Admin Setup"),
        const SizedBox(height: 4),
        _LabeledField(
          label: "Full Name",
          child: FormFields(
            controller: adminNameController,
            enabled: !isSubmitting,
            hintText: "Enter Full Name",
            prefixIcon: const Icon(Iconsax.user, size: 20),
            valid: (value) => Validation.commonValidation(
              input: value?.trim() ?? '',
              isReq: true,
              label: "Full Name",
            ),
          ),
        ),
        const SizedBox(height: 18),
        _LabeledField(
          label: "Admin Email",
          child: FormFields(
            controller: adminEmailController,
            enabled: !isSubmitting,
            keyboardType: TextInputType.emailAddress,
            hintText: "Enter Admin Email",
            prefixIcon: const Icon(Iconsax.sms, size: 20),
            valid: (value) => Validation.validEmail(input: value, isReq: true),
          ),
        ),
        const SizedBox(height: 18),
        _LabeledField(
          label: "Admin Password",
          child: FormFields(
            controller: passwordController,
            enabled: !isSubmitting,
            obsecureText: !passwordVisible,
            hintText: "Create password",
            prefixIcon: const Icon(Iconsax.lock, size: 20),
            suffixIcon: IconButton(
              onPressed: isSubmitting ? null : onTogglePasswordVisibility,
              icon: Icon(
                passwordVisible ? Iconsax.eye : Iconsax.eye_slash,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            valid: (value) =>
                Validation.passwordValidation(input: value, isReq: true),
          ),
        ),
      ],
    );
  }
}

/// Small reusable "label above field" wrapper, styled identically to the
/// login screen's fields for visual consistency across the auth flow.
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

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: AppColors.primary,
      ),
    );
  }
}

/// Two-node progress stepper ("Company" -> "Admin"), themed with the app's
/// brand color instead of hardcoded Material colors.
class _RegistrationStepper extends StatelessWidget {
  final int currentStep;

  const _RegistrationStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = ["Company", "Admin"];
    final inactiveColor = theme.colorScheme.outlineVariant;
    final textInactiveColor = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        // Even indices = step nodes, odd indices = connector lines.
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          final isCompleted = stepIndex < currentStep;
          final isActive =
              stepIndex == currentStep - 1 || stepIndex == currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 2,
              margin: const EdgeInsets.only(bottom: 24),
              color: isCompleted || isActive
                  ? AppColors.primary
                  : inactiveColor,
            ),
          );
        }

        final index = i ~/ 2;
        final isCompleted = index < currentStep;
        final isActive = index == currentStep;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted || isActive
                    ? AppColors.primary
                    : theme.colorScheme.surface,
                border: Border.all(
                  color: isCompleted || isActive
                      ? AppColors.primary
                      : inactiveColor,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : textInactiveColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              steps[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isCompleted || isActive
                    ? AppColors.primary
                    : textInactiveColor,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Subtle, static, brand-tinted backdrop used behind the card on
/// phones/tablets - identical treatment to the login screen so the whole
/// auth flow feels visually unified. No animation, no ongoing cost.
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
/// same visual language as the login screen's panel, with copy tailored to
/// registration.
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
                    "Create your company",
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
                      "Set up your workspace in minutes and start managing "
                      "leads, deals and your team the professional way.",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const _BrandBullet(
                    icon: Iconsax.buildings,
                    text: "Create your company profile",
                  ),
                  const SizedBox(height: 14),
                  const _BrandBullet(
                    icon: Iconsax.security_user,
                    text: "Set up a secure admin account",
                  ),
                  const SizedBox(height: 14),
                  const _BrandBullet(
                    icon: Iconsax.flash_1,
                    text: "Start capturing leads instantly",
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
/// inline loading/disabled state - the exact same component style used on
/// the login screen, for a consistent feel across the auth flow.
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