#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

static pthread_mutex_t startup_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t startup_changed = PTHREAD_COND_INITIALIZER;
static bool reached_run = false;
static bool allow_run = false;

static void run_after_stop_requested(void);
static int join_after_releasing_run(pthread_t thread, void **result);

// Exercise the production observer, pausing exactly between its startup check
// and entering the run loop. Disposal releases that pause only after requesting
// the stop, immediately before it joins the observer thread.
#define CFRunLoopRun run_after_stop_requested
#define pthread_join join_after_releasing_run
#include "../../native/macos_power_observer.c"
#undef CFRunLoopRun
#undef pthread_join

static void run_after_stop_requested(void) {
  pthread_mutex_lock(&startup_mutex);
  reached_run = true;
  pthread_cond_broadcast(&startup_changed);
  while (!allow_run) pthread_cond_wait(&startup_changed, &startup_mutex);
  pthread_mutex_unlock(&startup_mutex);
  CFRunLoopRun();
}

static int join_after_releasing_run(pthread_t thread, void **result) {
  pthread_mutex_lock(&startup_mutex);
  allow_run = true;
  pthread_cond_broadcast(&startup_changed);
  pthread_mutex_unlock(&startup_mutex);
  return pthread_join(thread, result);
}

static void observe_power(int event, int error_code) {
  if (event == SESORI_FAILED) {
    fprintf(stderr, "Observer registration failed: %d\n", error_code);
    _Exit(2);
  }
}

int main(void) {
  void *observer = sesori_power_observer_start(observe_power);
  if (observer == NULL) return 1;
  pthread_mutex_lock(&startup_mutex);
  while (!reached_run) pthread_cond_wait(&startup_changed, &startup_mutex);
  pthread_mutex_unlock(&startup_mutex);
  sesori_power_observer_stop(observer);
  puts("Observer stopped after disposal preceded run-loop startup");
  return 0;
}
