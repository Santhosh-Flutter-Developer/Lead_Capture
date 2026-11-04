import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';

class CompaniesCreate extends StatefulWidget {
  const CompaniesCreate({super.key});

  @override
  State<CompaniesCreate> createState() => _CompaniesCreateState();
}

class _CompaniesCreateState extends State<CompaniesCreate> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _vScrollController = ScrollController();

  Uint8List? _logoBytes;
  String? _logoUrl;

  bool _isLoading = false;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await Spdb.getUser();

      // Upload logo if provided
      if (_logoBytes != null) {
        // Convert Uint8List to File for upload
        // For now, skip logo upload as it requires File conversion
        // _logoUrl = await StorageService.uploadImage(
        //   file: File.fromRawPath(_logoBytes!),
        //   folder: StorageFolder.companyLogo,
        // );
      }

      final company = CompanyModel(
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
      );

      await CompanyService.createCompany(company: company);

      if (!mounted) return;

      FlushBar.show(context, 'Branch created successfully');
      Navigator.pop(context);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, 'Failed to create branch: $e', isSuccess: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FormWidgets.buildHeader(
        context: context,
        title: "Add New Branch",
      ),
      body: Padding(
        padding: const EdgeInsets.only(right:8.0),
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
                  : Icon(
                      Icons.add_photo_alternate,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
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
            : const Text("Create Company"),
      ),
    );
  }
}
