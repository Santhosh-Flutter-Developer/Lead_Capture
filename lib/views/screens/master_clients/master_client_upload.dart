import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/models/src/client_model.dart';
import 'package:leadcapture/models/src/region_model.dart';
import 'package:leadcapture/services/database/src/spdb.dart';
import 'package:leadcapture/services/firebase/src/client_service.dart';
import 'package:leadcapture/services/others/src/region_data_service.dart';
import 'package:leadcapture/utils/src/download.dart';
import 'package:leadcapture/views/components/src/xlsx_csv_reader.dart';
import 'package:leadcapture/views/ui/src/flush_bar.dart';
import 'package:leadcapture/views/ui/src/loading.dart';

/// Bulk import of Master Clients (companies) from an .xlsx / .csv file.
///
/// Columns (same order as the downloadable template):
///   0 Company Name *   1 Contact Name *   2 Contact Mobile * (10 digits)
///   3 Office Phone     4 GST/VAT          5 Country   6 State
///   7 District         8 City             9 Postal Code (6 digits)
///   10 Company Address
class MasterClientUpload extends StatefulWidget {
  const MasterClientUpload({super.key});

  @override
  State<MasterClientUpload> createState() => _MasterClientUploadState();
}

class _MasterClientUploadState extends State<MasterClientUpload> {
  final ScrollController _vScrollController = ScrollController();
  String? _fileName;
  int _fileSize = 0;
  List<List<String>> _rows = [];
  bool _loading = false;

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParse() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final ext = file.extension?.toLowerCase();
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Could not read file bytes.');

