import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_button.dart';
import '../models/training_content.dart';
import 'package:url_launcher/url_launcher.dart';
import 'reports_screen.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'enhanced_printer_settings_screen.dart';
import 'rfid_settings_screen.dart';

class TrainingAssistantScreen extends StatefulWidget {
  const TrainingAssistantScreen({super.key});

  @override
  State<TrainingAssistantScreen> createState() =>
      _TrainingAssistantScreenState();
}

class _TrainingAssistantScreenState extends State<TrainingAssistantScreen> {
  final TextEditingController _search = TextEditingController();
  int _pivotIndex = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterSections(_search.text.trim());
    return AdaptiveScaffold(
      title: 'المساعد التدريبي',
      commandBarItems: [
        CommandBarButton(
          icon: const Icon(FluentIcons.contact_info, size: 20),
          label: const Text(
            'الدليل',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          onPressed: () => setState(() => _pivotIndex = 0),
        ),
        CommandBarButton(
          icon: const Icon(FluentIcons.lightning_bolt, size: 20),
          label: const Text(
            'مهام سريعة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          onPressed: () => setState(() => _pivotIndex = 1),
        ),
        CommandBarButton(
          icon: const Icon(FluentIcons.lifesaver, size: 20),
          label: const Text(
            'حلول المشاكل',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          onPressed: () => setState(() => _pivotIndex = 2),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: _search,
                    placeholder:
                        'ابحث عن سؤال أو إجراء... (مثال: طابعة، تقرير، RFID)',
                    onChanged: (_) => setState(() {}),
                    suffix: IconButton(
                      icon: const Icon(FluentIcons.clear),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _pivotIndex == 0
                  ? _GuideView(sections: filtered)
                  : _pivotIndex == 1
                  ? const _QuickTasksView()
                  : const _TroubleshootingView(),
            ),
          ],
        ),
      ),
    );
  }

  List<TrainingSection> _filterSections(String query) {
    if (query.isEmpty) return trainingSections;
    final lower = query.toLowerCase();
    return trainingSections
        .map(
          (s) => TrainingSection(
            title: s.title,
            items: s.items
                .where(
                  (i) =>
                      i.question.toLowerCase().contains(lower) ||
                      i.answer.toLowerCase().contains(lower),
                )
                .toList(),
          ),
        )
        .where((s) => s.items.isNotEmpty)
        .toList();
  }
}

class _GuideView extends StatefulWidget {
  final List<TrainingSection> sections;
  const _GuideView({required this.sections});

  @override
  State<_GuideView> createState() => _GuideViewState();
}

class _GuideViewState extends State<_GuideView> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: widget.sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final section = widget.sections[index];
        final isOpen = _expanded.contains(index);
        return Expander(
          header: Text(
            section.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          initiallyExpanded: isOpen,
          onStateChanged: (open) {
            setState(() {
              if (open) {
                _expanded.add(index);
              } else {
                _expanded.remove(index);
              }
            });
          },
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in section.items)
                _QaTile(question: item.question, answer: item.answer),
            ],
          ),
        );
      },
    );
  }
}

class _QaTile extends StatelessWidget {
  final String question;
  final String answer;
  const _QaTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[20]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  question,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.copy),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: '$question\n$answer'),
                  ).then((_) {
                    if (!context.mounted) return;
                    _toast(context, 'تم نسخ الإجابة');
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(answer),
        ],
      ),
    );
  }
}

class _QuickTasksView extends StatelessWidget {
  const _QuickTasksView();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _taskCard(
          context,
          title: 'بيع سريع',
          subtitle: 'افتح شاشة البيع وأكمل عملية بيع',
          icon: FluentIcons.shop,
          onTap: () => _open(context, const PosScreen()),
        ),
        _taskCard(
          context,
          title: 'التقارير',
          subtitle: 'افتح شاشة التقارير وعرض الإحصائيات',
          icon: FluentIcons.report_document,
          onTap: () => _open(context, const ReportsScreen()),
        ),
        _taskCard(
          context,
          title: 'المخزون',
          subtitle: 'إدارة الأصناف والجرد',
          icon: FluentIcons.product_catalog,
          onTap: () => _open(context, const InventoryScreen()),
        ),
        _taskCard(
          context,
          title: 'إعدادات الطابعة',
          subtitle: 'حل مشاكل الطباعة والاتصال',
          icon: FluentIcons.print,
          onTap: () => _open(context, const EnhancedPrinterSettingsScreen()),
        ),
        _taskCard(
          context,
          title: 'إعدادات RFID',
          subtitle: 'ربط البطاقة ومعالجة المشاكل',
          icon: FluentIcons.tag,
          onTap: () => _open(context, const RfidSettingsScreen()),
        ),
        _taskCard(
          context,
          title: 'دليل PDF',
          subtitle: 'فتح دليل المستخدم',
          icon: FluentIcons.pdf,
          onTap: () async {
            final uri = Uri.parse('https://'); // ضع رابط دليل خارجي إن توفر
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
        ),
      ],
    );
  }

  static Widget _taskCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            AppButton.primary(text: 'فتح', onPressed: onTap),
          ],
        ),
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(FluentPageRoute(builder: (_) => screen));
  }
}

class _TroubleshootingView extends StatelessWidget {
  const _TroubleshootingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _FixCard(
          title: 'الطباعة لا تعمل',
          steps: [
            'تأكد من توصيل الطابعة وتشغيلها.',
            'افتح: الإعدادات > الطابعة > اختبار الطباعة.',
            'تأكد من اختيار التعريف الصحيح للطابعة.',
            'جرّب إعادة تشغيل الحاسوب ثم الطابعة.',
          ],
        ),
        _FixCard(
          title: 'القارئ RFID لا يقرأ',
          steps: [
            'تأكد من تركيب القارئ والمنافذ.',
            'افتح: إعدادات RFID > اختبار القراءة.',
            'تأكد من عدم وجود تداخل معدني حول القارئ.',
            'أعد توصيل القارئ بمنفذ USB آخر.',
          ],
        ),
        _FixCard(
          title: 'الأصناف لا تظهر في السلة',
          steps: [
            'افتح شاشة المخزون وتأكد من وجود الأصناف وحالتها.',
            'تأكد من العيار والوزن والسعر.',
            'حدّث الشاشة ثم أعد المحاولة.',
          ],
        ),
        _FixCard(
          title: 'التقارير فارغة',
          steps: [
            'تأكد من اختيار الفترة الزمنية الصحيحة.',
            'جرّب إزالة الفلاتر (الفئة/طريقة الدفع/المكان).',
            'تحقق من وجود فواتير ضمن الفترة المحددة.',
          ],
        ),
      ],
    );
  }
}

class _FixCard extends StatelessWidget {
  final String title;
  final List<String> steps;
  const _FixCard({required this.title, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(FluentIcons.copy),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: '$title\n- ${steps.join('\n- ')}'),
                  ).then((_) {
                    if (!context.mounted) return;
                    _toast(context, 'تم نسخ الخطوات');
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.status_circle_checkmark,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _toast(BuildContext context, String text) {
  displayInfoBar(
    context,
    builder: (context, close) =>
        InfoBar(title: Text(text), severity: InfoBarSeverity.success),
  );
}
