import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Order_History_Screen.dart';
import 'login.dart';
import 'package:intl/intl.dart';
import 'business_stop_list_screen.dart';

class OrdersScreen extends StatelessWidget {
  final String shopId;
  final String shopName;

  const OrdersScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  // --- ЛОГИКА СОХРАНЕНИЯ В ИСТОРИЮ ЗАВЕДЕНИЯ ---
  Future<void> _syncToShopHistory(String orderId, Map<String, dynamic> updateData) async {
    final shopHistoryRef = FirebaseFirestore.instance
        .collection('categories')
        .doc(shopId)
        .collection('ordersHistory')
        .doc(orderId);

    await shopHistoryRef.set({
      ...updateData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String translatePaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash': return 'Наличные';
      case 'online': return 'Онлайн';
      default: return method;
    }
  }

  Future<String> _getShopCategory() async {
    final doc = await FirebaseFirestore.instance
        .collection('categories')
        .doc(shopId)
        .get();
    return doc.data()?['category']?.toString().trim().toLowerCase() ?? 'restaurant';
  }

  // Виджет отображения инфо о курьере
  Widget _buildCourierInfo(Map<String, dynamic> orderData) {
    final String? courierId = orderData['courierId'];
    final String courierName = orderData['courierName'] ?? 'Курьер';
    final String courierPhone = orderData['courierPhone'] ?? '';

    if (courierId == null || courierId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _infoLabel(Icons.hail_rounded, 'Ожидание курьера...', customColor: Colors.grey),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _infoLabel(
          Icons.delivery_dining,
          'Курьер: $courierName ($courierPhone)',
          isBold: true,
          customColor: Colors.purple,
        ),
      ),
    );
  }

  void _showTimePicker(BuildContext context, CollectionReference ordersRef, String orderId, Map<String, dynamic> currentOrderData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('ЧЕРЕЗ СКОЛЬКО БУДЕТ ГОТОВО?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
            const SizedBox(height: 24),
            Row(
              children: [
                _timeChoice(context, '15 мин', 15, ordersRef, orderId, currentOrderData),
                _timeChoice(context, '30 мин', 30, ordersRef, orderId, currentOrderData),
                _timeChoice(context, '45 мин', 45, ordersRef, orderId, currentOrderData),
                _timeChoice(context, '60 мин', 60, ordersRef, orderId, currentOrderData),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _timeChoice(BuildContext context, String label, int mins, CollectionReference ordersRef, String orderId, Map<String, dynamic> currentOrderData) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final estimatedTime = now.add(Duration(minutes: mins));

          final updateData = {
            'status': 'preparing',
            'startedAt': FieldValue.serverTimestamp(),
            'statusUpdatedAt': FieldValue.serverTimestamp(),
            'estimatedReadyTime': Timestamp.fromDate(estimatedTime),
          };

          await ordersRef.doc(orderId).update(updateData);
          await _syncToShopHistory(orderId, {...currentOrderData, ...updateData});

          Navigator.pop(context);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu, color: Colors.deepOrangeAccent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessStopListScreen(shopId: shopId))),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.blueGrey),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderHistoryScreen(shopId: shopId))),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<String>(
        future: _getShopCategory(),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final shopCategory = categorySnapshot.data ?? 'restaurant';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collectionGroup('orders')
                .where('shopId', isEqualTo: shopId)
                .where('status', whereIn: ['new', 'preparing', 'accepted', 'ready'])
                .snapshots(),
            builder: (context, ordersSnapshot) {
              if (ordersSnapshot.hasError) {
                debugPrint('ОШИБКА FIRESTORE: ${ordersSnapshot.error}');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Ошибка получения данных. Проверьте терминал на наличие ссылки для создания индекса.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                );
              }

              if (ordersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allOrders = ordersSnapshot.data?.docs ?? [];

              if (allOrders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Активных заказов пока нет\nID: $shopId',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allOrders.length,
                itemBuilder: (context, index) {
                  final doc = allOrders[index];
                  final orderData = doc.data() as Map<String, dynamic>;
                  return _buildOrderTile(context, doc.id, orderData, shopCategory, doc.reference.parent);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderTile(BuildContext context, String orderId, Map<String, dynamic> orderData, String category, CollectionReference ordersRef) {
    final status = orderData['status'] ?? 'new';
    final items = orderData['items'] as List<dynamic>? ?? [];
    final String restaurantComment = orderData['restaurantComment'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)],
      ),
      child: ExpansionTile(
        title: Text(orderData['clientName'] ?? 'Клиент', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoLabel(Icons.account_balance_wallet, '${orderData['total'] ?? 0} Руб', isBold: true),
            _buildCourierInfo(orderData),
          ],
        ),
        trailing: _buildStatus(status, category),
        children: [
          const Divider(),
          // ДОБАВЛЕНО: Блок комментария от заведения
          if (restaurantComment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'КОММЕНТАРИЙ ОТ КЛИЕНТА:',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurantComment,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ...items.map((item) => ListTile(
            dense: true,
            title: Text(item['name']),
            leading: Text('${item['quantity']}x', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            trailing: Text('${item['price']} Руб'),
          )),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: _buildButtons(context, category, ordersRef, orderId, status, orderData),
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildButtons(BuildContext context, String category, CollectionReference ordersRef, String orderId, String status, Map<String, dynamic> currentOrderData) {
    String startText = (['svetok', 'apteka', 'product', 'electronika'].contains(category)) ? 'Сборка' : 'Начать';
    String readyText = (['svetok', 'apteka', 'product', 'electronika'].contains(category)) ? 'Отправлен' : 'Готово';

    return [
      if (status == 'new')
        _button(startText, Colors.blue, () => _showTimePicker(context, ordersRef, orderId, currentOrderData)),

      if (status == 'preparing' || status == 'accepted')
        _button(readyText, Colors.green, () async {
          final updateData = {
            'status': 'ready',
            'readyAt': FieldValue.serverTimestamp(),
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          };
          await ordersRef.doc(orderId).update(updateData);
          await _syncToShopHistory(orderId, {...currentOrderData, ...updateData});
        }),

      _button('Отмена', Colors.red, () async {
        final updateData = {
          'status': 'canceled',
          'canceledAt': FieldValue.serverTimestamp(),
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        };
        await ordersRef.doc(orderId).update(updateData);
        await _syncToShopHistory(orderId, {...currentOrderData, ...updateData});
      }),
    ];
  }

  Widget _button(String text, Color color, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onPressed,
          child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _infoLabel(IconData icon, String text, {bool isBold = false, Color? customColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: customColor ?? Colors.grey[400]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: customColor ?? (isBold ? Colors.deepOrange : Colors.grey[700]), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildStatus(String status, String category) {
    Color color;
    String text;
    bool isShop = ['svetok', 'apteka', 'product', 'electronika'].contains(category.toLowerCase());
    switch (status) {
      case 'new': color = Colors.orange; text = 'Новый'; break;
      case 'preparing': color = Colors.blue; text = isShop ? 'Сборка' : 'Готовится'; break;
      case 'accepted': color = Colors.purple; text = 'Принят'; break;
      case 'ready': color = Colors.teal; text = isShop ? 'Готов' : 'Готов'; break;
      case 'canceled': color = Colors.red; text = 'Отменен'; break;
      default: color = Colors.grey; text = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
