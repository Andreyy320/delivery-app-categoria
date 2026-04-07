import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final CollectionReference ordersRef;

  const OrderTile({super.key, required this.doc, required this.ordersRef});

  @override
  Widget build(BuildContext context) {
    final orderData = doc.data() as Map<String, dynamic>;
    final orderId = doc.id;

    final createdAt = orderData['createdAt'] as Timestamp?;
    final dateString = createdAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate())
        : '-';

    final items = orderData['items'] as List<dynamic>? ?? [];
    final status = orderData['status'] ?? 'new';
    final statusUpdatedAt = orderData['statusUpdatedAt'] as Timestamp?;
    final statusTimeString = statusUpdatedAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(statusUpdatedAt.toDate())
        : '-';

    // ==== Новый код для номера телефона и перевода оплаты ====
    final clientPhone = orderData['clientPhone'] ?? '-';

    String paymentMethod = orderData['paymentMethod'] ?? '-';
    if (paymentMethod.toLowerCase() == 'cash') paymentMethod = 'Наличные';
    if (paymentMethod.toLowerCase() == 'online') paymentMethod = 'Онлайн';
    // ========================================================

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
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              orderData['clientName'] ?? 'Клиент',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatus(status),
                const SizedBox(height: 2),
                Text('Обновлено: $statusTimeString',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Телефон: $clientPhone\nДата: $dateString\nОплата: $paymentMethod\nСумма: ${orderData['total'] ?? 0} ₽',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        children: [
          const Divider(),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Состав заказа:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            final i = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      i['name'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text('${i['quantity']} x ${i['price']} ₽'),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatus(String status) {
    Color color;
    String text;

    switch (status) {
      case 'new':
        color = Colors.orange;
        text = 'Новый';
        break;
      case 'preparing':
        color = Colors.blue;
        text = 'Готовится';
        break;
      case 'ready':
        color = Colors.green;
        text = 'Готов';
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
