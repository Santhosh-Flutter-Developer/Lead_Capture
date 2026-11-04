/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

// ignore_for_file: public_member_api_docs, sort_constructors_first

// Dart imports:
import 'dart:convert';

class FilterModel {
  int pageNumber;
  int pageLimit;
  DateTime fromDate;
  DateTime toDate;

  FilterModel({
    DateTime? fromDate,
    DateTime? toDate,
    required this.pageNumber,
    required this.pageLimit,
  }) : fromDate = fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
       toDate =
           toDate ??
           DateTime(
             DateTime.now().year,
             DateTime.now().month,
             DateTime.now().day,
             23,
             59,
             59,
           );

  FilterModel copyWith({
    int? pageNumber,
    int? pageLimit,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return FilterModel(
      pageNumber: pageNumber ?? this.pageNumber,
      pageLimit: pageLimit ?? this.pageLimit,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pageNumber': pageNumber,
      'pageLimit': pageLimit,
      'fromDate': fromDate.millisecondsSinceEpoch,
      'toDate': toDate.millisecondsSinceEpoch,
    };
  }

  factory FilterModel.fromMap(Map<String, dynamic> map) {
    return FilterModel(
      pageNumber: map['pageNumber'] as int,
      pageLimit: map['pageLimit'] as int,
      fromDate: DateTime.fromMillisecondsSinceEpoch(map['fromDate'] as int),
      toDate: DateTime.fromMillisecondsSinceEpoch(map['toDate'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory FilterModel.fromJson(String source) =>
      FilterModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'FilterModel(pageNumber: $pageNumber, pageLimit: $pageLimit, fromDate: $fromDate, toDate: $toDate)';
  }

  @override
  bool operator ==(covariant FilterModel other) {
    if (identical(this, other)) return true;

    return other.pageNumber == pageNumber &&
        other.pageLimit == pageLimit &&
        other.fromDate == fromDate &&
        other.toDate == toDate;
  }

  @override
  int get hashCode {
    return pageNumber.hashCode ^
        pageLimit.hashCode ^
        fromDate.hashCode ^
        toDate.hashCode;
  }
}

class RideFilterModel {
  DateTime fromDate;
  DateTime toDate;

  RideFilterModel({DateTime? fromDate, DateTime? toDate})
    : fromDate =
          fromDate ??
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            00,
            00,
            00,
          ),
      toDate =
          toDate ??
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            23,
            59,
            59,
          );

  RideFilterModel copyWith({DateTime? fromDate, DateTime? toDate}) {
    return RideFilterModel(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fromDate': fromDate.millisecondsSinceEpoch,
      'toDate': toDate.millisecondsSinceEpoch,
    };
  }

  factory RideFilterModel.fromMap(Map<String, dynamic> map) {
    return RideFilterModel(
      fromDate: DateTime.fromMillisecondsSinceEpoch(map['fromDate'] as int),
      toDate: DateTime.fromMillisecondsSinceEpoch(map['toDate'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory RideFilterModel.fromJson(String source) =>
      RideFilterModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'FilterModel(fromDate: $fromDate, toDate: $toDate)';
  }

  @override
  bool operator ==(covariant FilterModel other) {
    if (identical(this, other)) return true;

    return other.fromDate == fromDate && other.toDate == toDate;
  }

  @override
  int get hashCode {
    return fromDate.hashCode ^ toDate.hashCode;
  }
}
