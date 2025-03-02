import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 预约数据模型，新增了房间号和是否非现金支付两个字段
class Appointment {
  String id;
  String therapist;
  DateTime start;
  DateTime end;
  double price;
  String roomNumber; // 新增房间号
  bool isNonCash;    // 新增是否非现金支付

  Appointment({
    required this.id,
    required this.therapist,
    required this.start,
    required this.end,
    required this.price,
    required this.roomNumber,
    this.isNonCash = false,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "therapist": therapist,
        "start": start.toIso8601String(),
        "end": end.toIso8601String(),
        "price": price,
        "roomNumber": roomNumber,
        "isNonCash": isNonCash,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json["id"],
      therapist: json["therapist"],
      start: DateTime.parse(json["start"]),
      end: DateTime.parse(json["end"]),
      price: (json["price"] as num).toDouble(),
      roomNumber: json["roomNumber"] ?? "",
      isNonCash: json["isNonCash"] ?? false,
    );
  }
}

void main() {
  runApp(const MyApp());
}

/// 应用入口
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

/// 主页面
class SchedulerPage extends StatefulWidget {
  const SchedulerPage({super.key});

  @override
  State<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends State<SchedulerPage> {
  List<String> therapists = [];
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

  static DateTime _truncateToDate(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apptJson = prefs.getString("appointments");
    String? notesJson = prefs.getString("dailyNotes");

    if (apptJson != null) {
      List<dynamic> list = jsonDecode(apptJson);
      List<Appointment> loaded = list.map((e) => Appointment.fromJson(e)).toList();
      setState(() {
        appointments = loaded;
      });
    }
    if (notesJson != null) {
      Map<String, dynamic> notesMap = jsonDecode(notesJson);
      setState(() {
        dailyNotes = notesMap.map((k, v) => MapEntry(k, v as String));
      });
    }
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<Map<String, dynamic>> apptList = appointments.map((a) => a.toJson()).toList();
    String apptJson = jsonEncode(apptList);
    await prefs.setString("appointments", apptJson);

    String notesJson = jsonEncode(dailyNotes);
    await prefs.setString("dailyNotes", notesJson);
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

  double getPersonalRevenue(String therapist, DateTime day) {
    double sum = 0;
    for (var a in appointments) {
      if (a.therapist == therapist && isSameDay(a.start, day)) {
        sum += a.price;
      }
    }
    return sum;
  }

  String getNoteForDay(DateTime day) {
    return dailyNotes[_dateKey(day)] ?? "";
  }

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
                    dailyNotes.remove(_dateKey(selectedDate));
                  } else {
                    dailyNotes[_dateKey(selectedDate)] = newNote;
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
                if (name.isNotEmpty && !therapists.contains(name)) {
                  setState(() {
                    therapists.add(name);
                  });
                  _saveData();
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

  void _showAddAppointmentDialog() {
    if (therapists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请先添加技师！")),
      );
      return;
    }

    String selectedTherapist = therapists.first;
    String durationOption = "30分钟";
    bool isCustomDuration = false;
    TextEditingController customDurationController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    TextEditingController roomController = TextEditingController(); // 房间号输入
    bool isNonCash = false; // 是否非现金支付

    DateTime startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 10, 0);

    Future<void> pickTime() async {
      await showModalBottomSheet(
        context: context,
        builder: (_) {
          return SizedBox(
            height: 250,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: startTime,
              onDateTimeChanged: (DateTime newDate) {
                startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
                    newDate.hour, newDate.minute);
              },
            ),
          );
        },
      );
      setState(() {});
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("添加预约"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "技师"),
                    value: selectedTherapist,
                    items: therapists.map((t) {
                      return DropdownMenuItem<String>(
                        value: t,
                        child: Text(t),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          selectedTherapist = value;
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
                  // 新增房间号输入
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(labelText: "房间号"),
                  ),
                  const SizedBox(height: 8),
                  // 新增非现金支付选择（三角标）
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

                  String newId = "${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}";
                  Appointment appt = Appointment(
                    id: newId,
                    therapist: selectedTherapist,
                    start: startTime,
                    end: endTime,
                    price: p,
                    roomNumber: roomController.text,
                    isNonCash: isNonCash,
                  );
                  setState(() {
                    appointments.add(appt);
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

  void _deleteTherapist(String therapist) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("删除技师：$therapist"),
          content: const Text("确定要删除该技师及其所有预约吗？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("取消"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  therapists.remove(therapist);
                  appointments.removeWhere((appt) => appt.therapist == therapist);
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

  /// 返回一个“技师行”Widget，带 key
  Widget _buildRowForTherapist(String therapist, Key key) {
    return Container(
      key: key,
      height: rowHeight,
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: _rowContent(therapist),
    );
  }

  /// 将 row 的实际内容分离出来，避免重复
  Widget _rowContent(String therapist) {
    // 过滤该技师在 selectedDate 的预约
    List<Appointment> dayAppointments = appointments.where((a) {
      return a.therapist == therapist && isSameDay(a.start, selectedDate);
    }).toList();

    int totalMinutes = (endHour - startHour) * 60;
    double tableWidth = totalMinutes * minuteWidth;
    double personalRev = getPersonalRevenue(therapist, selectedDate);

    return Row(
      children: [
        // 左侧：技师姓名 + 个人营业额 + 点击删除
        InkWell(
          onTap: () {
            _deleteTherapist(therapist);
          },
          child: Container(
            width: 120,
            color: Colors.grey[200],
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(therapist, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  "营业额: ￥${personalRev.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        // 右侧：时间表网格
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: tableWidth,
              height: rowHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: CustomPaint(
                painter: TimeRowPainter(
                  startHour: startHour,
                  endHour: endHour,
                  minuteWidth: minuteWidth,
                  rowHeight: rowHeight,
                  appointments: dayAppointments,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 拖拽排序
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex--;
      }
      final item = therapists.removeAt(oldIndex);
      therapists.insert(newIndex, item);
      _saveData();
    });
  }

  @override
  Widget build(BuildContext context) {
    double dailyRev = getDailyRevenue(selectedDate);
    double nonCashRev = appointments
        .where((a) => isSameDay(a.start, selectedDate) && a.isNonCash)
        .fold(0.0, (prev, a) => prev + a.price);
    String dateString =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

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
                for (String t in therapists)
                  _buildRowForTherapist(t, ValueKey(t)),
              ],
            ),
          // 左下角：备注按钮
          Positioned(
            left: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: _showNoteDialog,
              child: const Text("备注"),
            ),
          ),
          // 右下角：添加预约
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
}

/// 自定义绘制时间行的 Painter
class TimeRowPainter extends CustomPainter {
  final int startHour;
  final int endHour;
  final double minuteWidth;
  final double rowHeight;
  final List<Appointment> appointments;

  TimeRowPainter({
    required this.startHour,
    required this.endHour,
    required this.minuteWidth,
    required this.rowHeight,
    required this.appointments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint linePaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;

    int totalMinutes = (endHour - startHour) * 60;

    // 绘制每小时竖线和时间标签
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

    // 绘制预约块
    for (var appt in appointments) {
      int startMin = (appt.start.hour - startHour) * 60 + appt.start.minute;
      int endMin = (appt.end.hour - startHour) * 60 + appt.end.minute;
      startMin = startMin.clamp(0, totalMinutes);
      endMin = endMin.clamp(0, totalMinutes);

      double left = startMin * minuteWidth;
      double width = (endMin - startMin) * minuteWidth;
      if (width < 0) width = 0;

      Paint rectPaint = Paint()
        ..color = Colors.lightBlueAccent.withOpacity(0.8);

      Rect rect = Rect.fromLTWH(left, 0, width, rowHeight);
      canvas.drawRect(rect, rectPaint);

      // 显示内容：房间号、非现金标识（三角）及价格
      String txt = "房间 ${appt.roomNumber} " + (appt.isNonCash ? "△ " : "") + "￥${appt.price.toStringAsFixed(2)}";
      TextSpan sp = TextSpan(
        text: txt,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      );
      TextPainter tPainter = TextPainter(
        text: sp,
        textDirection: TextDirection.ltr,
      );
      tPainter.layout(maxWidth: width);

      double textX = left + (width - tPainter.width) / 2;
      double textY = (rowHeight - tPainter.height) / 2;
      if (textX < left) textX = left;
      if (textX + tPainter.width > left + width) textX = left;
      tPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
