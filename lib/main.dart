import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 表示一个可见区间：start <= 日期 < end (如果 end == null 表示无限未来)
class VisibleRange {
  DateTime start;
  DateTime? end;

  VisibleRange({required this.start, this.end});

  bool covers(DateTime date) {
    // date >= start && (end == null || date < end)
    if (date.isBefore(start)) return false;
    if (end == null) return true;
    return date.isBefore(end!);
  }

  // JSON 序列化
  Map<String, dynamic> toJson() => {
        "start": start.toIso8601String(),
        "end": end?.toIso8601String(),
      };

  // JSON 反序列化
  factory VisibleRange.fromJson(Map<String, dynamic> json) {
    return VisibleRange(
      start: DateTime.parse(json["start"]),
      end: json["end"] == null ? null : DateTime.parse(json["end"]),
    );
  }
}

/// 技师对象，使用多段可见区间 visibleRanges 管理显示周期
class Therapist {
  String name;
  List<VisibleRange> visibleRanges;

  Therapist({
    required this.name,
    required this.visibleRanges,
  });

  // 判断某一天是否可见：只要这一天落在任意一个区间内即可
  bool isVisibleOn(DateTime date) {
    for (var range in visibleRanges) {
      if (range.covers(date)) return true;
    }
    return false;
  }

  // 删除(隐藏)技师：将最后一个区间 [X, null] 改成 [X, deleteDay)
  void deleteFrom(DateTime deleteDay) {
    // truncate
    DateTime d = _truncateToDate(deleteDay);

    // 找到最后一个 end == null 的区间，把它的 end 改为 d
    for (int i = visibleRanges.length - 1; i >= 0; i--) {
      if (visibleRanges[i].end == null) {
        visibleRanges[i].end = d;
        break;
      }
    }
  }

  // 重新激活：在 visibleRanges 中再追加一个 [reactivateDay, null]
  void reactivateFrom(DateTime reDay) {
    DateTime r = _truncateToDate(reDay);
    visibleRanges.add(VisibleRange(start: r, end: null));
  }

  // JSON 序列化
  Map<String, dynamic> toJson() => {
        "name": name,
        "visibleRanges": visibleRanges.map((r) => r.to
