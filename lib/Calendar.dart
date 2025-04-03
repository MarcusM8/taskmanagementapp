import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final user = FirebaseAuth.instance.currentUser;
  String _selectedCategory = "Shared Tasks With Me";
  String _sortOrder = "A-Z";
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (user == null) return;

    tasks = _selectedCategory == "Shared Tasks With Me"
        ? await _fetchSharedTasks()
        : await _fetchCompletedTasks();

    _sortTasks();
  }

  Future<List<Map<String, dynamic>>> _fetchSharedTasks() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('categories')
          .doc('shared_tasks')
          .collection('tasks')
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['categoryName'] = "Shared Tasks";
        return data;
      }).toList();
    } catch (e) {
      print("Error loading shared tasks: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCompletedTasks() async {
    List<Map<String, dynamic>> completedTasks = [];
    try {
      final categories = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('categories')
          .get();

      for (var categoryDoc in categories.docs) {
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('categories')
            .doc(categoryDoc.id)
            .collection('tasks')
            .where('completed', isEqualTo: true)
            .get();

        completedTasks.addAll(tasksSnapshot.docs.map((taskDoc) {
          var data = taskDoc.data() as Map<String, dynamic>;
          data['id'] = taskDoc.id;
          data['categoryName'] = categoryDoc['name'] ?? "Unknown Category";
          return data;
        }));
      }
    } catch (e) {
      print("Error loading completed tasks: $e");
    }
    return completedTasks;
  }

  void _sortTasks() {
    tasks.sort((a, b) {
      String nameA = (a['name'] ?? "").toLowerCase();
      String nameB = (b['name'] ?? "").toLowerCase();
      return _sortOrder == "A-Z" ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });
    setState(() {});
  }

  Future<void> _deleteTask(String taskId, String categoryName) async {
    try {
      final collectionPath = categoryName == "Shared Tasks" ? "shared_tasks" : categoryName;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('categories')
          .doc(collectionPath)
          .collection('tasks')
          .doc(taskId)
          .delete();

      setState(() {
        tasks.removeWhere((task) => task['id'] == taskId);
      });
    } catch (e) {
      print("Error deleting task: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
                  Row(
                    children: [
                      _buildDropdown(_selectedCategory, ["Shared Tasks With Me", "Completed Tasks"], (value) {
                        setState(() {
                          _selectedCategory = value!;
                          _loadTasks();
                        });
                      }),
                      const SizedBox(width: 10),
                      _buildDropdown(_sortOrder, ["A-Z", "Z-A"], (value) {
                        setState(() {
                          _sortOrder = value!;
                          _sortTasks();
                        });
                      }),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(
                        child: Text("No tasks available",
                            style: TextStyle(color: Colors.white70, fontSize: 16)))
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildTaskCard(task);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    bool isCompleted = task['completed'] ?? false;
    String category = task['categoryName'] ?? "shared_tasks";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(45, 52, 60, 1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCompleted ? Colors.greenAccent : Colors.orangeAccent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(task['name'] ?? "Unnamed Task",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
                        color: isCompleted ? Colors.greenAccent : Colors.white)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteTask(task['id'], category),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text("Category: $category", style: const TextStyle(color: Colors.orangeAccent)),
            Text(isCompleted ? "Completed" : "In Progress",
                style: TextStyle(
                  color: isCompleted ? Colors.greenAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          dropdownColor: const Color.fromRGBO(45, 52, 60, 1),
          borderRadius: BorderRadius.circular(12),
          onChanged: onChanged,
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
        ),
      ),
    );
  }
}
