// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void ensureWebTestBaseHref() {
  final existing = html.document.querySelector('base');
  final base = existing is html.BaseElement ? existing : html.BaseElement();
  base.setAttribute('href', '/');
  if (base.parent == null) {
    html.document.head?.append(base);
  }
}
