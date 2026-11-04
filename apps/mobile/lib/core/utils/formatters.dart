import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 2);
final _time = DateFormat('hh:mm a', 'ar');
final _dateTime = DateFormat('d MMM yyyy - hh:mm a', 'ar');

String money(num value) => _money.format(value);
String timeOf(DateTime? d) => d == null ? '-' : _time.format(d);
String dateTimeOf(DateTime? d) => d == null ? '-' : _dateTime.format(d);
String km(num value) => '${value.toStringAsFixed(1)} كم';
