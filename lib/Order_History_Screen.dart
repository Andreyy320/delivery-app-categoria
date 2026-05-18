import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderHistoryScreen extends StatefulWidget {
  final String shopId;

  const OrderHistoryScreen({super.key, required this.shopId});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String selectedStatus = 'all';
  final Color primaryColor = const Color(0xFF2D31FA);

  Future<void> _launchIndexUrl(String errorText) async {
    final RegExp regExp = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
    final match = regExp.firstMatch(errorText);
    if (match != null) {
      final url = Uri.parse(match.group(0)!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var historyRef = FirebaseFirestore.instance
        .collection('categories')
        .doc(widget.shopId.trim())
        .collection('ordersHistory');

    Query query = historyRef;

    if (selectedStatus != 'all') {
      query = query.where('status', isEqualTo: selectedStatus);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('История заведения',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.orderBy('updatedAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  String errorMsg = snapshot.error.toString();
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                          const SizedBox(height: 10),
                          const Text('Нужно создать индекс в Firebase',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () => _launchIndexUrl(errorMsg),
                            child: const Text('НАЖМИ ТУТ ЧТОБЫ СОЗДАТЬ ИНДЕКС'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    final docId = snapshot.data!.docs[index].id;
                    return _buildOrderHistoryCard(data, docId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('all', 'Все записи'),
            _filterChip('accepted', 'Принятые'),
            _filterChip('preparing', 'Готовятся'),
            _filterChip('ready', 'Готовы'),
            _filterChip('delivered', 'Завершены'),
            _filterChip('canceled', 'Отменены'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String status, String label) {
    bool isSelected = selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) => setState(() => selectedStatus = status),
        selectedColor: primaryColor,
        labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 12),
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildOrderHistoryCard(Map<String, dynamic> data, String id) {
    String status = data['status'] ?? 'new';
    String clientComment = data['comment'] ?? '';
    String restaurantComment = data['restaurantComment'] ?? '';
    List items = data['items'] as List? ?? [];

    final displayPrice = data['itemsPrice'] ?? data['total'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('№${id.length > 6 ? id.substring(id.length - 6).toUpperCase() : id}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black54)),
              _statusBadge(status),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _rowInfo(Icons.person_outline, 'Клиент', data['clientName'] ?? 'Не указан'),
              const SizedBox(height: 4),
              _rowInfo(Icons.shopping_bag_outlined, 'Сумма товаров', '$displayPrice Руб'),
            ],
          ),
          children: [
            const Divider(height: 1),
            // --- СОСТАВ ЗАКАЗА ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('СОСТАВ ЗАКАЗА:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${item['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        Text('${item['quantity']} шт. x ${item['price']} Руб', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  )).toList(),

                  if (clientComment.isNotEmpty || restaurantComment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (clientComment.isNotEmpty)
                      _commentRow('Курьеру:', clientComment, Colors.orange),
                    if (restaurantComment.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _commentRow('Заведению:', restaurantComment, Colors.blue),
                      ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['updatedAt'] != null
                            ? DateFormat('dd.MM HH:mm').format((data['updatedAt'] as Timestamp).toDate())
                            : 'Время не указано',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      if (data['courierName'] != null)
                        Text('Курьер: ${data['courierName']}', style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentRow(String label, String text, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor)),
        Text(text, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87)),
      ],
    );
  }

  Widget _rowInfo(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? Colors.black87, fontSize: 12)),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'preparing': color = Colors.orange; text = 'Готовится'; break;
      case 'ready': color = Colors.teal; text = 'Готов'; break;
      case 'delivered': color = Colors.green; text = 'Доставлен'; break;
      case 'canceled': color = Colors.red; text = 'Отменен'; break;
      default: color = Colors.blue; text = 'В работе';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('История пока пуста', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}