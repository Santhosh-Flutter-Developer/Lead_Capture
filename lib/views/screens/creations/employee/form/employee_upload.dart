import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';

/// One row of the uploaded sheet that could not be imported, together with
/// the human-readable reason (shown in the summary table + downloadable report).
class _SkippedRow {
  final int rowNum; // row number as seen in the spreadsheet (header = row 1)
  final String employeeId;
  final String name;
  final String email;
  final String reason;

  const _SkippedRow({
    required this.rowNum,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.reason,
  });
}

class EmployeeUploadPage extends StatefulWidget {
  const EmployeeUploadPage({super.key});

  @override
  State<EmployeeUploadPage> createState() => _EmployeeUploadPageState();
}

class _EmployeeUploadPageState extends State<EmployeeUploadPage> {
  String? _fileName;
  int _fileSize = 0;
  List<List<String>> _rows = [];
  bool _loading = false;
  final ScrollController _scrollController = ScrollController();

  // ── Import result (shown after "Complete Import" when rows were skipped) ──
  bool _importing = false;
  bool _showResult = false;
  int _resultTotal = 0;
  int _resultAdded = 0;
  List<_SkippedRow> _skippedRows = [];

  static const int _columnCount = 19;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  Future<void> _pickAndParse() async {
    setState(() => _loading = true);

    try {
      // Picking file
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

      // Previously this read the file via dart:io's File(path).readAsBytes().
      // dart:io has no real filesystem on Flutter Web, so File(...) is a
      // stub there — touching it throws "Unsupported operation:
      // _Namespace" the instant a file is picked, silently resetting the
      // screen back to the empty upload zone. Request the bytes directly
      // from file_picker instead (withData: true above), matching the
      // approach already used for lead uploads.
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
      debugPrint('Error parsing file: $e');
      FlushBar.show(context, 'Error: ${e.toString()}', isSuccess: false);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _resetFile() {
    setState(() {
      _fileName = null;
      _fileSize = 0;
      _rows = [];
      _showResult = false;
      _resultTotal = 0;
      _resultAdded = 0;
      _skippedRows = [];
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Iconsax.arrow_left_2, color: AppColors.white),
            tooltip: 'Back',
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Iconsax.document_upload,
              color: AppColors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Import Employees',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bulk-add employees from a CSV or Excel file',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Iconsax.more, color: AppColors.white),
            tooltip: 'Options',
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) async {
              if (value == 'template') {
                await Download.downloadFromAsset(
                  context,
                  "assets/templates/employee_upload_template.xlsx",
                  "Employee_Template.xlsx",
                );
              } else if (value == 'sample') {
                await Download.downloadFromAsset(
                  context,
                  "assets/templates/employee_upload_template_with_data.xlsx",
                  "Employee_Sample_Data.xlsx",
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'template',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Employee Template',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sample',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.contact_page_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sample Employee Data',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Color? accentColor,
  }) {
    final Color badgeColor =
        accentColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: badgeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.grey200, thickness: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_showResult) _buildImportSummary(),
                            if (!_showResult)
                            _buildSectionCard(
                              icon: Iconsax.document_upload,
                              accentColor: Theme.of(context).colorScheme.primary,
                              title: 'Upload Employee List',
                              subtitle:
                                  'Select a CSV or Excel file with your employee records',
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _fileName == null
                                    ? _buildUploadZone()
                                    : _buildFileInfoCard(),
                              ),
                            ),
                  
                            // Preview Section (Only visible if data exists)
                            if (!_showResult && _rows.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _buildSectionCard(
                                icon: Iconsax.task_square,
                                accentColor: AppColors.success,
                                title: 'Data Preview (${_rows.length - 1} entries)',
                                subtitle:
                                    'Review the records before completing the import',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_rows.length > 50)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Chip(
                                            label: Text(
                                              'Showing first 50',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurfaceVariant,
                                                  ),
                                            ),
                                            backgroundColor: Theme.of(
                                              context,
                                            ).scaffoldBackgroundColor,
                                            side: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    _buildPreviewTable(),
                                    const SizedBox(height: 20),
                                    _buildActionButtons(),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: _loading ? null : _pickAndParse,
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Soft background tint
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                ),
              ),
            ),

            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(
                            Icons.cloud_upload_outlined,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                  ),
                  const SizedBox(height: 24),
                  RichText(
                    text: TextSpan(
                      text: 'Click to upload',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: ' or drag and drop',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.normal,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supported formats: .CSV, .XLSX',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(
                0xFF217346,
              ).withValues(alpha: 0.1), // Green tint
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.table_view,
              color: Color(0xFF217346),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName ?? 'Unknown file',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatFileSize(_fileSize),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _resetFile,
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Remove file',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    if (_rows.isEmpty) return const SizedBox.shrink();

    final headers = _rows.first;
    final body = _rows.length > 1 ? _rows.sublist(1) : <List<String>>[];
    final maxCols = headers.length > 10 ? 10 : headers.length; // Limit columns

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).scaffoldBackgroundColor,
            ),
            columnSpacing: 24,
            horizontalMargin: 24,
            columns: List.generate(
              maxCols,
              (i) => DataColumn(
                label: Text(
                  headers[i].toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            rows: List.generate(body.length > 50 ? 50 : body.length, (index) {
              final row = body[index];
              return DataRow(
                cells: List.generate(maxCols, (cIdx) {
                  final val = cIdx < row.length ? row[cIdx] : '';
                  return DataCell(
                    Text(
                      val,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── import helpers ─────────────────────────

  /// Accepts dd-MM-yyyy (template format), dd/MM/yyyy, dd.MM.yyyy,
  /// yyyy-MM-dd, yyyy/MM/dd and Excel serial numbers. Returns null when the
  /// value cannot be understood.
  DateTime? _parseDate(String value) {
    var v = value.trim();
    if (v.isEmpty) return null;

    // Drop a trailing time part, e.g. "01-01-2024 00:00:00".
    v = v.split(' ').first;

    final serial = double.tryParse(v);
    if (serial != null && serial > 1000) {
      return DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    }

    for (final pattern in const [
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'dd.MM.yyyy',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
    ]) {
      try {
        return DateFormat(pattern).parseStrict(v);
      } catch (_) {}
    }
    return null;
  }

  /// Escapes a value for CSV.
  String _csv(Object? v) {
    final t = (v ?? '').toString().replaceAll('"', '""');
    return '"$t"';
  }

  Future<void> _downloadSkippedReport() async {
    try {
      final b = StringBuffer('\uFEFF'); // BOM so Excel reads UTF-8 correctly
      b.writeln(
        ['Row #', 'Employee ID', 'Name', 'Email', 'Reason for Skipping']
            .map(_csv)
            .join(','),
      );
      for (final r in _skippedRows) {
        b.writeln(
          [r.rowNum, r.employeeId, r.name, r.email, r.reason]
              .map(_csv)
              .join(','),
        );
      }
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final path = await saveFileToDownloads(
        Uint8List.fromList(utf8.encode(b.toString())),
        fileName: 'Employee_Import_Skipped_$stamp.csv',
      );
      if (!mounted) return;
      FlushBar.show(context, 'Skipped report downloaded');
      if (!kIsWeb) openfile(path, context);
    } catch (e, st) {
      debugPrint('Skipped report download failed: $e, $st');
      if (mounted) {
        FlushBar.show(
          context,
          'Could not download report: $e',
          isSuccess: false,
        );
      }
    }
  }

  // ───────────────────────── import ─────────────────────────

  Future<void> _uploadEmployeeData() async {
    if (_rows.isEmpty || _importing) return;

    if (_rows.first.length < _columnCount) {
      FlushBar.show(
        context,
        "Error: The uploaded file does not have the required columns.",
        isSuccess: false,
      );
      return;
    }

    _importing = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    var loadingShown = true;
    void closeLoading() {
      if (loadingShown) {
        loadingShown = false;
        if (navigator.mounted && navigator.canPop()) navigator.pop();
      }
    }

    futureLoading(context);

    try {
      int uploadedCount = 0;
      final skipped = <_SkippedRow>[];

      // assuming row 0 is header
      final totalRows = _rows.length - 1;

      void skip({
        required int rowNum,
        required String employeeId,
        required String name,
        required String email,
        required String reason,
      }) {
        skipped.add(
          _SkippedRow(
            rowNum: rowNum,
            employeeId: employeeId.isEmpty ? '-' : employeeId,
            name: name.isEmpty ? '-' : name,
            email: email.isEmpty ? '-' : email,
            reason: reason,
          ),
        );
      }

      // Load every existing employee once so duplicates can be checked
      // in-memory against the whole file, instead of hitting the server
      // three times per row the way the single-employee form does.
      final existingEmployees =
          await EmployeeService.getAllEmployeesForDuplicateCheck();
      final existingKeys = <String>{
        for (final emp in existingEmployees)
          ...EmployeeService.duplicateKeysForEmployee(emp),
      };

      // Email and mobile number must be unique for one user across the
      // WHOLE app, not just this company - so also pull in every
      // employee and admin from every other company and merge their
      // email/mobile keys. employeeId numbering is per-company, so it's
      // deliberately left out of these global keys.
      final globalEmployees =
          await EmployeeService.getAllEmployeesGlobalForDuplicateCheck();
      final globalAdmins =
          await EmployeeService.getAllAdminsGlobalForDuplicateCheck();
      existingKeys.addAll([
        for (final emp in globalEmployees)
          ...EmployeeService.duplicateContactKeysForEmployee(emp),
        for (final admin in globalAdmins)
          ...EmployeeService.duplicateContactKeysForAdmin(admin),
      ]);

      // key -> spreadsheet row that already imported it (duplicates INSIDE
      // the uploaded file).
      final fileKeys = <String, int>{};

      String? keyOf({String? employeeId, String? email, String? mobile}) {
        final k = EmployeeService.duplicateKeysFor(
          employeeId: employeeId,
          email: email,
          mobileNumber: mobile,
        );
        return k.isEmpty ? null : k.first;
      }

      for (var i = 1; i < _rows.length; i++) {
        // Spreadsheet row number (header is row 1) so the user can find it.
        final rowNum = i + 1;
        final raw = _rows[i];

        // Pad short rows so a missing trailing cell never throws RangeError.
        final row = List<String>.generate(
          _columnCount,
          (c) => c < raw.length ? raw[c].toString().trim() : '',
        );

        final empId = row[0];
        final name = row[1];
        final email = row[2];
        final password = row[3];
        final mobile = row[7];

        try {
          // Completely blank line in the sheet - nothing to import or report.
          if (row.every((c) => c.isEmpty)) {
            continue;
          }

          // 1. Required fields (list exactly which ones are missing)
          final departmentNames = row[5]
              .split(',')
              .map((d) => d.trim())
              .where((d) => d.isNotEmpty)
              .toList();

          final missing = <String>[
            if (empId.isEmpty) 'Employee ID',
            if (name.isEmpty) 'Full Name',
            if (email.isEmpty) 'Email',
            if (password.isEmpty) 'Password',
            if (row[4].isEmpty) 'Designation',
            if (departmentNames.isEmpty) 'Department',
            if (row[9].isEmpty) 'Date of Joining',
            if (row[11].isEmpty) 'Role',
          ];
          if (missing.isNotEmpty) {
            skip(
              rowNum: rowNum,
              employeeId: empId,
              name: name,
              email: email,
              reason: 'Missing required field(s): ${missing.join(', ')}',
            );
            continue;
          }

          // 2. Email format
          final emailError = Validation.validEmail(input: email, isReq: true);
          if (emailError != null) {
            skip(
              rowNum: rowNum,
              employeeId: empId,
              name: name,
              email: email,
              reason: 'Invalid email format ($email)',
            );
            continue;
          }

          // 3. Password rules
          final passwordError = Validation.passwordValidation(
            input: password,
            isReq: true,
          );
          if (passwordError != null) {
            skip(
              rowNum: rowNum,
              employeeId: empId,
              name: name,
              email: email,
              reason: 'Invalid password: $passwordError',
            );
            continue;
          }

          // 4. Dates
          final doj = _parseDate(row[9]);
          if (doj == null) {
            skip(
              rowNum: rowNum,
              employeeId: empId,
              name: name,
              email: email,
              reason:
                  "Invalid Date of Joining '${row[9]}' (expected dd-MM-yyyy)",
            );
            continue;
          }

          DateTime? dob;
          if (row[10].isNotEmpty) {
            dob = _parseDate(row[10]);
            if (dob == null) {
              skip(
                rowNum: rowNum,
                employeeId: empId,
                name: name,
                email: email,
                reason:
                    "Invalid Date of Birth '${row[10]}' (expected dd-MM-yyyy)",
              );
              continue;
            }
          }

          // 5. Already exists in the organization (database)
          final idKey = keyOf(employeeId: empId);
          final emailKey = keyOf(email: email);
          final mobileKey = keyOf(mobile: mobile);

          final existsIn = <String>[
            if (idKey != null && existingKeys.contains(idKey))
              "Employee ID '$empId'",
            if (emailKey != null && existingKeys.contains(emailKey))
              "Email '$email'",
            if (mobileKey != null && existingKeys.contains(mobileKey))
              "Mobile Number '$mobile'",
          ];
          if (existsIn.isNotEmpty) {
            skip(
              rowNum: rowNum,
              employeeId: empId,
              name: name,
              email: email,
              reason: existsIn.length == 1
                  ? '${existsIn.first} already exists in your organization'
                  : '${existsIn.join(', ')} already exist in your organization',
            );
            continue;
          }

          // 6. Duplicate inside the uploaded file itself
          final dupInFile = <String>[];
          if (idKey != null && fileKeys.containsKey(idKey)) {
            dupInFile.add(
              "Employee ID '$empId' (already used in row #${fileKeys[idKey]})",
            );
          }
          if (emailKey != null && fileKeys.containsKey(emailKey)) {
            dupInFile.add(
              "Email '$email' (already used in row #${fileKeys[emailKey]})",
            );
          }
          if (mobileKey != null && fileKeys.containsKey(mobileKey)) {
            dupInFile.add(
              "Mobile Number '$mobile' (already used in row #${fileKeys[mobileKey]})",
            );
          }
          if (dupInFile.isNotEmpty) {
            skip(
              rowNum: rowNum,
              employeeId: empId,
              name: name,
              email: email,
              reason:
                  'Duplicate in uploaded spreadsheet: ${dupInFile.join(', ')}',
            );
            continue;
          }

          // ── Resolve lookups (auto-creates missing masters) ──
          final designation =
              await DesignationService.getDesignationByNameOrCreateDesignation(
                name: row[4],
              );

          final department = await Future.wait(
            departmentNames.map(
              (d) => DepartmentService.getDepartmentByNameOrCreateDepartment(
                name: d,
              ),
            ),
          );

          String? subDepartment;
          if (row[6].isNotEmpty) {
            subDepartment =
                await SubDepartmentService.getSubDepartmentByNameOrCreateSubDepartment(
                  name: row[6],
                  department: department.first,
                );
          }

          final genderValue = row[8].toLowerCase();
          var gender = 'Male';
          if (genderValue == 'female') gender = 'Female';

          final role = await RoleService.getRoleByNameOrCreateRole(
            name: row[11],
          );

          final reportingToVal = row[12]
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          final reportingTo = <String>[];
          for (final reportId in reportingToVal) {
            final uid = await EmployeeService.getEmployeeById(
              employeeId: reportId,
            );
            if (uid != null) {
              reportingTo.add(uid);
            }
          }

          final maritalStatusValue = row[17].toLowerCase();
          var maritalStatus = 'Single';
          if (maritalStatusValue == 'married') {
            maritalStatus = 'Married';
          } else if (maritalStatusValue == 'divorced') {
            maritalStatus = 'Divorced';
          } else if (maritalStatusValue == 'widowed') {
            maritalStatus = 'Widowed';
          }

          final employeeTypeValue = row[18].toLowerCase();
          var employeeType = 'Full Time';
          if (employeeTypeValue == 'part time') {
            employeeType = 'Part Time';
          } else if (employeeTypeValue == 'on contact') {
            employeeType = 'On Contact';
          } else if (employeeTypeValue == 'internship') {
            employeeType = 'Internship';
          } else if (employeeTypeValue == 'trainee') {
            employeeType = 'Trainee';
          }

          final employeeModel = EmployeeModel(
            employeeId: empId,
            name: name,
            email: email,
            password: password,
            designation: designation,
            department: department,
            mobileNumber: mobile,
            gender: gender,
            subDepartment: subDepartment,
            dateOfJoining: doj,
            dateOfBirth: dob,
            role: role,
            reportingTo: reportingTo,
            address: row[13],
            about: row[14],
            loginAllowed: row[15].toLowerCase() == 'yes',
            receiveEmailNotifications: row[16].toLowerCase() == 'yes',
            maritalStatus: maritalStatus,
            skills: '',
            employeeType: employeeType,
            createdBy: await Spdb.getUser(),
          );

          await EmployeeService.createEmployee(employee: employeeModel);
          uploadedCount++;

          // Remember this row's keys so a later duplicate inside the same
          // file is reported with the row number that came first.
          for (final k in [idKey, emailKey, mobileKey]) {
            if (k != null) fileKeys[k] = rowNum;
          }
        } catch (e, st) {
          // Show the real server / validation message as the reason, so
          // every skipped row is explained.
          var reason = e.toString().replaceFirst('Exception: ', '').trim();
          if (reason.isEmpty) reason = 'Unexpected error while saving';
          skip(
            rowNum: rowNum,
            employeeId: empId,
            name: name,
            email: email,
            reason: reason,
          );
          debugPrint('Error uploading row $rowNum: $e, $st');
        }
      }

      closeLoading();
      if (!mounted) return;

      if (skipped.isEmpty) {
        // Everything imported - same behaviour as before.
        Navigator.pop(context, true);
        FlushBar.show(
          context,
          "Upload Completed\nTotal: $totalRows  •  Added: $uploadedCount  •  Skipped: 0",
          isSuccess: uploadedCount > 0,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      // Some / all rows skipped: stay on the page and show WHY.
      setState(() {
        _resultTotal = totalRows;
        _resultAdded = uploadedCount;
        _skippedRows = skipped;
        _showResult = true;
      });
      FlushBar.show(
        context,
        uploadedCount > 0
            ? 'Imported $uploadedCount employee(s). ${skipped.length} skipped.'
            : 'No employees were imported. ${skipped.length} skipped.',
        isSuccess: uploadedCount > 0,
      );
    } catch (e) {
      closeLoading();
      if (mounted) {
        FlushBar.show(
          context,
          "Error uploading data: ${e.toString()}",
          isSuccess: false,
        );
      }
    } finally {
      _importing = false;
    }
  }

  // ───────────────────────── import summary UI ─────────────────────────

  Widget _countChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _reasonPill(String reason) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Iconsax.info_circle, size: 14, color: AppColors.danger),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                reason,
                softWrap: true,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkippedTable() {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final headStyle = textStyle?.copyWith(
      fontWeight: FontWeight.bold,
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    // Below this width the columns would get too cramped, so the table keeps
    // this width and scrolls sideways instead.
    const double minTableWidth = 760;

    Widget cell(int flex, Widget child, {double? width}) {
      final padded = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: child),
      );
      return width != null
          ? SizedBox(width: width, child: padded)
          : Expanded(flex: flex, child: padded);
    }

    Widget headerRow() => Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          cell(0, Text('ROW #', style: headStyle), width: 72),
          cell(2, Text('EMP ID', style: headStyle)),
          cell(3, Text('NAME', style: headStyle)),
          cell(4, Text('EMAIL', style: headStyle)),
          cell(6, Text('REASON FOR SKIPPING', style: headStyle)),
        ],
      ),
    );

    Widget dataRow(_SkippedRow r) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          cell(0, Text('${r.rowNum}', style: textStyle), width: 72),
          cell(
            2,
            Text(
              r.employeeId,
              style: textStyle?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          cell(3, Text(r.name, style: textStyle)),
          cell(4, Text(r.email, style: textStyle)),
          cell(6, _reasonPill(r.reason)),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = constraints.maxWidth < minTableWidth
                ? minTableWidth
                : constraints.maxWidth;
            final table = SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerRow(),
                  for (final r in _skippedRows) dataRow(r),
                ],
              ),
            );
            if (constraints.maxWidth >= minTableWidth) return table;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            );
          },
        ),
      ),
    );
  }

  Widget _buildImportSummary() {
    final skippedCount = _skippedRows.length;
    final message = _resultAdded == 0
        ? 'None of the rows could be imported. All $_resultTotal row(s) were '
              'skipped due to the specific issues detailed below.'
        : '$_resultAdded of $_resultTotal row(s) were imported. '
              '$skippedCount row(s) were skipped due to the specific issues '
              'detailed below.';

    return _buildSectionCard(
      icon: Iconsax.document_text,
      accentColor: _resultAdded == 0 ? AppColors.danger : AppColors.warning,
      title: 'Import Summary',
      subtitle: _fileName ?? 'Uploaded file',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _countChip('$_resultAdded Imported', AppColors.success),
              _countChip('$skippedCount Skipped', AppColors.danger),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(
                Iconsax.warning_2,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Skipped Records & Reasons',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _downloadSkippedReport,
                icon: const Icon(Iconsax.document_download, size: 16),
                label: const Text('Download Skipped Report'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSkippedTable(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _resetFile,
                icon: const Icon(Iconsax.refresh, size: 16),
                label: const Text('Upload Another File'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, _resultAdded > 0),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: _brandGradient,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4364F7).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _uploadEmployeeData,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 15,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.tick_circle,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Complete Import',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}