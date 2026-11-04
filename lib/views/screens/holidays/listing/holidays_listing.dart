import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/utils/src/platform.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import 'bloc/holiday_bloc.dart';

class HolidaysListing extends StatelessWidget {
  const HolidaysListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HolidayBloc()..add(LoadHolidays()),
      child: const HolidayListView(),
    );
  }
}

class HolidayListView extends StatefulWidget {
  const HolidayListView({super.key});

  @override
  State<HolidayListView> createState() => _HolidayListViewState();
}

class _HolidayListViewState extends State<HolidayListView> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await Spdb.isAdminLoggedIn();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsMobile
          ? AppBar(leading: const Back(), title: const Text('Holidays'))
          : null,
      body: BlocBuilder<HolidayBloc, HolidayState>(
        builder: (context, state) {
          if (state is HolidayLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HolidayError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<HolidayBloc>().add(LoadHolidays());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is HolidayLoaded) {
            if (state.holidays.isEmpty) {
              return const NoData(text: "No holidays available");
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<HolidayBloc>().add(LoadHolidays());
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildHolidayTable(context, state.holidays),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            final form = const HolidayForm();
            if (kIsMobile) {
              Sheet.showSheet(context, widget: form);
            } else {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(width: 500, child: form),
                ),
              );
            }
          },
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            "Add Holiday",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildHolidayTable(BuildContext context, List<HolidayModel> holidays) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: _buildColumns(context),
          rows: holidays.map((holiday) {
            return _buildRow(context, holiday);
          }).toList(),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns(BuildContext context) {
    return [
      DataColumn(
        label: Text("Date", style: Theme.of(context).textTheme.bodySmall),
      ),
      DataColumn(
        label: Text("Reason", style: Theme.of(context).textTheme.bodySmall),
      ),
      DataColumn(
        label: Text("Days", style: Theme.of(context).textTheme.bodySmall),
      ),
      DataColumn(
        label: Text("Created By", style: Theme.of(context).textTheme.bodySmall),
      ),
      DataColumn(
        label: Text("Action", style: Theme.of(context).textTheme.bodySmall),
      ),
    ];
  }

  DataRow _buildRow(BuildContext context, HolidayModel holiday) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            DateFormat('yyyy-MM-dd').format(holiday.date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(
          Text(holiday.reason, style: Theme.of(context).textTheme.bodySmall),
        ),
        DataCell(
          Text(
            holiday.days.toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(
          Text(
            holiday.createdBy.name,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () {
                  final form = HolidayForm(holiday: holiday);
                  if (kIsMobile) {
                    Sheet.showSheet(context, widget: form);
                  } else {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SizedBox(width: 500, child: form),
                      ),
                    );
                  }
                },
                tooltip: 'Edit',
              ),
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => _confirmDelete(context, holiday),
                  tooltip: 'Delete',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HolidayModel holiday,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text('Are you sure you want to delete "${holiday.reason}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await HolidayService.deleteHoliday(uid: holiday.uid ?? '');
        if (!context.mounted) return;
        FlushBar.show(context, 'Holiday deleted successfully');
        context.read<HolidayBloc>().add(LoadHolidays());
      } catch (e) {
        if (!context.mounted) return;
        FlushBar.show(
          context,
          'Failed to delete holiday: $e',
          isSuccess: false,
        );
      }
    }
  }
}
