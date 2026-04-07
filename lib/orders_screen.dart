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
    final usersStream =
    FirebaseFirestore.instance.collection('users').snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Заказы — $shopName'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderHistoryScreen(shopId: shopId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
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
                padding: const EdgeInsets.all(12),
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
                      if (orderSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox();
                      }

                      if (orderSnapshot.hasError) {
                        return Center(
                            child: Text('Ошибка: ${orderSnapshot.error}'));
                      }

                      final ordersDocs = orderSnapshot.data?.docs ?? [];
                      if (ordersDocs.isEmpty) return const SizedBox();

                      return Column(
                        children: ordersDocs.map((doc) {
                          final orderData =
                          doc.data() as Map<String, dynamic>;
                          final orderId = doc.id;

                          final createdAt =
                          orderData['createdAt'] as Timestamp?;
                          final dateString = createdAt != null
                              ? DateFormat('dd.MM.yyyy HH:mm')
                              .format(createdAt.toDate())
                              : '-';

                          final items =
                              orderData['items'] as List<dynamic>? ?? [];
                          final status = orderData['status'] ?? 'new';

                          final statusUpdatedAt =
                          orderData['statusUpdatedAt'] as Timestamp?;
                          final statusTimeString = statusUpdatedAt != null
                              ? DateFormat('dd.MM.yyyy HH:mm')
                              .format(statusUpdatedAt.toDate())
                              : '-';

                          final startedAt =
                          orderData['startedAt'] as Timestamp?;
                          final readyAt = orderData['readyAt'] as Timestamp?;
                          final canceledAt =
                          orderData['canceledAt'] as Timestamp?;

                          final startedTimeString = startedAt != null
                              ? DateFormat('dd.MM.yyyy HH:mm')
                              .format(startedAt.toDate())
                              : '-';
                          final readyTimeString = readyAt != null
                              ? DateFormat('dd.MM.yyyy HH:mm')
                              .format(readyAt.toDate())
                              : '-';
                          final canceledTimeString = canceledAt != null
                              ? DateFormat('dd.MM.yyyy HH:mm')
                              .format(canceledAt.toDate())
                              : '-';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              childrenPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              title: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    orderData['clientName'] ?? 'Клиент',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                    children: [
                                      _buildStatus(status, shopCategory),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Обновлено: $statusTimeString',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500]),
                                      ),
                                      if (startedAt != null)
                                        Text('Начало: $startedTimeString',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                      if (readyAt != null)
                                        Text('Готово: $readyTimeString',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                      if (canceledAt != null)
                                        Text('Отменен: $canceledTimeString',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                    ],
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Дата: $dateString\n'
                                      'Телефон: ${orderData['clientPhone'] ??
                                      '-'}\n'
                                      'Оплата: ${translatePaymentMethod(
                                      orderData['paymentMethod'] ?? '-')}\n'
                                      'Сумма: ${orderData['total'] ?? 0} ₽',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                              children: [
                                const Divider(),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Состав заказа:',
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...items.map((item) {
                                  final i = item as Map<String, dynamic>;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            i['name'] ?? '-',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Text(
                                            '${i['quantity']} x ${i['price']} ₽'),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 15),
                                Row(
                                  children: _buildButtons(
                                      shopCategory, ordersRef, orderId),
                                ),
                                const SizedBox(height: 10),
                              ],
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

  // Построение кнопок по категории магазина
  List<Widget> _buildButtons(String category, CollectionReference ordersRef,
      String orderId) {
    switch (category.toLowerCase()) {
      case 'restaurant':
        return [
          _button('Начать готовить', Colors.blue, () {
            ordersRef.doc(orderId).update({
              'status': 'preparing',
              'startedAt': FieldValue.serverTimestamp(),
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }),
          _button('Заказ готов', Colors.green, () {
            ordersRef.doc(orderId).update({
              'status': 'ready',
              'readyAt': FieldValue.serverTimestamp(),
              'statusUpdatedAt': FieldValue.serverTimestamp(),
            });
          }),
          _button('Отменить', Colors.red, () {
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
          _button('Собирается', Colors.blue, () {
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
          _button('Отменить', Colors.red, () {
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
            minimumSize: const Size(double.infinity, 45),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onPressed,
          child: Text(text),
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