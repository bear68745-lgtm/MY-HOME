import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyHomeApp());
}

class MyHomeApp extends StatelessWidget {
  const MyHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Home',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _width = TextEditingController();
  final _length = TextEditingController();
  final _picker = ImagePicker();

  File? _image;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 95,
    );
    if (picked == null) return;

    setState(() => _image = File(picked.path));
  }

  void _createPlan() {
    final width = double.tryParse(_width.text.replaceAll(',', '.'));
    final length = double.tryParse(_length.text.replaceAll(',', '.'));

    if (_image == null) {
      _message('กรุณาเลือกรูปวาดก่อน');
      return;
    }
    if (width == null || width <= 0 || length == null || length <= 0) {
      _message('กรุณากรอกความกว้างและความยาวเป็นตัวเลขมากกว่า 0');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Plan2DScreen(
          image: _image!,
          widthMeters: width,
          lengthMeters: length,
        ),
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  void dispose() {
    _width.dispose();
    _length.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Home'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const _StepTitle(number: '1', title: 'นำเข้ารูปวาด'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('แกลลอรี่'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('ถ่ายรูป'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 230,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade400),
                color: Colors.grey.shade100,
              ),
              clipBehavior: Clip.antiAlias,
              child: _image == null
                  ? const Center(
                      child: Text(
                        'ยังไม่มีรูปวาด\nเลือกรูปจากแกลลอรี่หรือถ่ายรูป',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Image.file(_image!, fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),
            const _StepTitle(number: '2', title: 'กำหนดขนาดจริง'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _width,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'ความกว้าง',
                      suffixText: 'เมตร',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _length,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'ความยาว',
                      suffixText: 'เมตร',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _StepTitle(number: '3', title: 'สร้างแบบ 2D'),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _createPlan,
              icon: const Icon(Icons.architecture),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('สร้างผัง 2D จากรูปวาด'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'รุ่นนี้รักษารูปต้นฉบับไว้เป็นชั้นอ้างอิง และปรับกรอบผังตามขนาดจริง '
              'เพื่อให้ต่อยอดไปสู่การอ่านผนัง ประตู หน้าต่าง และ 3D ได้ในรุ่นถัดไป',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  final String number;
  final String title;

  const _StepTitle({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          child: Text(number),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class Plan2DScreen extends StatelessWidget {
  final File image;
  final double widthMeters;
  final double lengthMeters;

  const Plan2DScreen({
    super.key,
    required this.image,
    required this.widthMeters,
    required this.lengthMeters,
  });

  @override
  Widget build(BuildContext context) {
    final area = widthMeters * lengthMeters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Home • แบบ 2D'),
        actions: [
          IconButton(
            tooltip: 'กลับไปแก้ขนาด',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      title: 'กว้าง',
                      value: '${_fmt(widthMeters)} ม.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoCard(
                      title: 'ยาว',
                      value: '${_fmt(lengthMeters)} ม.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoCard(
                      title: 'พื้นที่',
                      value: '${_fmt(area)} ตร.ม.',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                boundaryMargin: const EdgeInsets.all(120),
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableW = math.max(80, constraints.maxWidth - 40);
                      final availableH =
                          math.max(120, constraints.maxHeight - 80);
                      final realRatio = widthMeters / lengthMeters;

                      double w = availableW;
                      double h = w / realRatio;
                      if (h > availableH) {
                        h = availableH;
                        w = h * realRatio;
                      }

                      return SizedBox(
                        width: w,
                        height: h,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(width: 2),
                                color: Colors.white,
                              ),
                              child: Image.file(
                                image,
                                fit: BoxFit.fill,
                              ),
                            ),
                            CustomPaint(
                              painter: PlanOverlayPainter(
                                widthMeters: widthMeters,
                                lengthMeters: lengthMeters,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Text(
                'ลากเพื่อดู • ใช้นิ้วสองนิ้วเพื่อซูม',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _InfoCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}


class PlanOverlayPainter extends CustomPainter {
  final double widthMeters;
  final double lengthMeters;

  PlanOverlayPainter({
    required this.widthMeters,
    required this.lengthMeters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.black87;
    canvas.drawRect(
      Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3),
      border,
    );

    final dimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.black87;

    final bg = Paint()..color = Colors.white.withOpacity(0.82);

    final top = Rect.fromLTWH(size.width / 2 - 48, 6, 96, 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(top, const Radius.circular(6)),
      bg,
    );

    final topText = TextPainter(
      text: TextSpan(
        text: '${_fmt(widthMeters)} m',
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    topText.paint(
      canvas,
      Offset(size.width / 2 - topText.width / 2, 11),
    );

    final side = Rect.fromLTWH(
      size.width - 70,
      size.height / 2 - 14,
      64,
      28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(side, const Radius.circular(6)),
      bg,
    );

    final sideText = TextPainter(
      text: TextSpan(
        text: '${_fmt(lengthMeters)} m',
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(
      size.width - 22,
      size.height / 2 + sideText.width / 2,
    );
    canvas.rotate(-math.pi / 2);
    sideText.paint(canvas, Offset.zero);
    canvas.restore();

    // มุมแสดงมาตราส่วนของกรอบ
    final scale = TextPainter(
      text: const TextSpan(
        text: '2D • ต้นฉบับ',
        style: TextStyle(
          fontSize: 11,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelBg = Rect.fromLTWH(
      8,
      size.height - scale.height - 10,
      scale.width + 12,
      scale.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelBg, const Radius.circular(5)),
      bg,
    );
    scale.paint(canvas, Offset(14, size.height - scale.height - 8));
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

  @override
  bool shouldRepaint(covariant PlanOverlayPainter oldDelegate) {
    return oldDelegate.widthMeters != widthMeters ||
        oldDelegate.lengthMeters != lengthMeters;
  }
}
