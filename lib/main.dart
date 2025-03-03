import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 表示一个技师对象
class Therapist {
  String name;
  DateTime? deletedAt; // 如果不为空，表示从 deletedAt 这一天起，该技师不再显示

  Therapist({
    required this.name,
    this.deletedAt,
  });

  // 转成 JSON 方便存储
  Map<String, dynamic> toJson() => {
        "name": name,
        "deletedAt": deletedAt?.toIso8601String(),
      };

  // 从 JSON 解析
  factory Therapist.fromJson(Map<String, dynamic> json) {
    return Therapist(
      name: json["name"],
      deletedAt: json["deletedAt"] == null
          ? null
          : DateTime.parse(json["deletedAt"]),
    );
  }
}

/// 预约数据模型
/// 新增字段 [starred] 表示“星标熟客”
class Appointment {
  String id;
  String therapistName; // 这里存技师的名字，跟 Therapist.name 对应
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
  // 技师列表，使用 Therapist 对象
  List<Therapist> therapists = [];
  // 预约列表
  List<Appointment> appointments = [];
  // 每日备注
  Map<String, String> dailyNotes = {};

  DateTime selectedDate = _truncateToDate(DateTime.now());

  final int startHour = 10;
  final int endHour = 20;
  final double rowHeight = 80;   // 每个技师行的高度
  final double minuteWidth = 2;  // 每分钟对应的像素宽度

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 去掉时分秒，只保留日期
  static DateTime _truncateToDate(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 检查同一技师的预约是否重叠（只检查当天的预约）
  bool isOverlapping(String therapistName, DateTime newStart, DateTime newEnd, [String? excludeId]) {
    for (var appt in appointments) {
      if (appt.therapistName == therapistName && isSameDay(appt.start, newStart)) {
        if (excludeId != null && appt.id == excludeId) continue;
        // 如果新预约与已有预约重叠：newStart < appt.end 且 newEnd > appt.start
        if (newStart.isBefore(appt.end) && newEnd.isAfter(appt.start)) {
          return true;
        }
      }
    }
    return false;
  }

  /// 从本地存储加载数据
  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 读取 appointments
    String? apptJson = prefs.getString("appointments");
    if (apptJson != null) {
      List<dynamic> list = jsonDecode(apptJson);
      List<Appointment> loaded = list.map((e) => Appointment.fromJson(e)).toList();
      setState(() {
        appointments = loaded;
      });
    }

    // 读取 dailyNotes
    String? notesJson = prefs.getString("dailyNotes");
    if (notesJson != null) {
      Map<String, dynamic> notesMap = jsonDecode(notesJson);
      setState(() {
        dailyNotes = notesMap.map((k, v) => MapEntry(k, v as String));
      });
    }

    // 读取 therapists
    String? thJson = prefs.getString("therapists");
    if (thJson != null) {
      List<dynamic> tList = jsonDecode(thJson);
      setState(() {
        therapists = tList.map((obj) => Therapist.fromJson(obj)).toList();
      });
    }
  }

  /// 保存数据到本地
  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // appointments
    List<Map<String, dynamic>> apptList = appointments.map((a) => a.toJson()).toList();
    await prefs.setString("appointments", jsonEncode(apptList));

    // dailyNotes
    await prefs.setString("dailyNotes", jsonEncode(dailyNotes));

    // therapists
    List<Map<String, dynamic>> thList = therapists.map((t) => t.toJson()).toList();
    await prefs.setString("therapists", jsonEncode(thList));
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

  double getPersonalRevenue(String therapistName, DateTime day) {
    double sum = 0;
    for (var a in appointments) {
      if (a.therapistName == therapistName && isSameDay(a.start, day)) {
        sum += a.price;
      }
    }
    return sum;
  }

