import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// --- ЭКРАН СТОП-ЛИСТА (МЕНЮ) ---
class BusinessStopListScreen extends StatelessWidget {
  final String shopId;

  const BusinessStopListScreen({super.key, required this.shopId});

  // Функция для удаления товара
  Future<void> _deleteItem(BuildContext context, String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить товар?"),
        content: const Text("Это действие нельзя будет отменить."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Удалить", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(shopId)
          .collection('menu')
          .doc(itemId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Меню заведения",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddItemFormWeb(shopId: shopId)),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .doc(shopId)
            .collection('menu')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Меню пусто. Нажмите +, чтобы добавить."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var item = snapshot.data!.docs[index];
              var data = item.data() as Map<String, dynamic>;

              bool isAvailable = data['isAvailable'] ?? true;
              String name = data['name'] ?? data['title'] ?? 'Без названия';
              String desc = data['description'] ?? '';
              String weight = data['weight']?.toString() ?? '';
              var price = data['price'] ?? 0;
              String imagePath = data['imagePath'] ?? data['imageUrl'] ?? '';

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isAvailable ? 1.0 : 0.6,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ФОТО ТОВАРА
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: imagePath.isNotEmpty
                                ? Image.network(
                              imagePath,
                              width: 95,
                              height: 95,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                                : _buildPlaceholder(),
                          ),
                          if (!isAvailable)
                            Container(
                              width: 95,
                              height: 95,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  "СТОП",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // ИНФОРМАЦИЯ И ПАНЕЛЬ УПРАВЛЕНИЯ
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Название товара
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1, // На мелких экранах держим в 1 строку для компактности
                              overflow: TextOverflow.ellipsis,
                            ),

                            // Описание (если есть)
                            if (desc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  desc,
                                  style: TextStyle(
                                      color: Colors.blueGrey[500], fontSize: 12, height: 1.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                            const SizedBox(height: 8),

                            // Цена и Вес
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  "$price Руб",
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                if (weight.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    RegExp(r'[a-zA-Zа-яА-Я]').hasMatch(weight)
                                        ? weight
                                        : "/ $weight г",
                                    style: TextStyle(
                                        color: Colors.blueGrey[400],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ]
                              ],
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
                            ),

                            // НИЖНЯЯ ПАНЕЛЬ: Заменили Row на Wrap, чтобы ничего не вылетало
                            Wrap(
                              spacing: 8, // Отступ между элементами по горизонтали
                              runSpacing: 6, // Отступ, если элементы перенесутся на новую строку
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Статус "В наличии" / "В стопе"
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isAvailable ? "В наличии" : "В стопе",
                                    style: TextStyle(
                                      color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                // Кнопки действий внутри Row с min размером, чтобы Wrap правильно их переносил целиком
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      icon: Icon(Icons.edit_note_rounded, color: Colors.blueGrey[400], size: 22),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => EditItemFormWeb(shopId: shopId, itemId: item.id, itemData: data)),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                      onPressed: () => _deleteItem(context, item.id),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      height: 20,
                                      width: 34,
                                      child: Transform.scale(
                                        scale: 0.7,
                                        child: Switch(
                                          value: isAvailable,
                                          activeColor: Colors.green,
                                          onChanged: (val) {
                                            FirebaseFirestore.instance
                                                .collection('categories')
                                                .doc(shopId)
                                                .collection('menu')
                                                .doc(item.id)
                                                .update({'isAvailable': val});
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 90,
      height: 90,
      color: const Color(0xFFF1F5F9),
      child:
      const Icon(Icons.fastfood_rounded, color: Colors.blueGrey, size: 30),
    );
  }
}

// --- ЭКРАН ДОБАВЛЕНИЯ ---
class AddItemFormWeb extends StatefulWidget {
  final String shopId;
  const AddItemFormWeb({super.key, required this.shopId});

  @override
  State<AddItemFormWeb> createState() => _AddItemFormWebState();
}

class _AddItemFormWebState extends State<AddItemFormWeb> {
  final _formKey = GlobalKey<FormState>();

  // 🔹 ПОПРАВЛЕНО: Сделали контроллеры статическими, чтобы они жили в памяти
  // даже когда пользователь временно вышел из экрана (кнопка назад).
  static final nameCtrl = TextEditingController();
  static final priceCtrl = TextEditingController();
  static final catCtrl = TextEditingController();
  static final weightCtrl = TextEditingController();
  static final descCtrl = TextEditingController();
  static final imgUrlCtrl = TextEditingController();

  // 🔹 Изображение тоже сохраняем статически, чтобы заготовка фото не пропадала
  static Uint8List? _savedWebImage;

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final String _imgBBKey = "19b9ece492b6e9cf40bd22859665516b";

  // 🔹 Метод для полной очистки черновика ПОСЛЕ успешного сохранения
  static void _clearDraft() {
    nameCtrl.clear();
    priceCtrl.clear();
    catCtrl.clear();
    weightCtrl.clear();
    descCtrl.clear();
    imgUrlCtrl.clear();
    _savedWebImage = null;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        final Uint8List f = await image.readAsBytes();
        setState(() {
          _savedWebImage = f;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Ошибка галереи: $e")));
    }
  }

  Future<String?> _uploadToImgBB(Uint8List bytes) async {
    try {
      String base64Image = base64Encode(bytes);
      var response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {'key': _imgBBKey, 'image': base64Image},
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data['data']['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_savedWebImage == null && imgUrlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Добавьте фото!")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String finalImagePath = imgUrlCtrl.text.trim();
      if (_savedWebImage != null) {
        String? uploadedUrl = await _uploadToImgBB(_savedWebImage!);
        if (uploadedUrl == null) throw Exception("Ошибка загрузки");
        finalImagePath = uploadedUrl;
      }

      await FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.shopId)
          .collection('menu')
          .add({
        'title': nameCtrl.text.trim(),
        'price': double.tryParse(priceCtrl.text) ?? 0.0,
        'category': catCtrl.text.trim(),
        'weight': weightCtrl.text.trim(),
        'imagePath': finalImagePath,
        'description': descCtrl.text.trim(),
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔹 ПОПРАВЛЕНО: Стираем заготовку только тогда, когда товар успешно добавлен на сервер
      _clearDraft();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Новый товар",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("ОСНОВНАЯ ИНФОРМАЦИЯ"),
                  _card([
                    _modernInput(nameCtrl, "Название товара",
                        Icons.shopping_bag_outlined),
                    _modernInput(catCtrl, "Категория", Icons.category_outlined),
                    _modernInput(descCtrl, "Описание", Icons.notes, lines: 3),
                  ]),
                  const SizedBox(height: 24),
                  _sectionTitle("СТОИМОСТЬ И ВЕС"),
                  _card([
                    Row(
                      children: [
                        Expanded(
                            child: _modernInput(priceCtrl, "Цена (Руб)",
                                Icons.payments_outlined,
                                isNum: true)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _modernInput(weightCtrl, "Вес (н-р: 500 г)",
                                Icons.scale_outlined)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _sectionTitle("ФОТО ТОВАРА"),
                  _card([
                    Center(
                      child: Column(
                        children: [
                          if (_savedWebImage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(_savedWebImage!,
                                    height: 180, width: 180, fit: BoxFit.cover),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: Colors.blueAccent),
                              ),
                              onPressed: _pickImage,
                              icon: Icon(_savedWebImage == null
                                  ? Icons.add_a_photo
                                  : Icons.refresh),
                              label: Text(_savedWebImage == null
                                  ? "Выбрать файл"
                                  : "Заменить файл"),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text("ИЛИ",
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                          ),
                          _modernInput(
                              imgUrlCtrl, "Вставьте ссылку на фото", Icons.link,
                              required: false),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _saveProduct,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("СОХРАНИТЬ",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.blueGrey[400],
              letterSpacing: 1.2)),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _modernInput(TextEditingController ctrl, String hint, IconData icon,
      {bool isNum = false, int lines = 1, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: ctrl,
        maxLines: lines,
        keyboardType: isNum
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        validator: (v) {
          if (!required) return null;
          return (v == null || v.isEmpty) ? "Обязательно" : null;
        },
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, size: 20, color: Colors.blueAccent),
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
// --- ЭКРАН РЕДАКТИРОВАНИЯ ---
class EditItemFormWeb extends StatefulWidget {
  final String shopId;
  final String itemId;
  final Map<String, dynamic> itemData;

  const EditItemFormWeb({super.key, required this.shopId, required this.itemId, required this.itemData});

  @override
  State<EditItemFormWeb> createState() => _EditItemFormWebState();
}

class _EditItemFormWebState extends State<EditItemFormWeb> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController catCtrl;
  late TextEditingController weightCtrl;
  late TextEditingController descCtrl;
  late TextEditingController imgUrlCtrl;

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _webImage;
  String? _currentImageUrl;

  final String _imgBBKey = "19b9ece492b6e9cf40bd22859665516b";

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.itemData['name'] ?? widget.itemData['title'] ?? '');
    priceCtrl = TextEditingController(text: widget.itemData['price']?.toString() ?? '');
    catCtrl = TextEditingController(text: widget.itemData['category'] ?? '');
    weightCtrl = TextEditingController(text: widget.itemData['weight']?.toString() ?? '');
    descCtrl = TextEditingController(text: widget.itemData['description'] ?? '');
    _currentImageUrl = widget.itemData['imagePath'] ?? widget.itemData['imageUrl'] ?? '';
    imgUrlCtrl = TextEditingController(text: _currentImageUrl);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
      if (image != null) {
        final Uint8List f = await image.readAsBytes();
        setState(() { _webImage = f; });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка галереи: $e")));
    }
  }

  Future<String?> _uploadToImgBB(Uint8List bytes) async {
    try {
      String base64Image = base64Encode(bytes);
      var response = await http.post(Uri.parse('https://api.imgbb.com/1/upload'), body: {'key': _imgBBKey, 'image': base64Image});
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data']['url'];
      }
      return null;
    } catch (e) { return null; }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String finalImagePath = imgUrlCtrl.text.trim();
      if (_webImage != null) {
        String? uploadedUrl = await _uploadToImgBB(_webImage!);
        if (uploadedUrl != null) finalImagePath = uploadedUrl;
      }

      await FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.shopId)
          .collection('menu')
          .doc(widget.itemId)
          .update({
        'name': nameCtrl.text.trim(),
        'title': nameCtrl.text.trim(),
        'price': double.tryParse(priceCtrl.text) ?? 0.0,
        'category': catCtrl.text.trim(),
        'weight': weightCtrl.text.trim(),
        'imagePath': finalImagePath,
        'description': descCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Редактировать", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("ОСНОВНАЯ ИНФОРМАЦИЯ"),
                  _card([
                    _modernInput(nameCtrl, "Название товара", Icons.shopping_bag_outlined),
                    _modernInput(catCtrl, "Категория", Icons.category_outlined),
                    _modernInput(descCtrl, "Описание", Icons.notes, lines: 3),
                  ]),
                  const SizedBox(height: 24),
                  _sectionTitle("СТОИМОСТЬ И ВЕС"),
                  _card([
                    Row(
                      children: [
                        Expanded(child: _modernInput(priceCtrl, "Цена (Руб)", Icons.payments_outlined, isNum: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _modernInput(weightCtrl, "Вес (н-р: 500 г)", Icons.scale_outlined)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _sectionTitle("ФОТО ТОВАРА"),
                  _card([
                    Center(
                      child: Column(
                        children: [
                          if (_webImage != null || _currentImageUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _webImage != null
                                    ? Image.memory(_webImage!, height: 180, width: 180, fit: BoxFit.cover)
                                    : Image.network(_currentImageUrl!, height: 180, width: 180, fit: BoxFit.cover),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: Colors.blueAccent),
                              ),
                              onPressed: _pickImage,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Заменить файл"),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text("ИЛИ", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                          _modernInput(imgUrlCtrl, "Ссылка на фото", Icons.link, required: false),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading ? null : _updateProduct,
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("ОБНОВИТЬ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blueGrey[400], letterSpacing: 1.2)),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(children: children),
    );
  }

  Widget _modernInput(TextEditingController ctrl, String hint, IconData icon, {bool isNum = false, int lines = 1, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: ctrl,
        maxLines: lines,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        validator: (v) => (required && (v == null || v.isEmpty)) ? "Обязательно" : null,
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, size: 20, color: Colors.blueAccent),
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
