import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:task_manager_app/starter.dart';
import 'package:intl/intl.dart';
import 'calendar.dart';
import 'task_reminder_popup.dart';


class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => HomepageState();
}

void main() => runApp(MaterialApp(
      home: Homepage(),
    ));

class HomepageState extends State<Homepage> {
  final user = FirebaseAuth.instance.currentUser;
  String greeting = '';
  String _selectedFilter = 'A-Z';
  List<Map<String, dynamic>> categories = [];
  final GoogleSignIn googleSignIn = GoogleSignIn();
  String? selectedCategoryId;
  String? selectedCategoryName;
  List<Map<String, dynamic>> tasks = [];
  DateTime dueDate = Timestamp.now().toDate(); // 🔥 Firestore Timestamp → DateTime

  @override
  @override
void initState() {
  super.initState();
  _setGreetingMessage();
  _loadCategories();

  // 🔹 Késleltetve meghívjuk a popup ablakot bejelentkezéskor
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showTaskReminderPopup(context);
  });
}

// 🔹 Popup megjelenítése
void _showTaskReminderPopup(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return TaskReminderPopup(userId: FirebaseAuth.instance.currentUser!.uid);
    },
  );
}

void _showTaskReminderPopupButton() {
  showDialog(
    context: context, // Itt a `context` a StatefulWidget miatt már elérhető
    builder: (BuildContext context) {
      return TaskReminderPopup(userId: FirebaseAuth.instance.currentUser!.uid);
    },
  );
}




  void _sortTasks() {
  setState(() {
    if (_selectedFilter == 'A-Z') {
      tasks.sort((a, b) => a['name'].compareTo(b['name']));
    } else if (_selectedFilter == 'Z-A') {
      tasks.sort((a, b) => b['name'].compareTo(a['name']));
    } else if (_selectedFilter == 'Due Date (Earliest First)') {
      tasks.sort((a, b) => 
        (a['dueDate'] as DateTime).compareTo(b['dueDate'] as DateTime));
    } else if (_selectedFilter == 'Due Date (Latest First)') {
      tasks.sort((a, b) => 
        (b['dueDate'] as DateTime).compareTo(a['dueDate'] as DateTime));
    }
  });
}


  // 🔹 Navigációs sáv gombjainak építésére szolgáló segédfüggvény
