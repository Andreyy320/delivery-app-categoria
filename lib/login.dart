import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'orders_screen.dart';

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

    if (login.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите данные для входа')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .where('login', isEqualTo: login)
          .where('password', isEqualTo: password)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final categoryData = snapshot.docs.first.data();
        final categoryId = snapshot.docs.first.id;
        final categoryName = categoryData['name'] ?? 'Бизнес';

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrdersScreen(
              shopId: categoryId,
              shopName: categoryName,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неверный логин или пароль')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка доступа: $e')),
      );
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Универсальная иконка (Магазин/Бизнес)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, size: 64, color: Colors.blueGrey),
              ),
              const SizedBox(height: 32),
              const Text(
                'Панель управления',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Вход для партнеров сервиса',
                style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),

              // Поле Логин
              _inputField(
                controller: loginController,
                hint: 'Ваш логин',
                icon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 16),

              // Поле Пароль
              _inputField(
                controller: passwordController,
                hint: 'Пароль',
                icon: Icons.vpn_key_outlined,
                isPassword: true,
              ),
              const SizedBox(height: 32),

              // Кнопка Входа
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: loading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87, // Строгий черный цвет
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: loading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Войти в кабинет',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),

              // Нижняя надпись
              const Text(
                '© 2026 Delivery System',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6), // Мягкий серый фон
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.blueGrey[400], size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}