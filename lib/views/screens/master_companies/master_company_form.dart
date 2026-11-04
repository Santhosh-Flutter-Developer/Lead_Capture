import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/views/screens/leads/form/lead_form_ui.dart';

/// Master Company create / edit form.
///
/// Pass [uid] to edit. Pops with `{"status": true, "company": model}`.
class MasterCompanyForm extends StatefulWidget {
  final String? uid;
  const MasterCompanyForm({super.key, this.uid});

  @override
  State<MasterCompanyForm> createState() => _MasterCompanyFormState();
}

class _MasterCompanyFormState extends State<MasterCompanyForm> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _vScroll = ScrollController();

  final _companyName = TextEditingController();
  final _gst = TextEditingController();
  final _contactName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _postal = TextEditingController();

  // Location hierarchy: Country -> State -> District -> City.
  RegionModel? _country;
  StateModel? _state;
  DistrictModel? _district;
  CityModel? _city;

  List<RegionModel> _countries = [];
  List<StateModel> _states = [];
  List<DistrictModel> _districts = [];
  List<CityModel> _cities = [];
  List<String> _countryNames = [];
  List<String> _stateNames = [];
  List<String> _districtNames = [];
  List<String> _cityNames = [];

  MasterCompanyModel? _company;
  Uint8List? _newLogo; // freshly picked logo
  bool _removeLogo = false;
  late Future<void> _future;

  bool get _isEdit => (widget.uid ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _vScroll.dispose();
    _companyName.dispose();
    _gst.dispose();
    _contactName.dispose();
    _mobile.dispose();
    _email.dispose();
    _address.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _countries = await RegionDataService.getCountries();
      _countryNames = _countries.map((e) => e.name).toList();
      // India is pre-selected by default.
      _country = await RegionDataService.getDefaultCountry();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }

    if (!_isEdit) {
      await _loadStates();
      return;
    }
    try {
      final c = await MasterCompanyService.get(uid: widget.uid!);
      _company = c;
      // Restore the saved location (older records may not have one).
      _country = c.country ?? _country;
      _state = c.state;
      _district = c.district;
      _city = c.city;
      await _loadStates();
      await _loadDistricts();
      await _loadCities();
      _postal.text = c.postalCode ?? '';
      _companyName.text = c.companyName;
      _gst.text = c.gstVatNumber ?? '';
      _contactName.text = c.contactName;
      _mobile.text = c.mobileNumber;
      _email.text = c.email ?? '';
      _address.text = c.companyAddress ?? '';
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _loadStates() async {
    _states = await RegionDataService.getStates(country: _country?.name);
    _stateNames = _states.map((e) => e.name).toList();
  }

  Future<void> _loadDistricts() async {
    _districts = await RegionDataService.getDistricts(
      country: _country?.name,
      state: _state?.name,
    );
    _districtNames = _districts.map((e) => e.name).toList();
  }

  Future<void> _loadCities() async {
    _cities = await RegionDataService.getCities(
      country: _country?.name,
      state: _state?.name,
      district: _district?.name,
    );
    _cityNames = _cities.map((e) => e.name).toList();
  }

  Future<void> _onCountryChanged(String? name) async {
    _country = _countries.where((e) => e.name == name).firstOrNull;
    _state = null;
    _district = null;
    _city = null;
    _districts = [];
    _districtNames = [];
    _cities = [];
    _cityNames = [];
    await _loadStates();
    if (mounted) setState(() {});
  }

  Future<void> _onStateChanged(String? name) async {
    _state = _states.where((e) => e.name == name).firstOrNull;
    _district = null;
    _city = null;
    _cities = [];
    _cityNames = [];
    await _loadDistricts();
    if (mounted) setState(() {});
  }

  Future<void> _onDistrictChanged(String? name) async {
    _district = _districts.where((e) => e.name == name).firstOrNull;
    _city = null;
    await _loadCities();
    if (mounted) setState(() {});
  }

  void _onCityChanged(String? name) {
    setState(() => _city = _cities.where((e) => e.name == name).firstOrNull);
  }

  Future<void> _pickLogo() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _newLogo = bytes;
      _removeLogo = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            }
            return Column(
              children: [
                LeadFormUI.header(
                  context,
                  title: _isEdit
                      ? 'Edit Our Company'
                      : 'Create Our Company',
                  subtitle: 'Company details and its primary contact',
                  icon: Iconsax.building_4,
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _vScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _vScroll,
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: LeadFormUI.sectionCard(
                          context,
                          title: 'Company Details',
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                _fields(constraints, 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: LeadFormUI.bottomBar(
          context,
          onSubmit: _submit,
          isEdit: _isEdit,
        ),
      ),
    );
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '* $label is required' : null;

  Widget _logoPicker(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final existing = _removeLogo ? null : _company?.logoUrl;
    ImageProvider? image;
    if (_newLogo != null) {
      image = MemoryImage(_newLogo!);
    } else if (existing != null && existing.isNotEmpty) {
      image = NetworkImage(existing);
    }
    return Row(
      children: [
        InkWell(
          onTap: _pickLogo,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            child: image == null
                ? Icon(Iconsax.gallery_add, color: scheme.primary)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company Logo (optional)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Iconsax.image, size: 16),
                    label: Text(image == null ? 'Upload' : 'Change'),
                  ),
                  if (image != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _newLogo = null;
                        _removeLogo = true;
                      }),
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fields(BoxConstraints constraints, int gridCounts) {
    const double spacing = 16.0;
    const double minWidth = 220.0;
    final canGrid =
        constraints.maxWidth >=
        (minWidth * gridCounts + spacing * (gridCounts - 1));
    final itemWidth = canGrid
        ? (constraints.maxWidth - spacing * (gridCounts - 1)) / gridCounts
        : constraints.maxWidth;

    Widget box(Widget child) => SizedBox(width: itemWidth, child: child);

    return Wrap(
      spacing: spacing,
      runSpacing: 8,
      children: [
        SizedBox(width: constraints.maxWidth, child: _logoPicker(context)),
        box(
          FormFields(
            label: 'Company Name',
            controller: _companyName,
            hintText: 'Enter company name',
            isRequired: true,
            valid: (v) => _required(v, 'Company name'),
          ),
        ),
        box(
          FormFields(
            label: 'GST/VAT Number',
            controller: _gst,
            hintText: 'Enter GST / VAT number',
          ),
        ),
        box(
          FormFields(
            label: 'Contact Name',
            controller: _contactName,
            hintText: 'Enter contact person name',
            isRequired: true,
            valid: (v) => _required(v, 'Contact name'),
          ),
        ),
        box(
          FormFields(
            label: 'Mobile Number',
            controller: _mobile,
            hintText: 'Enter 10 digit mobile number',
            keyboardType: TextInputType.phone,
            isRequired: true,
            valid: (input) {
              if (input == null || input.trim().isEmpty) {
                return '* Mobile number is required';
              }
              if (!RegExp(r'^\d+$').hasMatch(input.trim())) {
                return 'Mobile must contain only digits';
              }
              if (input.trim().length != 10) {
                return 'Mobile must be exactly 10 digits';
              }
              return null;
            },
          ),
        ),
        box(
          FormFields(
            label: 'Email',
            controller: _email,
            hintText: 'Enter email address',
            keyboardType: TextInputType.emailAddress,
            valid: (input) {
              final v = (input ?? '').trim();
              if (v.isEmpty) return null;
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
        ),
        // ── Location: Country → State → District → City ─────────────
        box(
          FormDropdownSearch(
            key: ValueKey('country_${_countryNames.length}'),
            label: 'Country',
            initialItem: _country?.name,
            items: _countryNames,
            allowClear: false,
            onChanged: (v) => _onCountryChanged(v as String?),
          ),
        ),
        box(
          FormDropdownSearch(
            key: ValueKey('state_${_country?.name}_${_stateNames.length}'),
            label: 'State',
            initialItem: _state?.name,
            items: _stateNames,
            onChanged: (v) => _onStateChanged(v as String?),
          ),
        ),
        box(
          FormDropdownSearch(
            key: ValueKey('district_${_state?.name}_${_districtNames.length}'),
            label: 'District',
            initialItem: _district?.name,
            items: _districtNames,
            onChanged: (v) => _onDistrictChanged(v as String?),
          ),
        ),
        box(
          FormDropdownSearch(
            key: ValueKey('city_${_district?.name}_${_cityNames.length}'),
            label: 'City',
            initialItem: _city?.name,
            items: _cityNames,
            onChanged: (v) => _onCityChanged(v as String?),
          ),
        ),
        box(
          FormFields(
            label: 'Postal Code',
            controller: _postal,
            hintText: 'Enter postal code',
            keyboardType: TextInputType.number,
            valid: (input) {
              if (input == null || input.trim().isEmpty) return null;
              if (!RegExp(r'^\d{6}$').hasMatch(input.trim())) {
                return 'Must be 6 digits';
              }
              return null;
            },
          ),
        ),
        SizedBox(
          width: constraints.maxWidth,
          child: FormFields(
            label: 'Company Address',
            controller: _address,
            hintText: 'Enter company address',
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      futureLoading(context);

      String? logoUrl = _removeLogo ? null : _company?.logoUrl;
      if (_newLogo != null) {
        logoUrl = await StorageService.uploadImageBytes(
          bytes: _newLogo!,
          folder: StorageFolder.clientCompanyLogos,
        );
      }
      // Clean up the replaced / removed logo file.
      final old = _company?.logoUrl;
      if (old != null && old.isNotEmpty && old != logoUrl) {
        try {
          await StorageService.deleteImage(old);
        } catch (_) {}
      }

      String? opt(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();

      late final MasterCompanyModel saved;
      if (_isEdit && _company != null) {
        saved = _company!.copyWith(
          companyName: _companyName.text.trim(),
          logoUrl: logoUrl,
          clearLogo: logoUrl == null,
          gstVatNumber: opt(_gst) ?? '',
          contactName: _contactName.text.trim(),
          mobileNumber: _mobile.text.trim(),
          email: opt(_email) ?? '',
          companyAddress: opt(_address) ?? '',
          postalCode: _postal.text.trim(),
          country: _country,
          state: _state,
          district: _district,
          city: _city,
          clearLocation: true,
          updatedAt: DateTime.now(),
        );
        await MasterCompanyService.edit(uid: widget.uid!, company: saved);
      } else {
        final model = MasterCompanyModel(
          companyName: _companyName.text.trim(),
          logoUrl: logoUrl,
          gstVatNumber: opt(_gst),
          contactName: _contactName.text.trim(),
          mobileNumber: _mobile.text.trim(),
          email: opt(_email),
          companyAddress: opt(_address),
          postalCode: opt(_postal),
          country: _country,
          state: _state,
          district: _district,
          city: _city,
          createdBy: await Spdb.getUser(),
        );
        final id = await MasterCompanyService.create(company: model);
        saved = model.copyWith(uid: id);
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, {"status": true, "company": saved});
      FlushBar.show(
        context,
        _isEdit ? 'Company updated' : 'Company created',
        isSuccess: true,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}