Widget _buildNavItem(IconData icon, String label, bool isSelected, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.greenAccent.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.greenAccent : Colors.white70,
            size: isSelected ? 28 : 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.greenAccent : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}


  void _setGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'Good Morning!';
    } else if (hour < 18) {
      greeting = 'Good Afternoon!';
    } else {
      greeting = 'Good Evening!';
    }
  }

  void _loadCategories() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .get()
          .then((snapshot) {
        if (mounted) {
          setState(() {
            categories = snapshot.docs.map((doc) {
              return {
                'id': doc.id,
                'name': doc['name'],
                'color': Color(doc['color']),
              };
            }).toList();
          });
        }
      }).catchError((error) {
        debugPrint("Error loading categories: $error");
      });
    }
  }

  void _loadTasks(String? categoryId) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && categoryId != null) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .doc(categoryId)
        .collection('tasks')
        .where('completed', isEqualTo: false)
        .get()
        .then((snapshot) {
      if (mounted) {
        setState(() {
          tasks = snapshot.docs.map((doc) {
            final dueDateRaw = doc['dueDate']; // Eredeti érték

            return {
              'id': doc.id,
              'name': doc['name'],
              'description': doc['description'],
              'dueDate': dueDateRaw is Timestamp 
                  ? dueDateRaw.toDate() // 🔥 Ha Timestamp, alakítjuk DateTime-má
                  : (dueDateRaw is String 
                      ? DateTime.tryParse(dueDateRaw) // 🔥 Ha String, akkor próbáljuk konvertálni
                      : null), // 🔥 Ha egyik sem, akkor `null`
              'completed': doc['completed'],
            };
          }).toList();
        });
      }
    }).catchError((error) {
      debugPrint("Error loading tasks: $error");
    });
  }
}



  void _addCategory(String name, Color color) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .add({
      'name': name,
      'color': color.value,
    }).then((value) {
      setState(() {
        categories.add({
          'id': value.id,
          'name': name,
          'color': color,
        });
      });

      // Testreszabott SnackBar a sikeres hozzáadáshoz
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Category added successfully!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(
                Icons.check_circle,
                color: Colors.greenAccent,
                size: 24,
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2C2C34), // Sötét háttérszín
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Lekerekített sarkok
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          duration: const Duration(seconds: 2), // Megjelenési idő
        ),
      );

      debugPrint("Category added successfully!");
      }).catchError((error) {
        // Hibakezelés SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Failed to add category.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(
                  Icons.error,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2C2C34), // Egységes háttérszín
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Modern dizájn
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            duration: const Duration(seconds: 2), // Időtartam
          ),
        );
        debugPrint("Error adding category: $error");
      });
      }
      }


  void _deleteCategory(String categoryId) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFF2C2C34), // Sötét háttérszín
        title: const Text(
          "Delete Category",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Are you sure you want to delete this category? This action cannot be undone.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          // 🔹 Mégse gomb
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Ablak bezárása
            },
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
            ),
          ),

          // 🔹 Törlés gomb
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Ablak bezárása

              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  // Firestore-ból törlés
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('categories')
                      .doc(categoryId)
                      .delete();

                  // Helyi lista frissítése
                  setState(() {
                    categories.removeWhere((category) => category['id'] == categoryId);
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Category deleted successfully!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(
                            Icons.check_circle,
                            color: Colors.greenAccent,
                            size: 24,
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF2C2C34),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      duration: const Duration(seconds: 2),
                    ),
                  );

                  debugPrint("Category deleted successfully!");
                } catch (error) {
                  debugPrint("Error deleting category: $error");

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Failed to delete category.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(
                            Icons.error,
                            color: Colors.redAccent,
                            size: 24,
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF2C2C34),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}


  void _showSnackBar(String message, IconData icon, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Icon(icon, color: color, size: 24),
        ],
      ),
      backgroundColor: const Color(0xFF2C2C34),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      duration: const Duration(seconds: 3),
    ),
  );
}


 void _showAddCategoryDialog() {
  String categoryName = '';

  showDialog(
  context: context,
  builder: (context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color.fromRGBO(35, 40, 42, 1), // 🔹 Sötét háttér
          title: const Text(
            "Add Category",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔹 Kategória név beviteli mező
              TextField(
                onChanged: (value) {
                  categoryName = value;
                },
                decoration: InputDecoration(
                  labelText: "Category Name",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2), // 🔹 Sötétebb háttér
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            // 🔹 Cancel gomb
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),

            // 🔹 Kategória hozzáadása gomb
            ElevatedButton(
              onPressed: () {
                if (categoryName.isNotEmpty) {
                  _addCategory(categoryName, Colors.greenAccent); // 🔹 Most már 2 argumentumot adunk át!
                  Navigator.of(context).pop();
                } else {
                  _showSnackBar("Category name cannot be empty!", Icons.error, Colors.redAccent);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.withOpacity(0.9), // 🔹 Szép zöld gomb
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "Add",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  },
);
}


  void _addTask(String name, String description, String categoryId, DateTime dueDate) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .doc(categoryId)
        .collection('tasks')
        .add({
      'name': name,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate), // 🔥 DateTime → Firestore Timestamp
      'completed': false,
    }).then((_) {
      debugPrint("Task added successfully!");
      if (selectedCategoryId == categoryId) {
        _loadTasks(categoryId);
      }
    }).catchError((error) {
      debugPrint("Error adding task: $error");
    });
  }
}


  void _updateTask(String taskId, String newName, String newDescription, DateTime? newDueDate) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && selectedCategoryId != null) {
    FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("categories")
        .doc(selectedCategoryId)
        .collection("tasks")
        .doc(taskId)
        .update({
      "name": newName,
      "description": newDescription,
      "dueDate": newDueDate != null ? Timestamp.fromDate(newDueDate) : null, // 🔥 DateTime → Timestamp
    }).then((_) {
      debugPrint("Task updated!");
      _loadTasks(selectedCategoryId!);
    }).catchError((error) {
      debugPrint("Failed to update task: $error");
    });
  }
}


  void _deleteTask(String taskId) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && selectedCategoryId != null) {
    FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("categories")
        .doc(selectedCategoryId)
        .collection("tasks")
        .doc(taskId)
        .delete()
        .then((_) {
          debugPrint("Task deleted!");
          _loadTasks(selectedCategoryId!);
        }).catchError((error) {
          debugPrint("Failed to delete task: $error");
        });
  }
}


  void _showEditTaskDialog(String taskId, String currentName, String currentDescription, dynamic currentDueDate) {
  TextEditingController nameController = TextEditingController(text: currentName);
  TextEditingController descriptionController = TextEditingController(text: currentDescription);

  // 🔹 Dátum konvertálása (Firestore Timestamp vagy String esetén is működik)
  DateTime? selectedDueDate;
  if (currentDueDate is Timestamp) {
    selectedDueDate = currentDueDate.toDate();
  } else if (currentDueDate is String) {
    selectedDueDate = DateTime.tryParse(currentDueDate);
  }

  showDialog(
  context: context,
  builder: (context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF2C2C34), // 🔹 Sötétebb háttér, hogy jobban illeszkedjen
          title: const Text(
            "Edit Task",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔹 Feladat neve szerkesztés
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Task Name",
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 10),

                // 🔹 Feladat leírás szerkesztés
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: "Task Description",
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 15),

                // 🔹 Határidő szerkesztés (dátum + idő választás)
                ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.greenAccent,
                              onPrimary: Colors.black,
                              surface: Color(0xFF2C2C34),
                              onSurface: Colors.white70,
                            ),
                            dialogBackgroundColor: const Color(0xFF2C2C34),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDueDate ?? DateTime.now()),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.greenAccent,
                                onPrimary: Colors.black,
                                surface: Color(0xFF2C2C34),
                                onSurface: Colors.white70,
                              ),
                              dialogBackgroundColor: const Color(0xFF2C2C34),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedTime != null) {
                        setState(() {
                          selectedDueDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    selectedDueDate == null
                        ? "Select Due Date & Time"
                        : "Due: ${DateFormat('yyyy-MM-dd HH:mm').format(selectedDueDate!)}",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // 🔹 Törlés gomb
            TextButton(
              onPressed: () {
                _deleteTask(taskId);
                Navigator.of(context).pop();
                _showSnackBar("Task has been deleted", Icons.delete_forever, Colors.redAccent);
              },
              child: const Text(
                "Delete Task",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),

            // 🔹 Mégse gomb
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),

            // 🔹 Mentés gomb
            ElevatedButton(
              onPressed: () {
                _updateTask(taskId, nameController.text, descriptionController.text, selectedDueDate);
                Navigator.pop(context);
                _showSnackBar("Editing has been completed", Icons.check_circle, Colors.greenAccent);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "Save",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  },
);
}


  void _showSendTaskDialog() {
  String taskName = '';
  String taskDescription = '';
  String recipientEmail = '';
  DateTime? selectedDueDate;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: const Color.fromRGBO(35, 40, 42, 1), // Az előző dizájn háttérszíne
            title: const Text(
              "Send Task",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 Task név
                  TextField(
                    onChanged: (value) => taskName = value,
                    decoration: InputDecoration(
                      labelText: "Task Name",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 15),

                  // 🔹 Task leírás
                  TextField(
                    onChanged: (value) => taskDescription = value,
                    decoration: InputDecoration(
                      labelText: "Task Description",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 15),

                  // 🔹 Címzett email
                  TextField(
                    onChanged: (value) => recipientEmail = value,
                    decoration: InputDecoration(
                      labelText: "Recipient Email",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 15),

                  // 🔹 Dátumválasztó
                  ElevatedButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.greenAccent, // Kiválasztott dátum színe
                                onPrimary: Colors.black, // Kiválasztott dátum szövegszíne
                                surface: Color.fromRGBO(35, 40, 42, 1), // Háttérszín
                                onSurface: Colors.white70, // Szövegek színe
                              ),
                              dialogBackgroundColor: const Color.fromRGBO(35, 40, 42, 1),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.greenAccent, // OK és Cancel gombok színe
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                primaryColor: Colors.greenAccent,
                                hintColor: Colors.greenAccent,
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.greenAccent, // Kiválasztott idő színe
                                  onPrimary: Colors.black, // AM/PM gombok színe
                                  surface: Color.fromRGBO(35, 40, 42, 1), // Háttérszín
                                  onSurface: Colors.white70, // Szövegek színe
                                ),
                                dialogBackgroundColor: const Color.fromRGBO(35, 40, 42, 1),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.greenAccent, // OK és Cancel gombok színe
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedTime != null) {
                          setState(() {
                            selectedDueDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withOpacity(0.9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      selectedDueDate == null
                          ? "Select Due Date"
                          : "Due: ${DateFormat('yyyy-MM-dd HH:mm').format(selectedDueDate!)}",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // 🔹 Cancel gomb
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),

              // 🔹 Task küldése gomb
              ElevatedButton(
                onPressed: () {
                  if (taskName.isNotEmpty &&
                      taskDescription.isNotEmpty &&
                      recipientEmail.isNotEmpty &&
                      selectedDueDate != null) {
                    _sendTask(taskName, taskDescription, recipientEmail, selectedDueDate!);
                    Navigator.pop(context);
                    _showSnackBar("Task sent successfully!", Icons.check_circle, Colors.greenAccent);
                  } else {
                    _showSnackBar("All fields must be filled!", Icons.error_outline, Colors.redAccent);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Send Task",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _sendTask(String taskName, String taskDescription, String recipientEmail, DateTime dueDate) async {
  try {
    // 🔹 Keresés Firestore-ban az email alapján
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: recipientEmail.toLowerCase()) // Kisbetűs összehasonlítás
        .get();

    if (userQuery.docs.isEmpty) {
      debugPrint("No user found with email $recipientEmail");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "No user found with email $recipientEmail",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 24,
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2C2C34),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 🔹 Célfelhasználó UID lekérdezése
    final recipientUID = userQuery.docs.first.id;

    // 🔹 Ellenőrizzük, hogy van-e "Shared Tasks" kategória
    final sharedCategoryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(recipientUID)
        .collection('categories')
        .doc('shared_tasks');

    final sharedCategorySnapshot = await sharedCategoryRef.get();

    if (!sharedCategorySnapshot.exists) {
      // 🔹 Ha nincs "Shared Tasks" kategória, létrehozzuk
      await sharedCategoryRef.set({
        'name': 'Shared Tasks',
        'color': Colors.orange.value, // Alapértelmezett szín
      });
    }

    // 🔹 Új task hozzáadása a "Shared Tasks" kategóriához a határidővel együtt
    await sharedCategoryRef.collection('tasks').add({
      'name': taskName,
      'description': taskDescription,
      'dueDate': Timestamp.fromDate(dueDate), // 🔹 Dátum Firestore Timestamp-ként mentve
      'completed': false,
    });

    debugPrint("Task sent successfully to $recipientEmail");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Task sent successfully to $recipientEmail",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
              size: 24,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C2C34),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (error) {
    debugPrint("Error sending task: $error");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Failed to send task",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 24,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C2C34),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


  void _showAddTaskDialog() {
  String taskName = '';
  String taskDescription = '';
  DateTime? selectedDate;
  String? selectedCategoryForTask;

  showDialog(
  context: context,
  builder: (context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color.fromRGBO(35, 40, 42, 1),
          title: const Text(
            "Add Task",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Task név
                TextField(
                  onChanged: (value) {
                    taskName = value;
                  },
                  decoration: InputDecoration(
                    labelText: "Task Name",
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 15),

                // 🔹 Task leírás
                TextField(
                  onChanged: (value) {
                    taskDescription = value;
                  },
                  decoration: InputDecoration(
                    labelText: "Task Description",
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 15),

                // 🔹 Kategória kiválasztó
                DropdownButtonFormField<String>(
                  value: selectedCategoryForTask,
                  items: categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['id'],
                      child: Text(
                        category['name'],
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategoryForTask = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Select Category",
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: const Color.fromRGBO(35, 40, 42, 1),
                ),
                const SizedBox(height: 15),

                // 🔹 Dátumválasztó
                ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.greenAccent, // Fő szín (pl. kiválasztott dátum)
                                onPrimary: Colors.black, // Kiválasztott dátum szövegszíne
                                surface: Color.fromRGBO(35, 40, 42, 1), // Háttérszín
                                onSurface: Colors.white70, // Szövegek színe
                              ),
                              dialogBackgroundColor: const Color.fromRGBO(35, 40, 42, 1), // Teljes háttér sötétítése
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.greenAccent, // Gombok színe (OK, Cancel)
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );


                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                primaryColor: Colors.greenAccent,
                                hintColor: Colors.greenAccent,
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.greenAccent, // Kiválasztott idő színe
                                  onPrimary: Colors.black, // AM/PM gombok színe
                                  surface: Color.fromRGBO(35, 40, 42, 1), // Háttérszín
                                  onSurface: Colors.white70, // Szövegek színe
                                ),
                                dialogBackgroundColor: const Color.fromRGBO(35, 40, 42, 1),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.greenAccent, // OK és Cancel gombok színe
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );


                      if (pickedTime != null) {
                        setState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    selectedDate == null
                        ? "Select Due Date"
                        : "Due: ${selectedDate!.toLocal()}",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // 🔹 Cancel gomb
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),

            // 🔹 Task hozzáadása gomb
            ElevatedButton(
              onPressed: () {
                if (taskName.isNotEmpty &&
                    taskDescription.isNotEmpty &&
                    selectedDate != null &&
                    selectedCategoryForTask != null) {
                  _addTask(
                    taskName,
                    taskDescription,
                    selectedCategoryForTask!,
                    selectedDate!,
                  );
                  Navigator.of(context).pop();
                  _showSnackBar("Task added successfully!", Icons.check_circle, Colors.greenAccent);
                } else {
                  _showSnackBar("All fields must be filled!", Icons.error_outline, Colors.redAccent);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "Add Task",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  },
);

}
  
  @override
  Widget build(BuildContext context) {
  String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());



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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Extra térköz a tetején, hogy szellősebb legyen
            const SizedBox(height: 20),

            // 🔹 Köszöntő üzenet és dátum modernizált dizájnnal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 26, // Nagyobb betűméret a hangsúly miatt
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6), // Kis térköz a dátum előtt
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            todayDate,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (await googleSignIn.isSignedIn()) {
                      await googleSignIn.signOut();
                    }
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const Starter()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🔹 Modernizált "Categories" cím
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // 🔹 Modernizált "+ Add Category" gomb
                ElevatedButton(
                  onPressed: _showAddCategoryDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(105, 240, 174, 1).withOpacity(0.6), // Modern sötétebb tónus
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30), // Finomabb kerekítés
                    ),
                    elevation: 8, // Erősebb lebegő hatás
                    shadowColor: Colors.black.withOpacity(0.3), // Lágyabb árnyék
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2), // Finom háttér a plusz ikon mögött
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Add Category',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.1, // Modern betűköz
                        ),
                      ),
                    ],
                  ),
                ),

              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = selectedCategoryId == category['id'];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategoryId = category['id'];
                        selectedCategoryName = category['name'];
                        _loadTasks(selectedCategoryId);
                      });
                    },
                    child: Stack(
                      children: [
                        // 🔹 Modernizált kategóriakártya
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: isSelected ? 220 : 200,
                          height: isSelected ? 130 : 120,
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color.fromRGBO(105, 240, 174, 0.6) 
                                : const Color.fromRGBO(90, 102, 117, 1), // Világosabb árnyalat
                            borderRadius: BorderRadius.circular(18),
                            border: isSelected
                                ? Border.all(
                                    color: Colors.white.withOpacity(0.8),
                                    width: 2.5, // Vastagabb kiemelés
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: isSelected ? 25 : 12,
                                offset: const Offset(0, 8), // Lebegő hatás
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  category['name'].toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: isSelected ? 20 : 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2, // Modern betűköz
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: 30,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 🔹 Modern törlés gomb lebegő hatással
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              _deleteCategory(category['id']);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.8),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

// 🔹 Új cím a feladatokhoz, közvetlenül a kategóriák alá
            Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // 🔹 "Tasks" cím
    Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Tasks',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
    ),



    // 🔹 Szűrő dropdown (Filter)
    Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          icon: const Icon(Icons.filter_list, color: Colors.white),
          dropdownColor: const Color.fromRGBO(45, 52, 60, 1), // Sötét háttér
          borderRadius: BorderRadius.circular(12),
          onChanged: (String? newValue) {
            setState(() {
              _selectedFilter = newValue!;
              _sortTasks();
            });
          },
          items: <String>[
            'A-Z',
            'Z-A',
            'Due Date (Earliest First)',
            'Due Date (Latest First)',
          ].map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  ],
),


            const SizedBox(height: 5),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(), // Simább görgetés Androidon és iOS-en
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Dismissible(
                      key: Key(task['id'].toString()),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null && selectedCategoryId != null) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('categories')
                                .doc(selectedCategoryId)
                                .collection('tasks')
                                .doc(task['id'])
                                .update({'completed': true});

                            setState(() {
                              tasks.removeAt(index);
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "${task['name']} marked as completed!",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                      size: 24,
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF2C2C34),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } catch (error) {
                            debugPrint("Error updating task: $error");
                          }
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              "Mark as Completed",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.greenAccent,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(45, 52, 60, 1), // Modern sötétszürke
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: task['completed'] ? Colors.greenAccent : Colors.white24,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(3, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🔹 Feladat neve és szerkesztés ikon
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    task['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: task['completed']
                                          ? Colors.greenAccent
                                          : Colors.white,
                                      decoration: task['completed']
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                    onTap: () {
                                      debugPrint("Edit button pressed for task: ${task['name']}");

                                      dynamic dueDate = task['dueDate'];
                                      DateTime? parsedDueDate;

                                      if (dueDate is Timestamp) {
                                        parsedDueDate = dueDate.toDate(); // 🔹 Firestore Timestamp -> DateTime
                                      } else if (dueDate is String) {
                                        parsedDueDate = DateTime.tryParse(dueDate);
                                      } else if (dueDate is DateTime) {
                                        parsedDueDate = dueDate;
                                      } else {
                                        parsedDueDate = null; // 🔹 Ha semmi nem működik, legyen null
                                      }

                                      if (mounted) {
                                        _showEditTaskDialog(
                                          task['id'],
                                          task['name'],
                                          task['description'],
                                          parsedDueDate, // 🔹 Most már DateTime formátumot küldünk
                                        );
                                      } else {
                                        debugPrint("Widget is unmounted, cannot open dialog.");
                                      }
                                    },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // 🔹 Leírás
                            Text(
                              task['description'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),

                            // 🔹 Határidő és "Swipe to Complete" egyetlen sorban
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 🔹 Határidő kijelzése
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                        "Due: ${task['dueDate'] != null 
                                        ? DateFormat('yyyy-MM-dd HH:mm').format(task['dueDate'] as DateTime) // 🔥 Biztosítjuk, hogy DateTime marad
                                        : 'No due date'}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                // 🔹 Swipe to Complete igazítása
                                Row(
                                  mainAxisSize: MainAxisSize.min, // Ne foglaljon több helyet a szükségesnél
                                  children: [
                                    Text(
                                      "Swipe to Complete",
                                      style: TextStyle(
                                        color: Colors.greenAccent.withOpacity(0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      
      
      floatingActionButton: Stack(
  alignment: Alignment.bottomCenter,
  children: [
    // 🔹 Bal alsó sarokban lévő gomb (Feladat emlékeztető popup)
    Positioned(
      left: 20, // Távolság a bal oldaltól
      bottom: 85, // Távolság a bottomNavigationBartól
      child: FloatingActionButton(
        onPressed: () => _showTaskReminderPopup(context),
        backgroundColor: Colors.greenAccent.withOpacity(0.95),
        elevation: 6,
        shape: const CircleBorder(), // Kerekebb forma
        child: const Icon(
          Icons.timer, // ⏳ Időzítő ikon
          size: 34, // Nagyobb ikonméret
          color: Colors.black87,
        ),
      ),
    ),

    // 🔹 Jobb alsó sarokban lévő gomb (Feladat hozzáadása)
    Positioned(
      right: 20, // Távolság a jobb oldaltól
      bottom: 85, // Távolság a bottomNavigationBartól
      child: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        backgroundColor: Colors.greenAccent.withOpacity(0.95),
        elevation: 6,
        shape: const CircleBorder(), // Kerekebb forma
        child: const Icon(
          Icons.add,
          size: 34, // Nagyobb ikonméret
          color: Colors.black87,
        ),
      ),
    ),
  ],
),

floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // Az alsó navbar felett tartja a gombokat

bottomNavigationBar: Container(
  decoration: BoxDecoration(
    color: Colors.black.withOpacity(0.85), // Háttérszín
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(25),
      topRight: Radius.circular(25),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, -2),
      ),
    ],
  ),
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildNavItem(Icons.home, "Home", selectedCategoryId == null, () {
          setState(() {
            selectedCategoryId = null;
            selectedCategoryName = null;
            tasks.clear();
          });
        }),
        _buildNavItem(Icons.send, "Send", false, () {
          _showSendTaskDialog();
        }),
        _buildNavItem(Icons.calendar_today, "Tasks", false, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CalendarPage()),
          );
        }),
      ],
    ),
  ),
),
    ),
  );
}
}