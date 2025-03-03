import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 可见区间类：表示技师在某一段日期内可见，区间为左闭右开：[start, end)
class VisibleRange {
  DateTime start;
  DateTime? end; // end 为 null 表示一直可见

  VisibleRange({required this.start, this.end});

  // 判断 date 是否在此区间内（只比较日期，不含时分秒）
  bool covers(DateTime date) {
    DateTime d = _truncateToDate(date);
    DateTime s = _truncateToDate(start);
    if (d.isBefore(s)) return false;
    if (end == null) return true;
    DateTime e = _truncateToDate(end!);
    return d.isBefore(e);
  }

  Map<String, dynamic> toJson() => {
        "start": start.toIso8601String(),
        "end": end?.toIso8601String(),
      };

  factory VisibleRange.fromJson(Map<String, dynamic> json) {
    return VisibleRange(
      start: DateTime.parse(json["start"]),
      end: json["end"] == null ? null : DateTime.parse(json["end"]),
    );
  }
}

/// 技师类，采用多区间控制可见性
class Therapist {
  String name;
  List<VisibleRange> visibleRanges;

  Therapist({
    required this.name,
    required this.visibleRanges,
  });

  /// 判断技师在指定日期是否可见
  bool isVisibleOn(DateTime date) {
    for (var range in visibleRanges) {
      if (range.covers(date)) return true;
    }
    return false;
  }

  /// 删除技师：将最后一个区间 (end == null) 截断至 deleteDate（删除当天及以后不可见）
  void deleteFrom(DateTime deleteDate) {
    DateTime d = _truncateToDate(deleteDate);
    for (int i = visibleRanges.length - 1; i >= 0; i--) {
      if (visibleRanges[i].end == null) {
        visibleRanges[i].end = d; // 左闭右开 => d 当天不再覆盖
        break;
      }
    }
  }

  /// 重新激活技师：在 visibleRanges 中添加新的区间 [reactivateDate, null]
  void reactivateFrom(DateTime reactivateDate) {
    DateTime d = _truncateToDate(reactivateDate);
    visibleRanges.add(VisibleRange(start: d, end: null));
  }

  Map<String, dynamic> toJson() => {
        "name": name,
        "visibleRanges": visibleRanges.map((r) => r.toJson()).toList(),
      };

  factory Therapist.fromJson(Map<String, dynamic> json) {
    List<dynamic> ranges = json["visibleRanges"];
    return Therapist(
      name: json["name"],
      visibleRanges: ranges.map((r) => VisibleRange.fromJson(r)).toList(),
    );
  }
}

/// 预约数据模型
class Appointment {
  String id;
  String therapistName;
  DateTime start;
  DateTime end;
  double price;
  String roomNumber;
  bool isNonCash;
  bool starred; // 是否星标熟客

  Appointment({
    required this.id,
    required this.therapistName,
    required this.start,
    required this.end,
    required this.price,
    required this.roomNumber,
    this.isNonCash = false,
    this.starred = false,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "therapistName": therapistName,
        "start": start.toIso8601String(),
        "end": end.toIso8601String(),
        "price": price,
        "roomNumber": roomNumber,
        "isNonCash": isNonCash,
        "starred": starred,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json["id"],
      therapistName: json["therapistName"],
      start: DateTime.parse(json["start"]),
      end: DateTime.parse(json["end"]),
      price: (json["price"] as num).toDouble(),
      roomNumber: json["roomNumber"] ?? "",
      isNonCash: json["isNonCash"] ?? false,
      starred: json["starred"] ?? false,
    );
  }
}

/// 仅保留日期部分
DateTime _truncateToDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Massage Scheduler',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SchedulerPage(),
    );
  }
}

