import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'orders_screen.dart'; // экран с заказами

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;

  void login() async {
    final login = loginController.text.trim();
    final password = passwordController.text.trim();

    if (login.isEmpty || password.isEmpty) return;

    setState(() => loading = true);

    try {
      // ищем ресторан в коллекции categories по login + password
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .where('login', isEqualTo: login)
          .where('password', isEqualTo: password)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final categoryData = snapshot.docs.first.data();
        final categoryId = snapshot.docs.first.id; // id документа категории
        final categoryName = categoryData['name'] ?? 'Unknown';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrdersScreen(
              shopId: categoryId,       // ID документа ресторана
              shopName: categoryName,   // Название ресторана
            ),
          ),
        );

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неверный логин или пароль')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход для ресторана')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: loginController,
              decoration: const InputDecoration(
                labelText: 'Логин',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: login,
              child: const Text('Войти'),
            ),
          ],
        ),
      ),
    );
  }
}
