import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Order_History_Screen.dart';
import 'login.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatelessWidget {
  final String shopId;
  final String shopName;

  const OrdersScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  // Перевод методов оплаты
  String translatePaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Наличные';
      case 'online':
        return 'Онлайн';
      default:
        return method;
    }
  }

  Future<String> _getShopCategory() async {
    final doc = await FirebaseFirestore.instance
        .collection('categories') // или 'shops', как у тебя называется
        .doc(shopId)
        .get();
    return doc.data()?['category']?.toString().trim().toLowerCase() ??
        'restaurant';
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC), // Более мягкий светлый фон
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text('Заказы — $shopName', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.blueGrey),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => OrderHistoryScreen(shopId: shopId)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<String>(
        future: _getShopCategory(),
        builder: (context, categorySnapshot) {
          if (!categorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final shopCategory = categorySnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: usersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}'));
              }

              final userDocs = snapshot.data?.docs ?? [];

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: userDocs.map((userDoc) {
                  final ordersRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(userDoc.id)
                      .collection('orders');

                  return StreamBuilder<QuerySnapshot>(
                    stream: ordersRef
                        .where('shopId', isEqualTo: shopId)
                        .where('status', whereIn: ['new', 'preparing'])
                        .snapshots(),
                    builder: (context, orderSnapshot) {
                      if (orderSnapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                      if (orderSnapshot.hasError) return Center(child: Text('Ошибка: ${orderSnapshot.error}'));

                      final ordersDocs = orderSnapshot.data?.docs ?? [];
                      if (ordersDocs.isEmpty) return const SizedBox();

                      return Column(
                        children: ordersDocs.map((doc) {
                          final orderData = doc.data() as Map<String, dynamic>;
                          final orderId = doc.id;

                          // Твои переменные времени
                          final createdAt = orderData['createdAt'] as Timestamp?;
                          final dateString = createdAt != null ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate()) : '-';
                          final items = orderData['items'] as List<dynamic>? ?? [];
                          final status = orderData['status'] ?? 'new';
                          final statusUpdatedAt = orderData['statusUpdatedAt'] as Timestamp?;
                          final statusTimeString = statusUpdatedAt != null ? DateFormat('HH:mm').format(statusUpdatedAt.toDate()) : '-';

                          final startedAt = orderData['startedAt'] as Timestamp?;
                          final readyAt = orderData['readyAt'] as Timestamp?;
                          final canceledAt = orderData['canceledAt'] as Timestamp?;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                childrenPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          orderData['clientName'] ?? 'Клиент',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('ID: ...${orderId.substring(orderId.length - 5)}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _buildStatus(status, shopCategory),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Обновлено: $statusTimeString',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Wrap(
                                    spacing: 15,
                                    runSpacing: 5,
                                    children: [
                                      _infoLabel(Icons.calendar_today, dateString),
                                      _infoLabel(Icons.phone, orderData['clientPhone'] ?? '-'),
                                      _infoLabel(Icons.payment, translatePaymentMethod(orderData['paymentMethod'] ?? '-')),
                                      _infoLabel(Icons.account_balance_wallet, '${orderData['total'] ?? 0} ₽', isBold: true),
                                    ],
                                  ),
                                ),
                                children: [
                                  const Divider(height: 1),
                                  const SizedBox(height: 16),
                                  // Блок с таймингами (Начало, Готово и т.д.)
                                  if (startedAt != null || readyAt != null || canceledAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          if (startedAt != null) _timeBadge('Начало', startedAt),
                                          if (readyAt != null) _timeBadge('Готово', readyAt),
                                          if (canceledAt != null) _timeBadge('Отмена', canceledAt),
                                        ],
                                      ),
                                    ),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('СОСТАВ ЗАКАЗА',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey, letterSpacing: 1.1)),
                                  ),
                                  const SizedBox(height: 12),
                                  ...items.map((item) {
                                    final i = item as Map<String, dynamic>;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                            child: Text('${i['quantity']}x', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(i['name'] ?? '-', style: const TextStyle(fontSize: 15))),
                                          Text('${i['price']} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  const SizedBox(height: 20),
                                  Row(children: _buildButtons(shopCategory, ordersRef, orderId)),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

// Вспомогательные мини-виджеты для чистоты кода
  Widget _infoLabel(IconData icon, String text, {bool isBold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(
            fontSize: 13,
            color: isBold ? Colors.indigo : Colors.grey[700],
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal
        )),
      ],
    );
  }

  Widget _timeBadge(String label, Timestamp ts) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(DateFormat('HH:mm').format(ts.toDate()), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  List<Widget> _buildButtons(String category, CollectionReference ordersRef, String orderId) {
    switch (category.toLowerCase()) {
      case 'restaurant':
        return [
          _button('Начать', Colors.blue, () {
            ordersRef.doc(orderId).update({
              'status': 'preparing',
              'startedAt': FieldValue.serverTimestamp(),
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }),
          _button('Готово', Colors.green, () {
            ordersRef.doc(orderId).update({
              'status': 'ready',
              'readyAt': FieldValue.serverTimestamp(),
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }),
          _button('Отмена', Colors.red, () {
            ordersRef.doc(orderId).update({
              'status': 'canceled',
              'canceledAt': FieldValue.serverTimestamp(),
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }),
        ];
      case 'svetok':
      case 'apteka':
      case 'product':
      case 'electronika':
        return [
          _button('Сборка', Colors.blue, () {
            ordersRef.doc(orderId).update({
              'status': 'preparing',
              'startedAt': FieldValue.serverTimestamp(),
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }),
          _button('Готов', Colors.green, () {
            ordersRef.doc(orderId).update({
              'status': 'ready',
              'readyAt': FieldValue.serverTimestamp(),
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }),
          _button('Отмена', Colors.red, () {
            ordersRef.doc(orderId).update({
              'status': 'canceled',
              'canceledAt': FieldValue.serverTimestamp(),
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }),
        ];
      default:
        return [
          _button('Отменить', Colors.red, () {
            ordersRef.doc(orderId).update({
              'status': 'canceled',
              'canceledAt': FieldValue.serverTimestamp(),
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }),
        ];
    }
  }

  Widget _button(String text, Color color, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0, // Плоский современный вид
            // Фиксируем высоту 44 пикселя — стандарт для удобного нажатия пальцем
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 2), // Минимум отступов по бокам
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10), // Скругление под стиль "Quiet Luxury"
            ),
          ),
          onPressed: onPressed,
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1, // Текст никогда не перепрыгнет на вторую строку
            overflow: TextOverflow.ellipsis, // Если не влезет — аккуратно обрежется
            style: const TextStyle(
              fontSize: 11, // Оптимальный размер для мобильного веба
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(String status, String category) {
    Color color;
    String text;

    switch (status) {
      case 'new':
        color = Colors.orange;
        text = 'Новый';
        break;

      case 'preparing':
        color = Colors.blue;
        // Светок и аптека одинаково
        text = (category.toLowerCase() == 'svetok' ||
            category.toLowerCase() == 'apteka' || category.toLowerCase() == 'product' ||
            category.toLowerCase() == 'electronika')
            ? 'Собирается'
            : 'Готовится';
        break;

      case 'ready':
        color = Colors.green;
        text = (category.toLowerCase() == 'svetok' ||
            category.toLowerCase() == 'apteka' || category.toLowerCase() == 'product' ||
            category.toLowerCase() == 'electronika')
            ? 'Отправлен'
            : 'Готов';
        break;

      case 'canceled':
        color = Colors.red;
        text = 'Отменен';
        break;

      default:
        color = Colors.orange;
        text = 'Новый';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}




