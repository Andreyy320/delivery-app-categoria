import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // Добавь этот пакет в pubspec.yaml

class OrderHistoryScreen extends StatefulWidget {
  final String shopId;

  const OrderHistoryScreen({super.key, required this.shopId});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String selectedStatus = 'all';
  final Color primaryColor = const Color(0xFF2D31FA);

  // Функция для открытия ссылки из кода
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
    // Ссылка на историю заказов конкретного заведения
    var historyRef = FirebaseFirestore.instance
        .collection('categories')
        .doc(widget.shopId.trim())
        .collection('ordersHistory');

    Query query = historyRef;

    // Фильтр по статусу
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
              // Сортировка требует составного индекса (status + updatedAt)
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
                          const Text(
                            'Нужно создать индекс в Firebase',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () => _launchIndexUrl(errorMsg),
                            child: const Text(
                              'НАЖМИ ТУТ ЧТОБЫ СОЗДАТЬ ИНДЕКС',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Или проверьте лог в Android Studio — там есть прямая ссылка',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
            _filterChip('inProgress', 'В пути'),
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
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildOrderHistoryCard(Map<String, dynamic> data, String id) {
    String status = data['status'] ?? 'new';
    String clientComment = data['comment'] ?? '';
    String restaurantComment = data['restaurantComment'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('№${id.length > 6 ? id.substring(id.length - 6).toUpperCase() : id}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black54)),
                _statusBadge(status),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _rowInfo(Icons.person_outline, 'Клиент', data['clientName'] ?? 'Не указан'),
                const SizedBox(height: 8),
                _rowInfo(Icons.shopping_bag_outlined, 'Сумма', '${data['total'] ?? 0} Руб'),
                if (data['courierName'] != null) ...[
                  const SizedBox(height: 8),
                  _rowInfo(Icons.delivery_dining, 'Курьер', data['courierName'], color: primaryColor),
                ],

                // ДОБАВЛЕНО: Комментарии
                if (clientComment.isNotEmpty || restaurantComment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                ],

                if (clientComment.isNotEmpty)
                  _commentRow('Клиент:', clientComment, Colors.orange),

                if (restaurantComment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _commentRow('Комментарий от клиента:', restaurantComment, Colors.blue),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['updatedAt'] != null
                      ? DateFormat('dd.MM HH:mm').format((data['updatedAt'] as Timestamp).toDate())
                      : 'Время не указано',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentRow(String label, String text, Color labelColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: labelColor)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _rowInfo(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 5),
        Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? Colors.black87, fontSize: 13))),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'preparing': color = Colors.orange; text = 'Готовится'; break;
      case 'ready': color = Colors.teal; text = 'Готов'; break;
      case 'accepted': color = Colors.blue; text = 'Принят курьером'; break;
      case 'inProgress': color = Colors.indigo; text = 'В пути'; break;
      case 'delivered': color = Colors.green; text = 'Доставлен'; break;
      case 'canceled': color = Colors.red; text = 'Отменен'; break;
      default: color = Colors.grey; text = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 70, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('В истории заведения пусто', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Здесь появятся заказы, взятые курьерами', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}