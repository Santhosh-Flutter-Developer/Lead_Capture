import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class EmployeeList extends StatefulWidget {
  const EmployeeList({super.key});

  @override
  State<EmployeeList> createState() => _EmployeeListState();
}

class _EmployeeListState extends State<EmployeeList> {
  final TextEditingController _search = TextEditingController();
  List<EmployeeModel> _employeesList = [];
  List<EmployeeModel> _allEmployeesList = [];
  Future? _employeesListHandler;

  void resetSearch() {
    setState(() {
      _employeesList = List.from(_allEmployeesList);
    });
  }

  @override
  void initState() {
    super.initState();
    _employeesListHandler = _getEmployee();
  }

  Future _getEmployee() async {
    try {
      _employeesList.clear();
      _allEmployeesList.clear();
      setState(() {});

      List<EmployeeModel> r;

      r = await EmployeeService.getAllEmployees();

      if (r.isNotEmpty) {
        _allEmployeesList = r;
        _employeesList = List.from(_allEmployeesList);
        _employeesList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  _searchCustomer() {
    List<EmployeeModel> filteredList = _allEmployeesList.where((customers) {
      return customers.name.toLowerCase().contains(_search.text.toLowerCase());
    }).toList();

    setState(() {
      _employeesList = filteredList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Padding(
          padding: const EdgeInsets.only(left: 15, bottom: 15, right: 15),
          child: FutureBuilder(
            future: _employeesListHandler,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const WaitingLoading();
              } else if (snapshot.hasError) {
                return ErrorDisplay(error: snapshot.error.toString());
              } else {
                return Column(
                  children: [
                    FormFields(
                      controller: _search,
                      prefixIcon: const Icon(Iconsax.search_normal),
                      hintText: "Search employees",
                      onChanged: (value) => _searchCustomer(),
                      fillColor: AppColors.white,
                      suffixIcon: _search.text.isNotEmpty
                          ? TextButton(
                              onPressed: () {
                                _search.clear();
                                resetSearch();
                              },
                              child: Text(
                                "Clear",
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.grey700),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    if (_employeesList.isNotEmpty)
                      Flexible(
                        child: ListView.separated(
                          primary: false,
                          shrinkWrap: true,
                          itemCount: _employeesList.length,
                          itemBuilder: (context, index) {
                            var employee = _employeesList[index];
                            return ListTile(
                              onTap: () {},
                              title: Text(
                                employee.name,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.black),
                              ),
                              tileColor: AppColors.transparent,
                              subtitle: Text(
                                CacheService.designationByUid(
                                      employee.designation,
                                    )?.name ??
                                    '',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.black),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                backgroundImage:
                                    employee.profileImageUrl != null
                                    ? NetworkImage(employee.profileImageUrl!)
                                    : null,
                                child: employee.profileImageUrl == null
                                    ? Text(
                                        employee.name.capitalizeFirst,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.white),
                                      )
                                    : null,
                              ),
                            );
                          },
                          separatorBuilder: (context, index) {
                            return const Divider(color: AppColors.grey300);
                          },
                        ),
                      )
                    else
                      const NoData(bgColor: AppColors.white),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
