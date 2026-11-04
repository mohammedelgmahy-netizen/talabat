import 'package:url_launcher/url_launcher.dart';

Future<void> callPhone(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

/// فتح الملاحة في خرائط جوجل/أبل للوصول لنقطة
Future<void> openNavigation(double lat, double lng) => launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'),
      mode: LaunchMode.externalApplication,
    );
