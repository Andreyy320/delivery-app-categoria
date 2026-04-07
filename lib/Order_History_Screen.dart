import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'order_tile.dart';
import 'orders_screen.dart'; // для OrderTile

class OrderHistoryScreen extends StatefulWidget {
  final String shopId;

  const OrderHistoryScreen({super.key, required this.shopId});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String selectedStatus = 'all'; // all, preparing, ready, canceled

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('История заказов'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ===== Фильтр по статусу =====
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: selectedStatus,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все')),
                DropdownMenuItem(value: 'ready', child: Text('Готовые')),
                DropdownMenuItem(value: 'canceled', child: Text('Отмененные')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedStatus = value!;
                });
              },
            ),
          ),
          // ==============================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final userDocs = snapshot.data?.docs ?? [];

                // Формируем потоки заказов с фильтром
                final List<Stream<QuerySnapshot>> orderStreams = userDocs.map((userDoc) {
                  var query = FirebaseFirestore.instance
                      .collection('users')
                      .doc(userDoc.id)
                      .collection('orders')
                      .where('shopId', isEqualTo: widget.shopId);

                  if (selectedStatus != 'all') {
                    query = query.where('status', isEqualTo: selectedStatus);
                  } else {
                    query = query.where('status', whereIn: ['ready', 'canceled']);
                  }

                  return query.snapshots();
                }).toList();

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: orderStreams.map((stream) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: stream,
                      builder: (context, orderSnapshot) {
                        if (orderSnapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox();
                        }
                        if (orderSnapshot.hasError) {
                          return Text('Ошибка: ${orderSnapshot.error}');
                        }

                        final ordersDocs = orderSnapshot.data?.docs ?? [];
                        if (ordersDocs.isEmpty) return const SizedBox();

                        return Column(
                          children: ordersDocs.map((doc) {
                            final ordersRef = doc.reference.parent;
                            return OrderTile(doc: doc, ordersRef: ordersRef);
                          }).toList(),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
