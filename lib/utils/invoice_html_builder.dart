import '../models/invoice_render_data.dart';

/// منشئ HTML موحّد للفواتير يعتمد على InvoiceRenderData
String buildInvoiceHtml(InvoiceRenderData data) {
  final b = StringBuffer();
  b.writeln('<!DOCTYPE html>');
  b.writeln('<html dir="rtl" lang="ar">');
  b.writeln('<head>');
  b.writeln('<meta charset="UTF-8">');
  b.writeln(
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
  );
  b.writeln('<title>فاتورة ${_e(data.invoiceNumber)}</title>');
  b.writeln(
    '<style>'
    'body{font-family:Arial,sans-serif;margin:0;padding:20px;background:#f5f5f5;}'
    '.invoice-container{max-width:800px;margin:0 auto;background:#fff;padding:30px;border-radius:10px;box-shadow:0 0 20px rgba(0,0,0,0.1);}'
    '.header{text-align:center;border-bottom:3px solid #2196F3;padding-bottom:20px;margin-bottom:30px;}'
    '.store-name{font-size:28px;font-weight:bold;color:#2196F3;margin-bottom:10px;}'
    '.invoice-title{font-size:24px;color:#333;margin-bottom:5px;}'
    '.invoice-number{font-size:18px;color:#666;}'
    '.invoice-info{display:flex;flex-wrap:wrap;justify-content:space-between;margin-bottom:30px;padding:15px;background:#f8f9fa;border-radius:5px;}'
    '.info-section{flex:1 1 200px;margin:5px 0;}'
    '.info-label{font-weight:bold;color:#333;margin-bottom:5px;}'
    '.info-value{color:#555;}'
    'table{width:100%;border-collapse:collapse;margin-bottom:30px;}'
    'th,td{padding:12px;text-align:right;border-bottom:1px solid #ddd;}'
    'th{background:#2196F3;color:#fff;font-weight:bold;}'
    'tr:nth-child(even){background:#f8f9fa;}'
    '.totals-section{margin-top:30px;padding:20px;background:#f8f9fa;border-radius:5px;}'
    '.total-row{display:flex;justify-content:space-between;margin-bottom:10px;padding:5px 0;}'
    '.total-row.final{border-top:2px solid #2196F3;padding-top:15px;margin-top:15px;font-size:20px;font-weight:bold;color:#2196F3;}'
    '.notes{margin-top:20px;padding:15px;background:#fff3cd;border-radius:5px;line-height:1.6;}'
    '.footer{text-align:center;margin-top:40px;padding-top:20px;border-top:1px solid #ddd;color:#666;}'
    '@media print{body{background:#fff}.invoice-container{box-shadow:none}}'
    '</style>',
  );
  b.writeln(
    '<script>window.onload=function(){setTimeout(function(){window.print();},600);};</script>',
  );
  b.writeln('</head><body>');
  b.writeln('<div class="invoice-container">');
  b.writeln('<div class="header">');
  b.writeln('<div class="store-name">${_e(data.storeName)}</div>');
  b.writeln('<div class="invoice-title">فاتورة بيع</div>');
  b.writeln(
    '<div class="invoice-number">رقم الفاتورة: ${_e(data.invoiceNumber)}</div>',
  );
  b.writeln('</div>');
  b.writeln('<div class="invoice-info">');
  b.writeln(
    '<div class="info-section"><div class="info-label">التاريخ:</div><div class="info-value">${_formatDate(data.date)}</div></div>',
  );
  b.writeln(
    '<div class="info-section"><div class="info-label">طريقة الدفع:</div><div class="info-value">${_e(data.paymentMethod)}</div></div>',
  );
  if (data.customerName != null) {
    b.writeln(
      '<div class="info-section"><div class="info-label">العميل:</div><div class="info-value">${_e(data.customerName!)}</div></div>',
    );
  }
  if (data.cashierName != null) {
    b.writeln(
      '<div class="info-section"><div class="info-label">الكاشير:</div><div class="info-value">${_e(data.cashierName!)}</div></div>',
    );
  }
  b.writeln('</div>');
  b.writeln(
    '<table class="items-table"><thead><tr>'
    '<th>الصنف</th><th>الوزن</th><th>العيار</th><th>الكمية</th><th>سعر الوحدة</th><th>الإجمالي</th>'
    '</tr></thead><tbody>',
  );
  for (final it in data.items) {
    b.writeln(
      '<tr>'
      '<td>${_e(it.item.sku)}</td>'
      '<td>${it.item.weightGrams}g</td>'
      '<td>${it.item.karat}K</td>'
      '<td>${it.quantity}</td>'
      '<td>${it.unitPrice.toStringAsFixed(2)} د.ل</td>'
      '<td>${it.totalPrice.toStringAsFixed(2)} د.ل</td>'
      '</tr>',
    );
  }
  b.writeln('</tbody></table>');
  b.writeln('<div class="totals-section">');
  b.writeln(
    '<div class="total-row"><span>المجموع الفرعي:</span><span>${data.subtotal.toStringAsFixed(2)} د.ل</span></div>',
  );
  if (data.discount > 0) {
    b.writeln(
      '<div class="total-row"><span>الخصم:</span><span>- ${data.discount.toStringAsFixed(2)} د.ل</span></div>',
    );
  }
  if (data.tax > 0) {
    b.writeln(
      '<div class="total-row"><span>الضريبة:</span><span>${data.tax.toStringAsFixed(2)} د.ل</span></div>',
    );
  }
  b.writeln(
    '<div class="total-row final"><span>الإجمالي النهائي:</span><span>${data.total.toStringAsFixed(2)} د.ل</span></div>',
  );
  b.writeln('</div>');
  if (data.notes != null && data.notes!.isNotEmpty) {
    b.writeln(
      '<div class="notes"><strong>ملاحظات:</strong><br>${_e(data.notes!)}</div>',
    );
  }
  b.writeln(
    '<div class="footer"><p>شكراً لتعاملكم معنا</p><p>${_e(data.storeName)} - جودة وثقة</p></div>',
  );
  b.writeln('</div></body></html>');
  return b.toString();
}

String _formatDate(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
String _e(String v) => v
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
