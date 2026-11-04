import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/models/src/lead_model.dart';
import 'package:leadcapture/models/src/lead_source_model.dart';
import 'package:leadcapture/models/src/lead_category_model.dart';
import 'package:leadcapture/models/src/lead_priority_model.dart';
import 'package:leadcapture/models/src/lead_status_model.dart';
import 'package:leadcapture/models/src/client_model.dart';
import 'package:leadcapture/models/src/employee_model.dart';
import 'package:leadcapture/services/firebase/src/follow_up_access.dart';
import 'package:leadcapture/services/database/src/spdb.dart';
import 'package:leadcapture/services/firebase/src/lead_category_service.dart';
import 'package:leadcapture/services/firebase/src/lead_priority_service.dart';
import 'package:leadcapture/services/firebase/src/lead_service.dart';
import 'package:leadcapture/services/firebase/src/lead_source_service.dart';
import 'package:leadcapture/services/firebase/src/lead_status_service.dart';
import 'package:leadcapture/services/firebase/src/client_service.dart';

import 'package:leadcapture/utils/src/download.dart';
import 'package:leadcapture/views/components/src/xlsx_csv_reader.dart';
import 'package:leadcapture/views/ui/src/flush_bar.dart';
import 'package:leadcapture/views/ui/src/loading.dart';

class LeadUpload extends StatefulWidget {
  const LeadUpload({super.key});

  @override
  State<LeadUpload> createState() => _LeadUploadState();
}

class _LeadUploadState extends State<LeadUpload> {
  final ScrollController _vScrollController = ScrollController();
  String? _fileName;
  int _fileSize = 0;
  List<List<String>> _rows = [];
  bool _loading = false;

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
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final ext = file.extension?.toLowerCase();
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Could not read file bytes.');

      List<List<String>> rows = [];

      if (ext == 'csv') {
        final str = utf8.decode(bytes);
        rows = CsvReader().parse(str);
      } else if (ext == 'xlsx') {
        rows = await XlsxReader().readFromBytes(bytes);
      }