  String getNoteForDay(DateTime day) {
    return dailyNotes[_dateKey(day)] ?? "";
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

  /// 编辑当天备注
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

  /// 添加技师
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
                if (name.isNotEmpty) {
                  bool alreadyExists = therapists.any((th) => th.name == name);
                  if (!alreadyExists) {
                    setState(() {
                      therapists.add(Therapist(name: name, deletedAt: null));
                    });
                    _saveData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("技师 '$name' 已存在。")),
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

  /// 添加预约（含星标熟客功能、时间重叠检测）
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
    bool starred = false; // 是否星标

    DateTime startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 10, 0);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                    // 技师选择
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
                    // 开始时间
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
                    // 持续时长
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
                    // 价格
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "价格"),
                    ),
                    const SizedBox(height: 8),
                    // 房间号
                    TextField(
                      controller: roomController,
                      decoration: const InputDecoration(labelText: "房间号"),
                    ),
                    const SizedBox(height: 8),
                    // 非现金支付
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
                    // 星标熟客（图标颜色为黄色）
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
                    // 检查同一技师是否已有重叠预约
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
      },
    );
  }

  /// 编辑预约（含删除预约功能、重叠检测、星标图标黄色显示）
  void _showEditAppointmentDialog(Appointment appt) {
    String selectedTherapistName = appt.therapistName;
    DateTime startTime = appt.start;
    Duration duration = appt.end.difference(appt.start);
    TextEditingController priceController = TextEditingController(text: appt.price.toString());
    TextEditingController roomController = TextEditingController(text: appt.roomNumber);
    bool isNonCash = appt.isNonCash;
    bool starred = appt.starred; // 星标

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                                    startTime.year,
                                    startTime.month,
                                    startTime.day,
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

            int minutes = duration.inMinutes;
            String durationOption;
            if (minutes == 30 || minutes == 45 || minutes == 60) {
              durationOption = "${minutes}分钟";
            } else {
              durationOption = "自定义";
            }
            TextEditingController customDurationController = TextEditingController(
              text: durationOption == "自定义" ? "$minutes" : "",
            );
            bool isCustomDuration = (durationOption == "自定义");

            return AlertDialog(
              title: const Text("编辑预约"),
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
                    // 开始时间
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
                    StatefulBuilder(
                      builder: (ctxSB, setStateSB) {
                        return Column(
                          children: [
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
                                setStateSB(() {
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
                          ],
                        );
                      },
                    ),
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
                    // 非现金支付
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
                    // 星标熟客：图标颜色为黄色
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
                // 删除预约按钮
                TextButton(
                  onPressed: () {
                    setState(() {
                      appointments.remove(appt);
                    });
                    _saveData();
                    Navigator.of(ctx).pop();
                  },
                  child: const Text("删除该预约", style: TextStyle(color: Colors.red)),
                ),
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
                      finalDuration = int.parse(durationOption.replaceAll("分钟", ""));
                    }
                    DateTime endTime = startTime.add(Duration(minutes: finalDuration));
                    if (endTime.isBefore(startTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("结束时间不能早于开始时间！")),
                      );
                      return;
                    }
                    // 检查重叠：排除当前预约
                    if (isOverlapping(selectedTherapistName, startTime, endTime, appt.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("该技师在此时间已有预约，请选择其它时间。")),
                      );
                      return;
                    }
                    setState(() {
                      appt.therapistName = selectedTherapistName;
                      appt.start = startTime;
                      appt.end = endTime;
                      appt.price = p;
                      appt.roomNumber = roomController.text;
                      appt.isNonCash = isNonCash;
                      appt.starred = starred;
                    });
                    _saveData();
                    Navigator.of(ctx).pop();
                  },
                  child: const Text("保存修改"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// “删除技师” -> 从当前日期起，不再显示该技师
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
                  therapist.deletedAt = selectedDate;
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

  /// 构建单行（某个技师）的排程
  Widget _buildRowForTherapist(Therapist therapist, Key key) {
    return Container(
      key: key,
      height: rowHeight,
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: _rowContent(therapist),
    );
  }

  /// row 的实际内容
  Widget _rowContent(Therapist therapist) {
    // 过滤出该技师在 selectedDate 的预约
    List<Appointment> dayAppointments = appointments.where((a) {
      return a.therapistName == therapist.name && isSameDay(a.start, selectedDate);
    }).toList();

    int totalMinutes = (endHour - startHour) * 60;
    double tableWidth = totalMinutes * minuteWidth;
    double personalRev = getPersonalRevenue(therapist.name, selectedDate);

    return Row(
      children: [
        // 左侧：技师姓名 + 当天营业额 + 点击可删除
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
        // 右侧：时间表网格 + 预约块
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
                  for (var appt in dayAppointments) _buildAppointmentBlock(appt),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 预约块
  Widget _buildAppointmentBlock(Appointment appt) {
    int totalMinutes = (endHour - startHour) * 60;
    int startMin = (appt.start.hour - startHour) * 60 + appt.start.minute;
    int endMin = (appt.end.hour - startHour) * 60 + appt.end.minute;
    startMin = startMin.clamp(0, totalMinutes);
    endMin = endMin.clamp(0, totalMinutes);

    double left = startMin * minuteWidth;
    double width = (endMin - startMin) * minuteWidth;
    if (width < 0) width = 0;

    // 修改颜色逻辑：如果价格<=0或房间号为空，则显示黄色（优先）；否则如果星标则红色，否则蓝色
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
        onTap: () {
          _showEditAppointmentDialog(appt);
        },
        child: Container(
          color: blockColor,
          alignment: Alignment.center,
          child: Text(
            txt,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            textAlign: TextAlign.center,
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

  @override
  Widget build(BuildContext context) {
    double dailyRev = getDailyRevenue(selectedDate);
    double nonCashRev = appointments
        .where((a) => isSameDay(a.start, selectedDate) && a.isNonCash)
        .fold(0.0, (prev, a) => prev + a.price);

    String dateString =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    // 过滤出要显示的技师：如果 deletedAt==null，则一直显示；否则只有当 selectedDate < deletedAt 时显示
    final visibleTherapists = therapists.where((th) {
      if (th.deletedAt == null) return true;
      return selectedDate.isBefore(_truncateToDate(th.deletedAt!));
    }).toList();

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

/// 背景画布：绘制每小时竖线和时间标签
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
      // 竖线
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);

      // 时间标签
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
