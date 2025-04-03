import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:task_manager_app/homepage.dart';
import 'package:task_manager_app/login.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State <Wrapper> createState() =>  _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Homepage(); // ide illeszd be azt a widgetet, amit a bejelentkezett felhasználók látnak
          } else {
            return Login(); // ide illeszd be azt a widgetet, amit a kijelentkezett felhasználók látnak
          }
        }),
    );
  }
}