      setState(() {
        _fileName = file.name;
        _fileSize = file.size;
        _rows = rows;
      });
    } catch (e) {
      FlushBar.show(
        context,
        'Error parsing file: ${e.toString()}',
        isSuccess: false,
      );
    } finally {
      setState(() => _loading = false);
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

  // ── column layout (same order as the downloadable template) ─────────────
  //  0 Master Client (Company Name) *   1 Contact Name   2 Contact Mobile
  //  3 Lead Name *      4 Lead Email     5 Lead Source *  6 Lead Category *
  //  7 Lead Priority *  8 Status         9 Lead Value     10 Project Name
  //  11 Follow Up (employee NAME)        12 Project Description   13 Note
  //
  // Contact Name / Contact Mobile are only needed when the Master Client does
  // not exist yet; for an existing Master Client they are ignored.
  static const int _cMaster = 0,
      _cContact = 1,
      _cMobile = 2,
      _cLeadName = 3,
      _cEmail = 4,
      _cSource = 5,
      _cCategory = 6,
      _cPriority = 7,
      _cStatus = 8,
      _cValue = 9,
      _cProject = 10,
      _cFollowUp = 11,
      _cProjectDesc = 12,
      _cNote = 13;

  static const String _defaultStatus = 'New';

  /// Trimmed cell; "" when the row is shorter than [i]. Excel sometimes
  /// stores numbers as "9585038001.0", so a trailing ".0" is removed.
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

  String _key(String v) => v.trim().toLowerCase();

  /// All problems found in the file (empty list = OK to import).
  List<String> _validate(
    List<ClientModel> masterClients,
    List<EmployeeModel> employees,
  ) {
    if (_rows.isEmpty) return ['The file is empty.'];
    final header = _rows.first;
    if (header.length < 6 || !header[0].toLowerCase().contains('master')) {
      return [
        'This does not look like the Lead template. '
            'Download it from the ⋯ menu and fill it in.',
      ];
    }
    final indexes = _dataRowIndexes;
    if (indexes.isEmpty) return ['The file has no data rows.'];

    // Master clients that already exist, plus the ones this file will create
    // (so a company repeated in several rows is only asked for once).
    final known = <String>{
      for (final c in masterClients) _key(c.companyName ?? ''),
    };
    final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$');
    final errors = <String>[];

    for (final i in indexes) {
      final row = _rows[i];
      final n = i + 1; // Excel row number

      final master = _cell(row, _cMaster);
      if (master.isEmpty) {
        errors.add('Row $n: Master Client (Company Name) is required');
      } else if (!known.contains(_key(master))) {
        // A new Master Client is created -> same rules as the Master Client form.
        final contact = _cell(row, _cContact);
        final mobile = _cell(row, _cMobile);
        if (contact.isEmpty) {
          errors.add(
            'Row $n: Master Client "$master" is new - Contact Name is required',
          );
        }
        if (mobile.isEmpty) {
          errors.add(
            'Row $n: Master Client "$master" is new - Contact Mobile is required',
          );
        } else if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
          errors.add('Row $n: Contact Mobile must be exactly 10 digits');
        }
        if (contact.isNotEmpty && RegExp(r'^\d{10}$').hasMatch(mobile)) {
          known.add(_key(master));
        }
      }

      if (_cell(row, _cLeadName).isEmpty) {
        errors.add('Row $n: Lead Name is required');
      }
      final email = _cell(row, _cEmail);
      if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
        errors.add('Row $n: Lead Email "$email" is not valid');
      }
      if (_cell(row, _cSource).isEmpty) {
        errors.add('Row $n: Lead Source is required');
      }
      if (_cell(row, _cCategory).isEmpty) {
        errors.add('Row $n: Lead Category is required');
      }
      if (_cell(row, _cPriority).isEmpty) {
        errors.add('Row $n: Lead Priority is required');
      }
      final value = _cell(row, _cValue);
      if (value.isNotEmpty && double.tryParse(value) == null) {
        errors.add('Row $n: Lead Value must be a number');
      }

      // Follow Up: employee NAME only (optional).
      final fu = _cell(row, _cFollowUp);
      if (fu.isNotEmpty) {
        final matches = _employeesByName(employees, fu);
        if (matches.isEmpty) {
          final names = employees.map((e) => e.name.trim()).toSet().take(5);
          errors.add(
            'Row $n: Follow Up employee "$fu" was not found. '
            'Use an employee name exactly as in the Follow Up dropdown'
            '${names.isEmpty ? '' : ' (e.g. ${names.join(', ')})'}, or leave it empty.',
          );
        } else if (matches.length > 1) {
          errors.add(
            'Row $n: More than one employee is named "$fu" - '
            'rename one of them or leave Follow Up empty',
          );
        }
      }
    }
    return errors;
  }

  List<EmployeeModel> _employeesByName(
    List<EmployeeModel> employees,
    String name,
  ) => employees.where((e) => _key(e.name) == _key(name)).toList();

  Future<void> _uploadLeadData() async {
    if (_rows.isEmpty) return;

    // Loaded ONCE for the whole file.
    List<ClientModel> masterClients = [];
    List<EmployeeModel> employees = [];
    try {
      masterClients = await ClientService.getMasterClients();
      employees = await FollowUpAccess.employees();
    } catch (e) {
      if (!mounted) return;
      FlushBar.show(context, 'Could not load data: $e', isSuccess: false);
      return;
    }

    final errors = _validate(masterClients, employees);
    if (errors.isNotEmpty) {
      if (!mounted) return;
      FlushBar.show(
        context,
        errors.take(4).join('\n') +
            (errors.length > 4 ? '\n...and ${errors.length - 4} more' : ''),
        isSuccess: false,
      );
      return;
    }

    if (!mounted) return;
    futureLoading(context);

    int uploaded = 0;
    int newMasterClients = 0;
    int skipped = 0;
    final reasons = <String>[];
    final indexes = _dataRowIndexes;

    try {
      final currentUser = await Spdb.getUser();

      // company name -> Master Client (existing + created by this import).
      final clientsByName = <String, ClientModel>{
        for (final c in masterClients) _key(c.companyName ?? ''): c,
      };
      final sourceCache = <String, LeadSourceModel>{};
      final categoryCache = <String, LeadCategoryModel>{};
      final priorityCache = <String, LeadPriorityModel>{};
      final statusCache = <String, LeadStatusModel>{};

      for (final i in indexes) {
        final row = _rows[i];
        final n = i + 1;
        try {
          // 1. Master Client: reuse it when it exists, otherwise create it.
          final masterName = _cell(row, _cMaster);
          ClientModel? client = clientsByName[_key(masterName)];
          if (client == null) {
            final model = ClientModel(
              companyName: masterName,
              clientName: _cell(row, _cContact),
              mobileNumber: _cell(row, _cMobile),
              loginAllowed: false,
              receiveEmailNotifications: false,
              createdBy: currentUser,
              isCompany: true,
            );
            final id = await ClientService.createClient(
              client: model,
              skipDuplicateCheck: true,
            );
            client = model.copyWith(uid: id);
            clientsByName[_key(masterName)] = client;
            newMasterClients++;
          }

          // 2. Lead Source / Category / Priority / Status.
          final sourceName = _cell(row, _cSource);
          final source = sourceCache[_key(sourceName)] ??=
              await LeadSourceService.getByNameOrCreate(name: sourceName);

          final categoryName = _cell(row, _cCategory);
          final category = categoryCache[_key(categoryName)] ??=
              await LeadCategoryService.getByNameOrCreate(name: categoryName);

          final priorityName = _cell(row, _cPriority);
          final priority = priorityCache[_key(priorityName)] ??=
              await LeadPriorityService.getByNameOrCreate(name: priorityName);

          final statusText = _cell(row, _cStatus);
          final statusName = statusText.isEmpty ? _defaultStatus : statusText;
          final status = statusCache[_key(statusName)] ??=
              await LeadStatusService.getByNameOrCreate(name: statusName);

          // 3. Follow Up (employee name -> uid).
          final fu = _cell(row, _cFollowUp);
          final followUpUid = fu.isEmpty
              ? null
              : _employeesByName(employees, fu).first.uid;

          // 4. Lead - company / contact details come from the Master Client,
          //    exactly like the "Create Leads" form does.
          final lead = LeadModel(
            leadName: _cell(row, _cLeadName),
            leadEmail: _cell(row, _cEmail),
            leadSource: source,
            leadCategory: category.uid ?? '',
            leadPriority: priority.uid ?? '',
            leadValue: double.tryParse(_cell(row, _cValue)) ?? 0,
            leadStatus: status.uid ?? '',
            notes: _cell(row, _cNote),
            attachments: [],
            companyName: client.companyName,
            companyMobile: client.officePhoneNo,
            companyAddress: client.companyAddress,
            companyZipCode: client.postalCode,
            clientName: client.clientName,
            clientMobile: client.mobileNumber,
            clientId: client.uid,
            projectName: _cell(row, _cProject),
            projectDescription: _cell(row, _cProjectDesc),
            followUp: followUpUid,
            createdBy: currentUser,
            workflow: [],
          );

          final leadUid = await LeadService.createLead(lead: lead);
          // Status "Completed" -> a Deal is created automatically, as in the form.
          await LeadService.convertIfCompleted(leadUid: leadUid);
          uploaded++;
        } catch (e, st) {
          skipped++;
          reasons.add('Row $n: ${e.toString()}');
          debugPrint("Error uploading row $n: $e\n$st");
        }
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, true);

      final shown = reasons.take(3).join('\n');
      FlushBar.show(
        context,
        "Upload Completed\n"
        "Total: ${indexes.length}\n"
        "Uploaded: $uploaded\n"
        "New master clients: $newMasterClients\n"
        "Skipped: $skipped"
        "${shown.isEmpty ? '' : '\n$shown'}"
        "${reasons.length > 3 ? '\n...and ${reasons.length - 3} more' : ''}",
        isSuccess: uploaded > 0,
      );
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(
        context,
        "Error uploading leads: ${e.toString()}",
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
                  child: _LeadCustomMenuCard(parentContext: context),
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
                'Import Leads',
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
                        'Upload Lead Spreadsheet',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Required: Master Client (Company Name), Lead Name, Lead Source, Lead Category and Lead Priority. '
                        'If the Master Client already exists it is reused; otherwise it is created from the Contact Name and Contact Mobile (10 digits) columns. '
                        'Follow Up takes the employee name and is optional; Status defaults to New.',
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
              "Click to select Lead Excel or CSV",
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
                "Showing first 10 rows of ${_rows.length - 1} leads found",
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
          onPressed: _uploadLeadData,
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

class _LeadCustomMenuCard extends StatelessWidget {
  final BuildContext parentContext;
  const _LeadCustomMenuCard({required this.parentContext});

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
              label: "Lead Template",
              onTap: () async {
                if (Navigator.canPop(context)) Navigator.pop(context);
                await Download.downloadFromAsset(
                  parentContext,
                  "assets/templates/lead_upload_template.xlsx",
                  "Lead Template.xlsx",
                );
              },
            ),
            _menuItem(
              context,
              icon: Icons.contact_page_outlined,
              iconColor: Theme.of(context).colorScheme.secondary,
              label: "Sample Lead Data",
              onTap: () async {
                if (Navigator.canPop(context)) Navigator.pop(context);
                await Download.downloadFromAsset(
                  parentContext,
                  "assets/templates/lead_upload_template_with_data.xlsx",
                  "Lead Sample Data.xlsx",
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