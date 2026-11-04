/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:intl/intl.dart';
import 'package:leadcapture/constants/src/enum.dart';
import 'package:leadcapture/models/src/filter_model.dart';
import 'package:leadcapture/views/ui/src/form_fields.dart';
import 'package:leadcapture/views/ui/src/submit_button.dart';

// Project imports:
import '/utils/utils.dart';

class Filter extends StatefulWidget {
  final int totalCount;
  final FilterModel filter;
  final List<FilterRequirements>? requirements;
  const Filter({
    super.key,
    required this.totalCount,
    required this.filter,
    this.requirements,
  });

  @override
  State<Filter> createState() => _FilterState();
}

class _FilterState extends State<Filter> {
  final TextEditingController _pageNo = TextEditingController();
  final TextEditingController _pageLimit = TextEditingController();
  final TextEditingController _fromDate = TextEditingController();
  final TextEditingController _toDate = TextEditingController();

  @override
  void initState() {
    _init();
    super.initState();
  }

  final List<String> _pageNoList = [];
  final List<String> _pageLimitList = ["10", "50", "100", "250", "500", "1000"];

  _init() {
    _fromDate.text = DateFormat('dd-MM-yyyy').format(widget.filter.fromDate);
    _toDate.text = DateFormat('dd-MM-yyyy').format(widget.filter.toDate);
    _pageNo.text = widget.filter.pageNumber.toString();
    _pageLimit.text = widget.filter.pageLimit.toString();

    int totalPages = (widget.totalCount / widget.filter.pageLimit).ceil();

    _pageNoList.clear();
    for (int i = 1; i <= totalPages; i++) {
      _pageNoList.add(i.toString());
    }
  }

  final GlobalKey _pageNoKey = GlobalKey();
  final GlobalKey _pageLimitKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        bottomNavigationBar: SubmitButton(
          event: () {
            var filterModel = FilterModel(
              pageNumber: int.parse(_pageNo.text),
              pageLimit: int.parse(_pageLimit.text),
              fromDate: DateFormat('dd-MM-yyyy').parse(_fromDate.text),
              toDate: DateTime(
                DateTime.now().year,
                DateFormat('dd-MM-yyyy').parse(_toDate.text).month,
                DateFormat('dd-MM-yyyy').parse(_toDate.text).day,
                23,
                59,
                59,
              ),
            );

            Navigator.pop(context, filterModel);
          },
        ),
        body: ListView(
          padding: const EdgeInsets.only(left: 15, bottom: 15, right: 15),
          children: [
            FormFields(
              key: _pageNoKey,
              readOnly: true,
              controller: _pageNo,
              label: "Page No",
              fillColor: Theme.of(context).colorScheme.surface,
              onTap: () async {
                RenderBox renderBox =
                    _pageNoKey.currentContext!.findRenderObject() as RenderBox;
                Offset position = renderBox.localToGlobal(Offset.zero);

                final selectedValue = await showMenu<String>(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    position.dx,
                    position.dy + renderBox.size.height,
                    position.dx + renderBox.size.width,
                    MediaQuery.of(context).size.height - position.dy,
                  ),
                  items: _pageNoList.map((e) {
                    return PopupMenuItem<String>(value: e, child: Text(e));
                  }).toList(),
                );

                if (selectedValue != null) {
                  _pageNo.text = selectedValue;
                }
              },
            ),
            const SizedBox(height: 10),
            FormFields(
              key: _pageLimitKey,
              controller: _pageLimit,
              label: "Page Limit",
              readOnly: true,
              fillColor: Theme.of(context).colorScheme.surface,
              onTap: () async {
                RenderBox renderBox =
                    _pageLimitKey.currentContext!.findRenderObject()
                        as RenderBox;
                Offset position = renderBox.localToGlobal(Offset.zero);

                final selectedValue = await showMenu<String>(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    position.dx,
                    position.dy + renderBox.size.height,
                    position.dx + renderBox.size.width,
                    MediaQuery.of(context).size.height - position.dy,
                  ),
                  items: _pageLimitList.map((e) {
                    return PopupMenuItem<String>(value: e, child: Text(e));
                  }).toList(),
                );

                if (selectedValue != null) {
                  _pageLimit.text = selectedValue;
                }
              },
            ),
            const SizedBox(height: 10),
            FormFields(
              readOnly: true,
              controller: _fromDate,
              label: "From Date",
              hintText: "dd-mm-yyyy",
              fillColor: Theme.of(context).colorScheme.surface,
              onTap: () async {
                var v = await pickDate(
                  context,
                  initialDate: widget.filter.fromDate,
                  lastDate: DateTime.now(),
                );
                if (v != null) {
                  _fromDate.text = v;
                }
              },
            ),
            const SizedBox(height: 10),
            FormFields(
              readOnly: true,
              controller: _toDate,
              label: "To Date",
              hintText: "dd-mm-yyyy",
              fillColor: Theme.of(context).colorScheme.surface,
              onTap: () async {
                var v = await pickDate(context, lastDate: DateTime.now());
                if (v != null) {
                  _toDate.text = v;
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class RideFilter extends StatefulWidget {
  final RideFilterModel filter;
  const RideFilter({super.key, required this.filter});

  @override
  State<RideFilter> createState() => _RideFilterState();
}

class _RideFilterState extends State<RideFilter> {
  final TextEditingController _fromDate = TextEditingController();
  final TextEditingController _toDate = TextEditingController();

  @override
  void initState() {
    _init();
    super.initState();
  }

  _init() {
    _fromDate.text = DateFormat('dd-MM-yyyy').format(widget.filter.fromDate);
    _toDate.text = DateFormat('dd-MM-yyyy').format(widget.filter.toDate);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        bottomNavigationBar: SubmitButton(
          event: () {
            var filterModel = RideFilterModel(
              fromDate: DateFormat('dd-MM-yyyy').parse(_fromDate.text),
              toDate: DateTime(
                DateTime.now().year,
                DateFormat('dd-MM-yyyy').parse(_toDate.text).month,
                DateFormat('dd-MM-yyyy').parse(_toDate.text).day,
                23,
                59,
                59,
              ),
            );

            Navigator.pop(context, filterModel);
          },
        ),
        body: ListView(
          padding: const EdgeInsets.only(left: 15, bottom: 15, right: 15),
          children: [
            FormFields(
              readOnly: true,
              controller: _fromDate,
              label: "From Date",
              hintText: "dd-mm-yyyy",
              fillColor: Theme.of(context).colorScheme.surface,
              onTap: () async {
                var v = await pickDate(
                  context,
                  initialDate: widget.filter.fromDate,
                  lastDate: DateTime.now(),
                );
                if (v != null) {
                  _fromDate.text = v;
                }
              },
            ),
            const SizedBox(height: 10),
            FormFields(
              readOnly: true,
              controller: _toDate,
              label: "To Date",
              hintText: "dd-mm-yyyy",
              fillColor: Theme.of(context).colorScheme.surface,
              onTap: () async {
                var v = await pickDate(context, lastDate: DateTime.now());
                if (v != null) {
                  _toDate.text = v;
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
