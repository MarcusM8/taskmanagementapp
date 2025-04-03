import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:task_manager_app/login.dart';
import 'package:task_manager_app/signup.dart';

class Starter extends StatefulWidget {
  const Starter({super.key});

  @override
  _StarterState createState() => _StarterState();
}

class _StarterState extends State<Starter> {
  double opacityLevel = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        opacityLevel = 1.0;
      });
    });
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // 🔹 Logó megjelenítése fekete szűrővel
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: MediaQuery.of(context).size.width,
                  ),
                ),

                const Spacer(),

                // 🔹 "Sign Up" gomb
                AnimatedOpacity(
                  opacity: opacityLevel,
                  duration: const Duration(seconds: 1),
                  child: ElevatedButton(
                    onPressed: () => Get.to(const Signup()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withOpacity(0.95),
                      shadowColor: Colors.black.withOpacity(0.4),
                      elevation: 8,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      minimumSize: Size(MediaQuery.of(context).size.width * 0.8, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 "Login" szöveg és gomb
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      TextButton(
                        onPressed: () => Get.to(const Login()),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
