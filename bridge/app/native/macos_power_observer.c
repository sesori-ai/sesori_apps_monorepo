#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOMessage.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdlib.h>

typedef void (*sesori_power_callback)(int event, int error_code);
typedef struct {
  pthread_t thread;
  pthread_mutex_t mutex;
  CFRunLoopRef run_loop;
  bool stopping;
  sesori_power_callback callback;
  io_connect_t root_port;
} sesori_power_observer;

enum { SESORI_STARTED = 0, SESORI_WILL_SLEEP = 1, SESORI_FULL_WAKE = 2, SESORI_FAILED = 3 };

static void power_changed(void *refcon, io_service_t service, natural_t message_type, void *message_argument) {
  (void)service;
  sesori_power_observer *observer = refcon;
  const intptr_t token = (intptr_t)message_argument;
  if (message_type == kIOMessageCanSystemSleep) {
    IOAllowPowerChange(observer->root_port, token);
    return;
  }
  if (message_type == kIOMessageSystemWillSleep) {
    IOAllowPowerChange(observer->root_port, token);
    observer->callback(SESORI_WILL_SLEEP, 0);
    return;
  }
  if (message_type == kIOMessageSystemWillPowerOn || message_type == kIOMessageSystemHasPoweredOn) {
    observer->callback(SESORI_FULL_WAKE, 0);
  }
}

static void *observer_main(void *context) {
  sesori_power_observer *observer = context;
  IONotificationPortRef notify_port = NULL;
  io_object_t notifier = IO_OBJECT_NULL;
  io_connect_t root_port = IORegisterForSystemPower(observer, &notify_port, power_changed, &notifier);
  if (root_port == IO_OBJECT_NULL || notify_port == NULL) {
    if (notifier != IO_OBJECT_NULL) IODeregisterForSystemPower(&notifier);
    if (root_port != IO_OBJECT_NULL) IOServiceClose(root_port);
    if (notify_port != NULL) IONotificationPortDestroy(notify_port);
    observer->callback(SESORI_FAILED, -1);
    return NULL;
  }
  observer->root_port = root_port;
  CFRunLoopSourceRef source = IONotificationPortGetRunLoopSource(notify_port);
  pthread_mutex_lock(&observer->mutex);
  observer->run_loop = CFRunLoopGetCurrent();
  CFRetain(observer->run_loop);
  bool stopping = observer->stopping;
  pthread_mutex_unlock(&observer->mutex);
  if (!stopping) {
    CFRunLoopAddSource(observer->run_loop, source, kCFRunLoopDefaultMode);
    observer->callback(SESORI_STARTED, 0);
    CFRunLoopRun();
    CFRunLoopRemoveSource(observer->run_loop, source, kCFRunLoopDefaultMode);
  }
  IODeregisterForSystemPower(&notifier);
  IOServiceClose(root_port);
  IONotificationPortDestroy(notify_port);
  pthread_mutex_lock(&observer->mutex);
  CFRelease(observer->run_loop);
  observer->run_loop = NULL;
  pthread_mutex_unlock(&observer->mutex);
  return NULL;
}

void *sesori_power_observer_start(sesori_power_callback callback) {
  if (callback == NULL) return NULL;
  sesori_power_observer *observer = calloc(1, sizeof(*observer));
  if (observer == NULL) return NULL;
  observer->callback = callback;
  pthread_mutex_init(&observer->mutex, NULL);
  if (pthread_create(&observer->thread, NULL, observer_main, observer) != 0) {
    pthread_mutex_destroy(&observer->mutex);
    free(observer);
    return NULL;
  }
  return observer;
}

void sesori_power_observer_stop(void *handle) {
  sesori_power_observer *observer = handle;
  if (observer == NULL) return;
  pthread_mutex_lock(&observer->mutex);
  observer->stopping = true;
  if (observer->run_loop != NULL) CFRunLoopStop(observer->run_loop);
  pthread_mutex_unlock(&observer->mutex);
  pthread_join(observer->thread, NULL);
  pthread_mutex_destroy(&observer->mutex);
  free(observer);
}