class SchedulerPage extends StatefulWidget {
  const SchedulerPage({super.key});
  @override
  State<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends State<SchedulerPage> {
  List<Therapist> therapists = [];
  List<Appointment> appointments = [];
  Map<String, String> dailyNotes = {};

  DateTime selectedDate = _truncateToDate(DateTime.now());

  final int startHour = 10;
  final int endHour = 20;
  final double rowHeight = 80;
  final double minuteWidth = 2;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? apptJson = prefs.getString("appointments");
    if (apptJson != null) {
      List<dynamic> list = jsonDecode(apptJson);
      setState(() {
        appointments = list.map((e) => Appointment.fromJson(e)).toList();
      });
    }

    String? notesJson = prefs.getString("dailyNotes");
    if (notesJson != null) {
      Map<String, dynamic> notesMap = jsonDecode(notesJson);
      setState(() {
        dailyNotes = notesMap.map((k, v) => MapEntry(k, v as String));
      });
    }

    String? thJson = prefs.getString("therapists");
    if (thJson != null) {
      List<dynamic> tList = jsonDecode(thJson);
      setState(() {
        therapists = tList.map((obj) => Therapist.fromJson(obj)).toList();
      });
    }
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<Map<String, dynamic>> apptList = appointments.map((a) => a.toJson()).toList();
    await prefs.setString("appointments", jsonEncode(apptList));

    await prefs.setString("dailyNotes", jsonEncode(dailyNotes));

    List<Map<String, dynamic>> thList = therapists.map((t) => t.toJson()).toList();
    await prefs.setString("therapists", jsonEncode(thList));
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 检查同一技师当天是否有重叠预约
  bool isOverlapping(String therapistName, DateTime newStart, DateTime newEnd, [String? excludeId]) {
    for (var appt in appointments) {
      if (appt.therapistName == therapistName && isSameDay(appt.start, newStart)) {
        if (excludeId != null && appt.id == excludeId) continue;
        if (newStart.isBefore(appt.end) && newEnd.isAfter(appt.start)) {
          return true;
        }
      }
    }
    return false;
  }

  double getDailyRevenue(DateTime day) {
    double total = 0;
    for (var a in appointments) {
      if (isSameDay(a.start, day)) {
        total += a.price;
      }
    }
    return total;
  }

  String getNoteForDay(DateTime day) {
    return dailyNotes["${day.year}-${day.month}-${day.day}"] ?? "";
  }

  void _gotoPrevDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _gotoNextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
    });
  }

  /// 备注弹窗
  void _showNoteDialog() {
    String oldNote = getNoteForDay(selectedDate);
    TextEditingController noteController = TextEditingController(text: oldNote);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("备注"),
          content: TextField(
            controller: noteController,
            maxLines: 5,
            decoration: const InputDecoration(hintText: "输入当天的特殊情况..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("取消"),
            ),
            ElevatedButton(
              onPressed: () {
                String newNote = noteController.text.trim();
                setState(() {
                  if (newNote.isEmpty) {
                    dailyNotes.remove("${selectedDate.year}-${selectedDate.month}-${selectedDate.day}");
                  } else {
                    dailyNotes["${selectedDate.year}-${selectedDate.month}-${selectedDate.day}"] = newNote;
                  }
                });
                _saveData();
                Navigator.of(ctx).pop();
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );
  }

  /// 添加/重新激活技师对话框
  void _showAddTherapistDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("添加技师"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: "技师姓名"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("取消"),
            ),
            ElevatedButton(
              onPressed: () {
                String name = controller.text.trim();
                if (name.isEmpty) {
                  Navigator.of(ctx).pop();
                  return;
                }

                // 查找是否已存在同名技师
                Therapist? existing = therapists.firstWhere(
                  (th) => th.name == name,
                  orElse: () => null,
                );

                DateTime today = _truncateToDate(DateTime.now());

                if (existing == null) {
                  // 完全不存在 => 创建新技师: 可见区间 [today, null]
                  Therapist t = Therapist(
                    name: name,
                    visibleRanges: [VisibleRange(start: today, end: null)],
                  );
                  setState(() {
                    therapists.add(t);
                  });
                  _saveData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("已添加新技师：$name")),
                  );
                } else {
                  // 已存在 => 判断今天是否可见
                  if (!existing.isVisibleOn(today)) {
                    // 不可见 => 重新激活
                    setState(() {
                      existing.reactivateFrom(today);
                    });
                    _saveData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("已重新激活技师：$name")),
                    );
                  } else {
                    // 已存在且今天可见
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("技师 '$name' 已存在且当前可见。")),
                    );
                  }
                }

                Navigator.of(ctx).pop();
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );
  }

  /// 删除技师
  void _deleteTherapist(Therapist therapist) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("删除技师：${therapist.name}"),
          content: const Text("确定要从今天起隐藏该技师吗？过去的记录仍会保留。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("取消"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  therapist.deleteFrom(selectedDate);
                });
                _saveData();
                Navigator.of(ctx).pop();
              },
              child: const Text("删除"),
            ),
          ],
        );
      },
    );
  }

  /// 添加预约：若技师在预约日不可见，则重新激活
  void _showAddAppointmentDialog() {
    if (therapists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请先添加技师！")),
      );
      return;
    }
    String selectedTherapistName = therapists.first.name;
    String durationOption = "30分钟";
    bool isCustomDuration = false;
    TextEditingController customDurationController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    TextEditingController roomController = TextEditingController();
    bool isNonCash = false;
    bool starred = false;

    DateTime startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 10, 0);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          Future<void> pickTime() async {
            DateTime tempTime = startTime;
            await showModalBottomSheet(
              context: context,
              builder: (context) {
                return StatefulBuilder(
                  builder: (ctxSheet, setStateSheet) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 250,
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            use24hFormat: true,
                            initialDateTime: tempTime,
                            onDateTimeChanged: (DateTime newDate) {
                              setStateSheet(() {
                                tempTime = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  newDate.hour,
                                  newDate.minute,
                                );
                              });
                            },
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setStateDialog(() {
                              startTime = tempTime;
                            });
                            Navigator.of(context).pop();
                          },
                          child: const Text("确定"),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          }

          return AlertDialog(
            title: const Text("添加预约"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "技师"),
                    value: selectedTherapistName,
                    items: therapists.map((th) {
                      return DropdownMenuItem<String>(
                        value: th.name,
                        child: Text(th.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          selectedTherapistName = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("开始时间: "),
                      TextButton(
                        onPressed: pickTime,
                        child: Text(
                          "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "持续时长"),
                    value: durationOption,
                    items: <String>["30分钟", "45分钟", "60分钟", "自定义"].map((e) {
                      return DropdownMenuItem<String>(
                        value: e,
                        child: Text(e),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setStateDialog(() {
                        durationOption = val;
                        isCustomDuration = (val == "自定义");
                      });
                    },
                  ),
                  if (isCustomDuration) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customDurationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "自定义时长(分钟)"),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "价格"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(labelText: "房间号"),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("非现金支付: "),
                      IconButton(
                        onPressed: () {
                          setStateDialog(() {
                            isNonCash = !isNonCash;
                          });
                        },
                        icon: Icon(
                          Icons.change_history,
                          color: isNonCash ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("星标熟客: "),
                      IconButton(
                        onPressed: () {
                          setStateDialog(() {
                            starred = !starred;
                          });
                        },
                        icon: Icon(
                          starred ? Icons.star : Icons.star_border,
                          color: starred ? Colors.yellow : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("取消"),
              ),
              ElevatedButton(
                onPressed: () {
                  double p = double.tryParse(priceController.text) ?? 0.0;
                  int finalDuration;
                  if (isCustomDuration) {
                    finalDuration = int.tryParse(customDurationController.text) ?? 0;
                    if (finalDuration <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("自定义时长无效！")),
                      );
                      return;
                    }
                  } else {
                    String numStr = durationOption.replaceAll("分钟", "");
                    finalDuration = int.tryParse(numStr) ?? 30;
                  }
                  DateTime endTime = startTime.add(Duration(minutes: finalDuration));
                  if (endTime.isBefore(startTime)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("结束时间不能早于开始时间！")),
                    );
                    return;
                  }
                  if (isOverlapping(selectedTherapistName, startTime, endTime)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("该技师在此时间已有预约，请选择其它时间。")),
                    );
                    return;
                  }
                  String newId = "${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}";
                  Appointment appt = Appointment(
                    id: newId,
                    therapistName: selectedTherapistName,
                    start: startTime,
                    end: endTime,
                    price: p,
                    roomNumber: roomController.text,
                    isNonCash: isNonCash,
                    starred: starred,
                  );
                  setState(() {
                    appointments.add(appt);
                    // 如果该技师在预约日不可见 => re-activate
                    Therapist? t = therapists.firstWhere((th) => th.name == selectedTherapistName, orElse: () => null);
                    if (t != null && !t.isVisibleOn(startTime)) {
                      t.reactivateFrom(startTime);
                    }
                  });
                  _saveData();
                  Navigator.of(ctx).pop();
                },
                child: const Text("保存"),
              ),
            ],
          );
        });
      },
    );
  }

  /// 构建界面
  @override
  Widget build(BuildContext context) {
    double dailyRev = 0;
    for (var a in appointments) {
      if (isSameDay(a.start, selectedDate)) {
        dailyRev += a.price;
      }
    }
    double nonCashRev = appointments
        .where((a) => isSameDay(a.start, selectedDate) && a.isNonCash)
        .fold(0.0, (prev, a) => prev + a.price);

    String dateString =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    // 只显示在 selectedDate 可见的技师
    final visibleTherapists = therapists.where((t) => t.isVisibleOn(selectedDate)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("按摩店预约排程"),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: "添加技师",
            onPressed: _showAddTherapistDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left, color: Colors.white),
                onPressed: _gotoPrevDay,
              ),
              GestureDetector(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: selectedDate.subtract(const Duration(days: 365)),
                    lastDate: selectedDate.add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = _truncateToDate(picked);
                    });
                  }
                },
                child: Text(
                  dateString,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_right, color: Colors.white),
                onPressed: _gotoNextDay,
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          if (therapists.isEmpty)
            Center(
              child: Text(
                "暂无技师，请先添加。",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            )
          else
            ReorderableListView(
              padding: const EdgeInsets.only(bottom: 80),
              onReorder: _onReorder,
              children: [
                for (var t in visibleTherapists)
                  _buildRowForTherapist(t, ValueKey(t.name)),
              ],
            ),
          Positioned(
            left: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: _showNoteDialog,
              child: const Text("备注"),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _showAddAppointmentDialog,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 8.0,
        child: SizedBox(
          height: 50,
          child: Center(
            child: Text(
              "营业额: ￥${dailyRev.toStringAsFixed(2)}，其中非现金金额: ￥${nonCashRev.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  /// 拖拽排序
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = therapists.removeAt(oldIndex);
      therapists.insert(newIndex, item);
      _saveData();
    });
  }

  /// 构建技师行
  Widget _buildRowForTherapist(Therapist therapist, Key key) {
    return Container(
      key: key,
      height: rowHeight,
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: _rowContent(therapist),
    );
  }

  /// row 内容：左侧技师信息 + 右侧时间轴
  Widget _rowContent(Therapist therapist) {
    // 找出该技师在 selectedDate 这天的所有预约
    List<Appointment> dayAppointments = appointments.where((a) {
      return a.therapistName == therapist.name && isSameDay(a.start, selectedDate);
    }).toList();

    int totalMinutes = (endHour - startHour) * 60;
    double tableWidth = totalMinutes * minuteWidth;
    double personalRev = 0;
    for (var appt in dayAppointments) {
      personalRev += appt.price;
    }

    return Row(
      children: [
        // 左侧：点击可删除
        InkWell(
          onTap: () => _deleteTherapist(therapist),
          child: Container(
            width: 120,
            color: Colors.grey[200],
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(therapist.name, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  "营业额: ￥${personalRev.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        // 右侧时间表
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: rowHeight,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(tableWidth, rowHeight),
                    painter: TimeRowBackgroundPainter(
                      startHour: startHour,
                      endHour: endHour,
                      minuteWidth: minuteWidth,
                      rowHeight: rowHeight,
                    ),
                  ),
                  for (var appt in dayAppointments)
                    _buildAppointmentBlock(appt),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 绘制预约块
  Widget _buildAppointmentBlock(Appointment appt) {
    int totalMinutes = (endHour - startHour) * 60;
    int startMin = (appt.start.hour - startHour) * 60 + appt.start.minute;
    int endMin = (appt.end.hour - startHour) * 60 + appt.end.minute;
    startMin = startMin.clamp(0, totalMinutes);
    endMin = endMin.clamp(0, totalMinutes);

    double left = startMin * minuteWidth;
    double width = (endMin - startMin) * minuteWidth;
    if (width < 0) width = 0;

    // 颜色规则：未输入价格或房间 => 黄色优先；否则星标 => 红色；否则蓝色
    Color blockColor;
    if (appt.price <= 0 || appt.roomNumber.isEmpty) {
      blockColor = Colors.yellow.withOpacity(0.8);
    } else if (appt.starred) {
      blockColor = Colors.redAccent.withOpacity(0.8);
    } else {
      blockColor = Colors.lightBlueAccent.withOpacity(0.8);
    }

    String txt = "房间 ${appt.roomNumber} " +
        (appt.isNonCash ? "△ " : "") +
        "￥${appt.price.toStringAsFixed(2)}";

    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: rowHeight,
      child: GestureDetector(
        onTap: () => _showEditAppointmentDialog(appt),
        child: Container(
          color: blockColor,
          alignment: Alignment.center,
          child: Text(
            txt,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 自定义背景画布：绘制每小时竖线和时间标签
class TimeRowBackgroundPainter extends CustomPainter {
  final int startHour;
  final int endHour;
  final double minuteWidth;
  final double rowHeight;

  TimeRowBackgroundPainter({
    required this.startHour,
    required this.endHour,
    required this.minuteWidth,
    required this.rowHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint linePaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;

    int totalMinutes = (endHour - startHour) * 60;
    for (int i = 0; i <= totalMinutes; i += 60) {
      double x = i * minuteWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      TextSpan span = TextSpan(
        text: "${startHour + i ~/ 60}:00",
        style: const TextStyle(fontSize: 10, color: Colors.black),
      );
      TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      if (x + tp.width < size.width) {
        tp.paint(canvas, Offset(x + 2, 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
