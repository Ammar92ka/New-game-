/// عزل الأرقام عن اتجاه النص حتى تظهر علامة السالب في مكانها الصحيح.
String ltr(String s) => '\u2066$s\u2069';

/// رقم بفواصل الآلاف، مثل 12,000.
String formatNumber(num v) {
  final r = v.round();
  final digits = r.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return ltr(r < 0 ? '-$buf' : buf.toString());
}

/// رقم بإشارة صريحة، مثل +800 أو -1,200.
String formatSigned(num v) {
  final r = v.round();
  if (r == 0) return ltr('0');
  final digits = formatNumber(r.abs())
      .replaceAll('\u2066', '')
      .replaceAll('\u2069', '');
  return ltr(r > 0 ? '+$digits' : '-$digits');
}


String _trim(double v) {
  var t = v.toStringAsFixed(2);
  if (t.contains('.')) {
    t = t.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return t;
}

/// مبلغ بالقروش بصيغة مختصرة: 2.5 مليون، 800 ألف.
String formatMoney(num v) {
  final a = v.abs().toDouble();
  final String body;
  if (a >= 1e9) {
    body = '${_trim(a / 1e9)} مليار';
  } else if (a >= 1e6) {
    body = '${_trim(a / 1e6)} مليون';
  } else if (a >= 1e3) {
    body = '${_trim(a / 1e3)} ألف';
  } else {
    body = a.round().toString();
  }
  return v < 0 ? ltr('-') + body : body;
}

/// مبلغ مختصر بإشارة صريحة.
String formatMoneySigned(num v) {
  if (v.round() == 0) return '0';
  final body = formatMoney(v.abs());
  return v > 0 ? '+$body' : '-$body';
}
