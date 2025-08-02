# JWE POS - قائمة المهام

هذه القائمة تتبع خطة تطوير التطبيق.

## المرحلة الأولى: إكمال الواجهات وربطها بالمنطق (UI & Logic Integration)

- [x] **شاشة نقطة البيع (`pos_screen.dart`):**
  - [x] الواجهة: تصميم شبكة لعرض المنتجات (باستخدام `flutter_staggered_grid_view`) مع فلاتر حسب الفئة.
  - [x] المنطق:
    - [x] استخدام `ItemProvider` لجلب وعرض المنتجات المتاحة (`inStock`).
    - [x] عند الضغط على منتج، يتم إضافته إلى `CartProvider`.
    - [x] عرض ملخص للسلة (الإجمالي، عدد القطع) والانتقال إلى شاشة الدفع.
- [x] **شاشة المخزون (`inventory_screen.dart`):**
  - [x] الواجهة: عرض قائمة بكل الأصناف مع حالتها (`needsRfid`, `inStock`, `sold`).
  - [x] المنطق:
    - [x] استخدام `ItemProvider` لجلب كل الأصناف.
    - [x] إضافة أزرار للانتقال إلى شاشة "إضافة صنف" أو "ربط RFID".
    - [x] إمكانية البحث عن صنف معين بالـ SKU أو الاسم.
- [x] **شاشة إضافة/تعديل صنف (`add_item_screen.dart`):**
  - [x] الواجهة: تصميم فورم يحتوي على حقول لإدخال كل تفاصيل الصنف.
  - [x] المنطق:
    - [x] استخدام `image_picker` لاختيار صورة للمنتج.
    - [x] عند الحفظ، يتم استدعاء `ItemRepository.insertItem()` أو `updateItem()`.
    - [x] توليد SKU تلقائيًا باستخدام `ItemRepository.generateNextSku()`.
- [x] **شاشة ربط RFID (`link_rfid_screen.dart`):**
  - [x] الواجهة: واجهة بسيطة تعرض تفاصيل المنتج المختار وتنتظر قراءة بطاقة RFID.
  - [x] المنطق:
    - [x] استدعاء `RfidService` لقراءة البطاقة.
    - [x] عند الحصول على رقم البطاقة، يتم استدعاء `ItemRepository.linkRfidTag()` لتحديث المنتج.
- [ ] **إكمال باقي الشاشات (CRUD Screens):**
  - [x] `manage_categories_screen.dart`
  - [x] `manage_materials_screen.dart`
  - [x] `customers_screen.dart`
  - [x] `invoices_screen.dart`
  - [x] `settings_screen.dart`

## المرحلة الثانية: تفعيل الخدمات الأساسية (Core Services)

- [x] **خدمة RFID (`rfid_service.dart`):**
  - [x] البحث عن مكتبة مناسبة للتواصل مع قارئ RFID.
  - [x] تنفيذ دالة `readTag()`.
- [x] **خدمة الطباعة (`print_service.dart`):**
  - [x] البحث عن مكتبة مناسبة للطباعة الحرارية.
  - [x] تنفيذ دالة لطباعة الفواتير.

## المرحلة الثالثة: التحسين والجودة (Refinement & Quality)

- [x] **معالجة حالات التحميل والأخطاء (Loading & Error States).**
- [x] **التحقق من صحة المدخلات (Input Validation).**
- [x] **تحسين تجربة المستخدم (UX Improvements).**

## المرحلة الرابعة: الاختبار الشامل (Testing)

- [x] **Unit Tests:** كتابة اختبارات للـ `Repositories` (ItemRepository, CategoryRepository, CustomerRepository, InvoiceRepository, MaterialRepository, SettingsRepository).
- [x] **Widget Tests:** اختبار الشاشات بشكل منفصل.
- [x] **Integration Tests:** كتابة اختبارات لسيناريوهات استخدام كاملة.

## المرحلة الخامسة: التحضير للنشر (Deployment)

- [x] **الأمان (Security):** تشفير كلمات المرور.
- [x] **أيقونة التطبيق وشاشة البداية (App Icon & Splash Screen).**
- [x] **بناء النسخة النهائية (Build Release).**
