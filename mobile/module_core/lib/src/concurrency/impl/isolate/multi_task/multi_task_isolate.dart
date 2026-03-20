export "platform/isolate_multi_task_stub.dart"
    if (dart.library.io) "platform/isolate_multi_task_vm.dart"
    if (dart.library.js) "platform/isolate_multi_task_web.dart"
    if (dart.library.js_interop) "platform/isolate_multi_task_web.dart"
    if (dart.library.html) "platform/isolate_multi_task_web.dart";
