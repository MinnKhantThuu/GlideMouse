#ifndef GLIDEMOUSE_NATIVE_BRIDGE_H
#define GLIDEMOUSE_NATIVE_BRIDGE_H
#include <stdint.h>
#include <stdbool.h>
#define GM_MAX_CONTACTS 16
#define GM_MAX_DEVICES 16
typedef struct { int32_t identity; double x, y, area; } GMContact;
typedef struct { double timestamp; int32_t deviceIndex, count; GMContact contacts[GM_MAX_CONTACTS]; bool overflow; } GMFrame;
typedef struct { int32_t index, family; bool builtIn, opaque, mouseCandidate; } GMDevice;
// ABI is experimental; filtering is deliberately conservative.
bool gm_touch_probe(void);
const char *gm_touch_status(void);
int32_t gm_touch_devices(GMDevice *devices, int32_t capacity);
bool gm_touch_start(int32_t index);
void gm_touch_stop(void);
bool gm_touch_next(GMFrame *frame);
uint64_t gm_touch_dropped(void);
// Each automation command owns a separate process group. Output goes to /dev/null.
int32_t gm_command_spawn(const char *executable, const char *argument, const char *directory, const char *home);
int32_t gm_command_poll(int32_t pid, int32_t *exitStatus);
void gm_command_cancel(int32_t pid, bool force);

#endif