      List<List<String>> rows = [];
      if (ext == 'csv') {
        rows = CsvReader().parse(utf8.decode(bytes));
      } else if (ext == 'xlsx') {
        rows = await XlsxReader().readFromBytes(bytes);
      }

      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _fileSize = file.size;
        _rows = rows;
      });
    } catch (e) {
      if (mounted) {
        FlushBar.show(
          context,
          'Error parsing file: ${e.toString()}',
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetFile() => setState(() {
    _fileName = null;
    _fileSize = 0;
    _rows = [];
  });

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  // ── parsing helpers ─────────────────────────────────────────────────────

  /// Trimmed cell; "" when the row is shorter than [i]. Excel stores numbers
  /// as "9585038001.0" sometimes, so a trailing ".0" is removed.
  String _cell(List<String> row, int i) {
    if (i >= row.length) return '';
    final v = row[i].trim();
    return RegExp(r'^\d+\.0$').hasMatch(v) ? v.substring(0, v.length - 2) : v;
  }

  bool _isBlank(List<String> row) => row.every((c) => c.trim().isEmpty);

  /// Data rows (header excluded, completely empty rows ignored).
  List<int> get _dataRowIndexes => [
    for (var i = 1; i < _rows.length; i++)
      if (!_isBlank(_rows[i])) i,
  ];

  /// All problems found in the file (empty list = OK to import).
  List<String> _validate() {
    if (_rows.isEmpty) return ['The file is empty.'];
    final header = _rows.first;
    if (header.length < 3 || !header[0].toLowerCase().contains('company')) {
      return [
        'This does not look like the Master Client template. '
            'Download it from the ⋯ menu and fill it in.',
      ];
    }
    final indexes = _dataRowIndexes;
    if (indexes.isEmpty) return ['The file has no data rows.'];

    final errors = <String>[];
    for (final i in indexes) {
      final row = _rows[i];
      final n = i + 1; // Excel row number
      if (_cell(row, 0).isEmpty) errors.add('Row $n: Company Name is required');
      if (_cell(row, 1).isEmpty) errors.add('Row $n: Contact Name is required');
      final mobile = _cell(row, 2);
      if (mobile.isEmpty) {
        errors.add('Row $n: Contact Mobile is required');
      } else if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
        errors.add('Row $n: Contact Mobile must be exactly 10 digits');
      }
      final postal = _cell(row, 9);
      if (postal.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(postal)) {
        errors.add('Row $n: Postal Code must be 6 digits');
      }
    }
    return errors;
  }

  // ── import ──────────────────────────────────────────────────────────────

  Future<void> _importClients() async {
    if (_rows.isEmpty) return;

    final errors = _validate();
    if (errors.isNotEmpty) {
      FlushBar.show(
        context,
        errors.take(4).join('\n') +
            (errors.length > 4 ? '\n...and ${errors.length - 4} more' : ''),
        isSuccess: false,
      );
      return;
    }

    futureLoading(context);

    int created = 0;
    int duplicates = 0;
    int skipped = 0;
    final reasons = <String>[];
    final indexes = _dataRowIndexes;

    try {
      final user = await Spdb.getUser();
      final countries = await RegionDataService.getCountries();
      final defaultCountry = await RegionDataService.getDefaultCountry();

      // Dedupe keys of the companies that already exist (loaded ONCE) and
      // of the ones created by this import (so repeats inside the file are
      // caught too). Same rule as the "Add Master Client" form.
      final existing = await ClientService.getAllClients();
      final keys = <String>{
        for (final c in existing)
          if (c.isCompany) ...ClientService.duplicateKeysForClient(c),
      };

      final stateCache = <String, List<StateModel>>{};
      final districtCache = <String, List<DistrictModel>>{};
      final cityCache = <String, List<CityModel>>{};

      for (final i in indexes) {
        final row = _rows[i];
        final n = i + 1;
        try {
          final countryText = _cell(row, 5);
          final stateText = _cell(row, 6);
          final districtText = _cell(row, 7);
          final cityText = _cell(row, 8);

          RegionModel? country;
          StateModel? state;
          DistrictModel? district;
          CityModel? city;

          // Country defaults to India when a state/district/city is given.
          final countryName = countryText.isNotEmpty
              ? countryText
              : (stateText.isNotEmpty ||
                        districtText.isNotEmpty ||
                        cityText.isNotEmpty)
                  ? defaultCountry?.name
                  : null;

          if (countryName != null) {
            country = countries
                .where((c) => c.name.toLowerCase() == countryName.toLowerCase())
                .firstOrNull;
            if (country == null) {
              skipped++;
              reasons.add('Row $n: Country "$countryName" not found');
              continue;
            }
          }

          if (stateText.isNotEmpty) {
            final list = stateCache[country!.name] ??=
                await RegionDataService.getStates(country: country.name);
            state = list
                .where((s) => s.name.toLowerCase() == stateText.toLowerCase())
                .firstOrNull;
            if (state == null) {
              skipped++;
              reasons.add('Row $n: State "$stateText" not found');
              continue;
            }
          }

          if (districtText.isNotEmpty) {
            if (state == null) {
              skipped++;
              reasons.add('Row $n: District needs a State');
              continue;
            }
            final list = districtCache['${country!.name}|${state.name}'] ??=
                await RegionDataService.getDistricts(
                  country: country.name,
                  state: state.name,
                );
            district = list
                .where(
                  (d) => d.name.toLowerCase() == districtText.toLowerCase(),
                )
                .firstOrNull;
            if (district == null) {
              skipped++;
              reasons.add('Row $n: District "$districtText" not found');
              continue;
            }
          }

          if (cityText.isNotEmpty) {
            if (state == null) {
              skipped++;
              reasons.add('Row $n: City needs a State');
              continue;
            }
            final cacheKey =
                '${country!.name}|${state.name}|${district?.name ?? ''}';
            final list = cityCache[cacheKey] ??=
                await RegionDataService.getCities(
                  country: country.name,
                  state: state.name,
                  district: district?.name,
                );
            city = list
                .where((c) => c.name.toLowerCase() == cityText.toLowerCase())
                .firstOrNull;
            if (city == null) {
              skipped++;
              reasons.add('Row $n: City "$cityText" not found');
              continue;
            }
          }

          final model = ClientModel(
            companyName: _cell(row, 0),
            clientName: _cell(row, 1),
            mobileNumber: _cell(row, 2),
            officePhoneNo: _cell(row, 3),
            gstVatNumber: _cell(row, 4),
            country: country,
            state: state,
            district: district,
            city: city,
            postalCode: _cell(row, 9),
            companyAddress: _cell(row, 10),
            loginAllowed: false,
            receiveEmailNotifications: false,
            createdBy: user,
            isCompany: true,
          );

          final newKeys = ClientService.duplicateKeysForClient(model);
          if (newKeys.any(keys.contains)) {
            duplicates++;
            continue;
          }

          await ClientService.createClient(
            client: model,
            skipDuplicateCheck: true,
          );
          keys.addAll(newKeys);
          created++;
        } catch (e, st) {
          skipped++;
          reasons.add('Row $n: ${e.toString()}');
          debugPrint("Error importing row $n: $e\n$st");
        }
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, true);

      final shown = reasons.take(3).join('\n');
      FlushBar.show(
        context,
        "Import Completed\n"
        "Total: ${indexes.length}\n"
        "Created: $created\n"
        "Already exists: $duplicates\n"
        "Skipped: $skipped"
        "${shown.isEmpty ? '' : '\n$shown'}"
        "${reasons.length > 3 ? '\n...and ${reasons.length - 3} more' : ''}",
        isSuccess: created > 0,
      );
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(
        context,
        "Error importing master clients: ${e.toString()}",
        isSuccess: false,
      );
    }
  }

  void _showTemplateMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Menu',
      barrierColor: Colors.black12,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              right: 16,
              top: kIsWeb ? 60 : 100,
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation.drive(Tween(begin: 0.9, end: 1.0)),
                  child: _ClientCustomMenuCard(parentContext: context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0052D4),
                  Color(0xFF4364F7),
                  Color(0xFF6FB1FC),
                ],
              ),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Iconsax.document_upload,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Import Master Clients',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Iconsax.more, color: Colors.white),
              onPressed: () => _showTemplateMenu(context),
            ),
          ],
        ),
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
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Upload Master Client Spreadsheet',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Required columns: Company Name, Contact Name and Contact Mobile (10 digits). '
                        'Country, State, District, City, Postal Code, GST/VAT, Office Phone and Address are optional '
                        '(location names must match the app\'s list). '
                        'A company that already exists (same name or GST/VAT) is skipped.',
                      ),
                      const SizedBox(height: 32),
            
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _fileName == null
                            ? _buildUploadZone()
                            : _buildFileInfoCard(),
                      ),
            
                      if (_rows.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildPreviewHeader(),
                        const SizedBox(height: 16),
                        _buildPreviewTable(),
                        const SizedBox(height: 32),
                        _buildActionButtons(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: _loading ? null : _pickAndParse,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loading)
              const CircularProgressIndicator()
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0052D4),
                      Color(0xFF4364F7),
                      Color(0xFF6FB1FC),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              "Click to select Master Client Excel or CSV",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Supported: .xlsx, .xls, .csv",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(_formatFileSize(_fileSize)),
              ],
            ),
          ),
          IconButton(onPressed: _resetFile, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Data Preview",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                "Showing first 10 rows of ${_dataRowIndexes.length} master clients found",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _resetFile,
          icon: Icon(
            Icons.delete_outline,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          label: Text(
            "Clear",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTable() {
    final headers = _rows.first;
    final body = _rows.skip(1).take(10).toList(); // Preview only first 10
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          ),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
          rows: body
              .map(
                (r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList()),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Align(
      alignment: Alignment.centerRight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4364F7).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _importClients,
          icon: const Icon(Icons.check),
          label: const Text("Complete Import"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientCustomMenuCard extends StatelessWidget {
  final BuildContext parentContext;
  const _ClientCustomMenuCard({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuItem(
              context,
              icon: Icons.file_download_outlined,
              iconColor: Theme.of(context).colorScheme.primary,
              label: "Master Client Template",
              onTap: () async {
                if (Navigator.canPop(context)) Navigator.pop(context);
                await Download.downloadFromAsset(
                  parentContext,
                  "assets/templates/master_client_upload_template.xlsx",
                  "Master Client Template.xlsx",
                );
              },
            ),
            _menuItem(
              context,
              icon: Icons.contact_page_outlined,
              iconColor: Theme.of(context).colorScheme.secondary,
              label: "Sample Master Client Data",
              onTap: () async {
                if (Navigator.canPop(context)) Navigator.pop(context);
                await Download.downloadFromAsset(
                  parentContext,
                  "assets/templates/master_client_upload_template_with_data.xlsx",
                  "Master Client Sample Data.xlsx",
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}