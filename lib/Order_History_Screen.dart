import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'order_tile.dart';

class OrderHistoryScreen extends StatefulWidget {
  final String shopId;

  const OrderHistoryScreen({super.key, required this.shopId});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    // Чистый поток пользователей
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC), // Светлый, профессиональный фон
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('История заказов',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Фильтр в виде аккуратного выпадающего меню
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedStatus,
                  isExpanded: true,
                  icon: const Icon(Icons.filter_list_rounded),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Все завершенные')),
                    DropdownMenuItem(value: 'delivered', child: Text('Доставленные')),
                    DropdownMenuItem(value: 'ready', child: Text('Готовы к выдаче')),
                    DropdownMenuItem(value: 'canceled', child: Text('Отмененные')),
                  ],
                  onChanged: (value) => setState(() => selectedStatus = value!),
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));

                final userDocs = snapshot.data?.docs ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: userDocs.length,
                  itemBuilder: (context, index) {
                    final userDoc = userDocs[index];

                    // Формируем запрос
                    var query = FirebaseFirestore.instance
                        .collection('users')
                        .doc(userDoc.id)
                        .collection('orders')
                        .where('shopId', isEqualTo: widget.shopId.trim());

                    if (selectedStatus != 'all') {
                      query = query.where('status', isEqualTo: selectedStatus);
                    } else {
                      // Теперь мы видим ВСЕ завершенные этапы
                      query = query.where('status', whereIn: ['ready', 'delivered', 'canceled', 'accepted']);
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: query.snapshots(),
                      builder: (context, orderSnapshot) {
                        if (!orderSnapshot.hasData) return const SizedBox();
                        final orders = orderSnapshot.data!.docs;
                        if (orders.isEmpty) return const SizedBox();

                        return Column(
                          children: orders.map((doc) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: OrderTile(
                                  doc: doc,
                                  ordersRef: doc.reference.parent
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}