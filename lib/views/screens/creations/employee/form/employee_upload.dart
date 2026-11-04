import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';

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
                            if (_rows.isNotEmpty) ...[
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

  void _uploadEmployeeData() async {
    try {
      if (_rows.isEmpty) return;

      if (_rows.first.length < 19) {
        FlushBar.show(
          context,
          "Error: The uploaded file does not have the required columns.",
          isSuccess: false,
        );
        return;
      }

      futureLoading(context);

      int uploadedCount = 0;
      int skippedCount = 0;

      // assuming row 0 is header
      final totalRows = _rows.length - 1;

      // Tracks why a row was skipped, e.g. "Duplicate employee" -> 3 rows,
      // so the closing toast can show a reason breakdown like the leads
      // import does, instead of a bare added/skipped count.
      final Map<String, int> skipReasons = {};
      void recordSkip(String reason) {
        skippedCount++;
        skipReasons[reason] = (skipReasons[reason] ?? 0) + 1;
      }

      // Load every existing employee once so duplicates can be checked
      // in-memory against the whole file, instead of hitting Firestore
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
      // deliberately left out of these global keys (see
      // duplicateContactKeysForEmployee/duplicateContactKeysForAdmin).
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

      for (var i = 1; i < _rows.length; i++) {
        final row = _rows[i];

        try {
          final hasRequiredFields =
              row[0].trim().isNotEmpty && // employeeId
              row[1].trim().isNotEmpty && // name
              row[3].trim().isNotEmpty && // password
              row[4].trim().isNotEmpty && // designation
              row[5].trim().isNotEmpty && // department
              row[11].trim().isNotEmpty; // role

          if (!hasRequiredFields) {
            recordSkip('Missing required fields');
            continue;
          }

          final rowKeys = EmployeeService.duplicateKeysFor(
            employeeId: row[0],
            email: row[2],
            mobileNumber: row[7],
          );
          final isDuplicate = rowKeys.any(existingKeys.contains);
          if (isDuplicate) {
            recordSkip('Duplicate employee (already exists)');
            continue;
          }

          final designation =
              await DesignationService.getDesignationByNameOrCreateDesignation(
                name: row[4].trim(),
              );

          final departmentNames = row[5]
              .split(',')
              .map((d) => d.trim())
              .where((d) => d.isNotEmpty)
              .toList();

          final department = await Future.wait(
            departmentNames.map(
              (d) => DepartmentService.getDepartmentByNameOrCreateDepartment(
                name: d,
              ),
            ),
          );

          String? subDepartment;
          if (row[6].trim().isNotEmpty) {
            subDepartment =
                await SubDepartmentService.getSubDepartmentByNameOrCreateSubDepartment(
                  name: row[6].trim(),
                  department: department.first,
                );
          }

          final genderValue = row[8].trim().toLowerCase();
          var gender = 'Male';
          if (genderValue == 'female') gender = 'Female';

          final role = await RoleService.getRoleByNameOrCreateRole(
            name: row[11].trim(),
          );

          final reportingToVal = row[12]
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          List<String> reportingTo = [];
          for (var i in reportingToVal) {
            if (i.isNotEmpty) {
              var uid = await EmployeeService.getEmployeeById(employeeId: i);
              if (uid != null) {
                reportingTo.add(uid);
              }
            }
          }

          final maritalStatusValue = row[17].trim().toLowerCase();
          var maritalStatus = 'Single';
          if (maritalStatusValue == 'married') {
            maritalStatus = 'Married';
          }

          final employeeTypeValue = row[18].trim().toLowerCase();
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
            employeeId: row[0].trim(),
            name: row[1].trim(),
            email: row[2].trim(),
            password: row[3].trim(),
            designation: designation,
            department: department,
            mobileNumber: row[7].trim(),
            gender: gender,
            subDepartment: subDepartment,
            dateOfJoining: DateFormat("dd-MM-yyyy").parse(row[9].trim()),
            dateOfBirth: DateFormat("dd-MM-yyyy").parse(row[10].trim()),
            role: role,
            reportingTo: reportingTo,
            address: row[13].trim(),
            about: row[14].trim(),
            loginAllowed: row[15].trim().toLowerCase() == 'yes',
            receiveEmailNotifications: row[16].trim().toLowerCase() == 'yes',
            maritalStatus: maritalStatus,
            skills: '',
            employeeType: employeeType,
            createdBy: await Spdb.getUser(),
          );

          await EmployeeService.createEmployee(employee: employeeModel);
          uploadedCount++;
          // Register this new employee's keys so a duplicate later in the
          // same file is also caught, not just duplicates against what
          // already existed before the upload started.
          existingKeys.addAll(rowKeys);
        } catch (e, st) {
          // Show the real error so future failures are self-diagnosing
          // from the toast itself, instead of a generic "skipped".
          final reason =
              'Upload error: ${e.toString().replaceFirst('Exception: ', '')}';
          recordSkip(reason);
          debugPrint('Error uploading row ${i + 1}: $e, $st');
        }
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, true);

      final buffer = StringBuffer()
        ..writeln("Upload Completed")
        ..writeln(
          "Total: $totalRows  •  Added: $uploadedCount  •  Skipped: $skippedCount",
        );

      if (skipReasons.isNotEmpty) {
        final reasonLines = skipReasons.entries
            .map((e) => "${e.key}: ${e.value}")
            .join('\n');
        buffer.write(reasonLines);
      }

      FlushBar.show(
        context,
        buffer.toString().trimRight(),
        isSuccess: uploadedCount > 0,
        duration: skipReasons.isEmpty
            ? const Duration(seconds: 5)
            : Duration(seconds: 5 + skipReasons.length),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(
        context,
        "Error uploading data: ${e.toString()}",
        isSuccess: false,
      );
    }
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
