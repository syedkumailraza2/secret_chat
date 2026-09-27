String pluralDays(int n) => n == 1 ? '1 day' : '$n days';

String capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
