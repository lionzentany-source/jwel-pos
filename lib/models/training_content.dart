class TrainingSection {
  final String title;
  final List<TrainingItem> items;
  TrainingSection({required this.title, required this.items});
}

class TrainingItem {
  final String question;
  final String answer;
  TrainingItem({required this.question, required this.answer});
}

final List<TrainingSection> trainingSections = [
  TrainingSection(
    title: 'دليل البدء السريع',
    items: [
      TrainingItem(
        question: 'كيف أبدأ باستخدام النظام؟',
        answer:
            '1. سجل الدخول واختر المستخدم.\n2. انتقل إلى شاشة السلة لإضافة الأصناف.\n3. أكمل عملية البيع أو الطباعة.',
      ),
      TrainingItem(
        question: 'ما هي الخطوات الأساسية؟',
        answer: 'تسجيل الدخول > إضافة أصناف للسلة > دفع أو طباعة فاتورة.',
      ),
    ],
  ),
  TrainingSection(
    title: 'شروحات الشاشات',
    items: [
      TrainingItem(
        question: 'شرح شاشة البيع والسلة',
        answer: 'اختر الصنف، أضفه للسلة، عدل الكمية، ثم أكمل الدفع.',
      ),
      TrainingItem(
        question: 'شرح شاشة التقارير',
        answer: 'اختر الفترة الزمنية، اعرض التقرير، استخدم الفلاتر.',
      ),
      TrainingItem(
        question: 'شرح إدارة الأصناف',
        answer: 'أضف أو عدل أو احذف الأصناف من شاشة الأصناف.',
      ),
      TrainingItem(
        question: 'شرح شاشة العملاء',
        answer: 'أضف عملاء جدد، عدل بياناتهم، راقب مشترياتهم.',
      ),
    ],
  ),
  TrainingSection(
    title: 'الأسئلة الشائعة (FAQ)',
    items: [
      TrainingItem(
        question: 'كيف أضيف صنف جديد؟',
        answer: 'من شاشة الأصناف، اضغط زر الإضافة واملأ البيانات.',
      ),
      TrainingItem(
        question: 'كيف أعدل سعر مادة؟',
        answer: 'من شاشة تعديل أسعار المواد، اختر المادة وعدل السعر.',
      ),
      TrainingItem(
        question: 'كيف أستخرج تقرير؟',
        answer: 'من شاشة التقارير، اختر الفترة واضغط على عرض التقرير.',
      ),
    ],
  ),
  TrainingSection(
    title: 'مشاكل وحلول',
    items: [
      TrainingItem(
        question: 'لا أستطيع تسجيل الدخول',
        answer:
            'تأكد من اسم المستخدم وكلمة المرور. إذا استمرت المشكلة، تواصل مع الدعم.',
      ),
      TrainingItem(
        question: 'لا تظهر الأصناف في السلة',
        answer: 'تأكد من إضافة الأصناف بشكل صحيح أو تحديث الصفحة.',
      ),
      TrainingItem(
        question: 'مشكلة في طباعة الفاتورة',
        answer: 'تأكد من إعدادات الطابعة أو أعد تشغيل الجهاز.',
      ),
    ],
  ),
];
