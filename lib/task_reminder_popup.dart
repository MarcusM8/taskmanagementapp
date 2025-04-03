import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TaskReminderPopup extends StatefulWidget {
  final String userId;

  const TaskReminderPopup({Key? key, required this.userId}) : super(key: key);

  @override
  _TaskReminderPopupState createState() => _TaskReminderPopupState();
}

class _TaskReminderPopupState extends State<TaskReminderPopup> {
  List<Map<String, dynamic>> tasks = [];
  int currentTaskIndex = 0;
  Timer? _timer;
  Duration timeLeft = Duration.zero;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    DateTime now = DateTime.now();
    List<Map<String, dynamic>> fetchedTasks = [];

    var categoriesSnapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.userId)
        .collection("categories")
        .get();

    for (var categoryDoc in categoriesSnapshot.docs) {
      var tasksSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .collection("categories")
          .doc(categoryDoc.id)
          .collection("tasks")
          .get();

      for (var taskDoc in tasksSnapshot.docs) {
        var taskData = taskDoc.data();
        if (taskData['dueDate'] == null || taskData['name'] == null) continue;

        if (taskData.containsKey('completed') && taskData['completed'] == true) {
          continue;
        }

        DateTime dueDate;
        if (taskData['dueDate'] is Timestamp) {
          dueDate = (taskData['dueDate'] as Timestamp).toDate();
        } else {
          dueDate = DateTime.parse(taskData['dueDate']);
        }

        if (dueDate.isAfter(now) && dueDate.difference(now).inHours <= 24) {
          fetchedTasks.add({
            "name": taskData['name'],
            "dueDate": dueDate,
          });
        }
        
        if (dueDate.isBefore(now)) {
          fetchedTasks.add({
            "name": taskData['name'],
            "dueDate": dueDate,
            "overdue": true,
          });
        }
      }
    }

    setState(() {
      tasks = fetchedTasks;
      currentTaskIndex = 0; // 🔥 Mindig az első feladattal kezdi újra.
      isLoading = false;

      if (tasks.isNotEmpty) {
        _startTimer();
      }
    });
  }

  void _startTimer() {
    if (tasks.isEmpty) return;

    _updateTimeLeft();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _updateTimeLeft();
      });
    });
  }

  void _updateTimeLeft() {
    if (tasks.isEmpty) return;
    DateTime now = DateTime.now();
    DateTime dueDate = tasks[currentTaskIndex]["dueDate"];
    timeLeft = dueDate.difference(now);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const SizedBox.shrink();

    // 🔥 Ha nincs feladat, akkor üzenet jelenik meg
    if (tasks.isEmpty) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(25, 28, 30, 1),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Text(
            "No upcoming tasks available.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    bool isOverdue = tasks[currentTaskIndex].containsKey("overdue");

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(25, 28, 30, 1),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Upcoming Task",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tasks[currentTaskIndex]["name"],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Deadline: ${DateFormat('yyyy-MM-dd HH:mm').format(tasks[currentTaskIndex]["dueDate"])}",
              style: TextStyle(
                fontSize: 16,
                color: isOverdue ? Colors.red : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.greenAccent, Colors.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                isOverdue
                    ? "This task is overdue!"
                    : "${timeLeft.inHours}h ${timeLeft.inMinutes.remainder(60)}m ${timeLeft.inSeconds.remainder(60)}s",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isOverdue ? Colors.red : Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: currentTaskIndex > 0
                      ? () {
                          setState(() {
                            currentTaskIndex--;
                            _updateTimeLeft();
                          });
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white70),
                  onPressed: currentTaskIndex < tasks.length - 1
                      ? () {
                          setState(() {
                            currentTaskIndex++;
                            _updateTimeLeft();
                          });
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
