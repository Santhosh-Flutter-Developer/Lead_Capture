import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';

class CompanyEdit extends StatefulWidget {
  final String uid;

  const CompanyEdit({super.key, required this.uid});

  @override
  State<CompanyEdit> createState() => _CompanyEditState();
}

class _CompanyEditState extends State<CompanyEdit> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _vScrollController = ScrollController();

  Uint8List? _logoBytes;
  String? _logoUrl;
  bool _withoutLoginEnabled = false;
  String _notificationLanguage = 'en';
  final _kioskUsernameController = TextEditingController();
final _kioskPasswordController = TextEditingController();

  bool _isLoading = false;
  CompanyModel? _company;
  bool _isCheckingUsername = false;
  String? _usernameAvailabilityMessage;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    try {
      final company = await CompanyService.getCompany(uid: widget.uid);
      setState(() {
        _company = company;
        _nameController.text = company.name;
        _branchCodeController.text = company.branchCode ?? '';
        _phoneController.text = company.phone ?? '';
        _emailController.text = company.email ?? '';
        _gstinController.text = company.gstin ?? '';
        _addressController.text = company.address ?? '';
        _countryController.text = company.country ?? '';
        _stateController.text = company.state ?? '';
        _cityController.text = company.city ?? '';
        _pincodeController.text = company.pincode ?? '';
        _logoUrl = company.logoUrl;
        _withoutLoginEnabled = company.withoutLoginEnabled;
        _notificationLanguage = company.notificationLanguage;
        _kioskUsernameController.text = company.kioskUsername ?? '';
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, 'Failed to load company: $e', isSuccess: false);
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.trim().isEmpty) {
      setState(() {
        _usernameAvailabilityMessage = null;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameAvailabilityMessage = null;
    });

    try {
      final isAvailable = await CompanyService.isKioskUsernameAvailable(
        username,
        widget.uid,
      );

      if (!mounted) return;

      setState(() {
        _usernameAvailabilityMessage = isAvailable
            ? 'Username is available'
            : 'Username is already taken';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usernameAvailabilityMessage = 'Error checking username';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _branchCodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _kioskUsernameController.dispose();
    _kioskPasswordController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _logoBytes = bytes;
      });
    }
  }

  Future<void> _deleteLogo() async {
    try {
      await CompanyService.deleteCompanyLogo(uid: widget.uid);
      setState(() {
        _logoUrl = null;
        _logoBytes = null;
      });
      FlushBar.show(context, 'Logo deleted successfully');
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      FlushBar.show(context, 'Failed to delete logo: $e', isSuccess: false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await Spdb.getUser();

      // Upload new logo if provided
      if (_logoBytes != null) {
        // Convert Uint8List to File for upload
        // For now, skip logo upload as it requires File conversion
        // _logoUrl = await StorageService.uploadImage(
        //   file: File.fromRawPath(_logoBytes!),
        //   folder: StorageFolder.companyLogo,
        // );
      }

      final company = CompanyModel(
        uid: widget.uid,
        name: _nameController.text.trim(),
        branchCode: _branchCodeController.text.trim().isEmpty
            ? null
            : _branchCodeController.text.trim(),
        logoUrl: _logoUrl,
        gstin: _gstinController.text.trim().isEmpty
            ? null
            : _gstinController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        country: _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        pincode: _pincodeController.text.trim().isEmpty
            ? null
            : _pincodeController.text.trim(),
        createdBy: user,
        withoutLoginEnabled: _withoutLoginEnabled,
        notificationLanguage: _notificationLanguage,
        kioskUsername:
            _withoutLoginEnabled &&
                _kioskUsernameController.text.trim().isNotEmpty
            ? _kioskUsernameController.text.trim()
            : null,
        createdAt: _company?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await CompanyService.updateCompany(uid: widget.uid, company: company);

      if (!mounted) return;

      FlushBar.show(context, 'Company updated successfully');
      Navigator.pop(context);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, 'Failed to update company: $e', isSuccess: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_company == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: FormWidgets.buildHeader(context: context, title: "Edit Company"),
      body: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Scrollbar(
                      controller: _vScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
            controller: _vScrollController,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogoSection(),
                  const SizedBox(height: 24),
                  _buildBasicInfoSection(),
                  const SizedBox(height: 24),
                  _buildContactInfoSection(),
                  const SizedBox(height: 24),
                  _buildAddressSection(),
                  const SizedBox(height: 24),
                  _buildKioskSection(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Company Logo",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: _pickLogo,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: _logoBytes != null
                      ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                      : _logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _logoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Icon(
                          Icons.add_photo_alternate,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              if (_logoUrl != null)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteLogo,
                  tooltip: 'Delete Logo',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection("Basic Information", Icons.info_outline, [
      FormFields(
        controller: _nameController,
        label: "Company Name",
        isRequired: true,
        valid: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Company name is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      FormFields(controller: _branchCodeController, label: "Branch Code"),
      const SizedBox(height: 16),
      FormFields(controller: _gstinController, label: "GSTIN"),
    ]);
  }

  Widget _buildContactInfoSection() {
    return _buildSection("Contact Information", Icons.contact_phone, [
      FormFields(
        controller: _phoneController,
        label: "Phone",
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 16),
      FormFields(
        controller: _emailController,
        label: "Email",
        keyboardType: TextInputType.emailAddress,
      ),
    ]);
  }

  Widget _buildAddressSection() {
    return _buildSection("Address Information", Icons.location_on, [
      FormFields(controller: _addressController, label: "Address", maxLines: 2),
      const SizedBox(height: 16),
      FormFields(controller: _countryController, label: "Country"),
      const SizedBox(height: 16),
      FormFields(controller: _stateController, label: "State"),
      const SizedBox(height: 16),
      FormFields(controller: _cityController, label: "City"),
      const SizedBox(height: 16),
      FormFields(
        controller: _pincodeController,
        label: "Pincode",
        keyboardType: TextInputType.number,
      ),
    ]);
  }

  Widget _buildKioskSection() {
    return _buildSection("Kiosk Settings", Icons.no_accounts, [
      Row(
        children: [
          Checkbox(
            value: _withoutLoginEnabled,
            onChanged: (value) {
              setState(() {
                _withoutLoginEnabled = value ?? false;
              });
            },
          ),
          const SizedBox(width: 8),
          Text(
            "Enable Without Login",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (_withoutLoginEnabled) ...[
        FormFields(
          controller: _kioskUsernameController,
          label: "Kiosk Username",
          isRequired: true,
          valid: (value) {
            if (_withoutLoginEnabled &&
                (value == null || value.trim().isEmpty)) {
              return 'Kiosk username is required when without login is enabled';
            }
            if (_usernameAvailabilityMessage == 'Username is already taken') {
              return 'Username is already taken';
            }
            return null;
          },
          onChanged: (value) {
            if (value.trim().isNotEmpty) {
              _checkUsernameAvailability(value.trim());
            }
          },
        ),
        if (_usernameAvailabilityMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (_isCheckingUsername)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  _usernameAvailabilityMessage == 'Username is available'
                      ? Icons.check_circle
                      : Icons.error,
                  color: _usernameAvailabilityMessage == 'Username is available'
                      ? Colors.green
                      : Colors.red,
                  size: 16,
                ),
              const SizedBox(width: 8),
              Text(
                _usernameAvailabilityMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _usernameAvailabilityMessage == 'Username is available'
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        FormFields(
          controller: _kioskPasswordController,
          label: "Kiosk Password (leave empty to keep existing)",
          obsecureText: true,
        ),
        const SizedBox(height: 16),
        Text(
          "Notification Language",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Radio<String>(
              value: 'en',
              groupValue: _notificationLanguage,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _notificationLanguage = value;
                  });
                }
              },
            ),
            const Text('English'),
            const SizedBox(width: 16),
            Radio<String>(
              value: 'ta',
              groupValue: _notificationLanguage,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _notificationLanguage = value;
                  });
                }
              },
            ),
            const Text('Tamil (தமிழ்)'),
          ],
        ),
      ],
    ]);
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text("Update Company"),
      ),
    );
  }
}
