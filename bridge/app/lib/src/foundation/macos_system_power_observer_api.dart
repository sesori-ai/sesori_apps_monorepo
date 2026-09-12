import "dart:ffi";

const _assetId = "package:sesori_bridge/macos_power_observer.dylib";

typedef MacosPowerObserverCallback = void Function(int event, int errorCode);
typedef _NativePowerCallback = Void Function(Int32 event, Int32 errorCode);

@Native<Pointer<Void> Function(Pointer<NativeFunction<_NativePowerCallback>>)>(
  symbol: "sesori_power_observer_start",
  assetId: _assetId,
)
external Pointer<Void> _start(Pointer<NativeFunction<_NativePowerCallback>> callback);

@Native<Void Function(Pointer<Void>)>(symbol: "sesori_power_observer_stop", assetId: _assetId)
external void _stop(Pointer<Void> handle);

class MacosSystemPowerObserverApi() {
  Pointer<Void>? _handle;
  NativeCallable<_NativePowerCallback>? _callback;

  void start({required MacosPowerObserverCallback callback}) {
    if (_handle != null) throw StateError("macOS power observer already started");
    final nativeCallback = NativeCallable<_NativePowerCallback>.listener(callback);
    final handle = _start(nativeCallback.nativeFunction);
    if (handle == nullptr) {
      nativeCallback.close();
      throw StateError("Failed to start macOS system power observer thread");
    }
    _handle = handle;
    _callback = nativeCallback;
  }

  void stop() {
    final handle = _handle;
    final callback = _callback;
    _handle = null;
    _callback = null;
    if (handle == null || callback == null) return;
    _stop(handle);
    callback.close();
  }
}
