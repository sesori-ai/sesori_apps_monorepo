import "package:web/web.dart" as web;

import "prego_annotation_storage_access.dart";

PregoAnnotationStorageAccess createPregoAnnotationStorageAccess() => PregoAnnotationStorageAccess(
  read: (key) async => web.window.localStorage.getItem(key),
  write: (key, value) async => web.window.localStorage.setItem(key, value),
);
