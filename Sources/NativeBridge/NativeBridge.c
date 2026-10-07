#include "NativeBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <pthread.h>
#include <math.h>
#include <stdatomic.h>
#include <string.h>
// Independently declared private ABI; never exposed to Swift.
typedef struct { float x,y; } GMPrivatePoint;
typedef struct { GMPrivatePoint position,velocity; } Vector;
typedef struct { int32_t frame; double timestamp; int32_t pathIndex,stage,fingerID,handID; Vector normalized; float total,pressure,angle,major,minor; Vector absolute; int32_t f14,f15; float density; } Contact;
_Static_assert(sizeof(Contact) == 96, "Unexpected touch ABI size");
typedef void (*Callback)(void*, Contact*, size_t, double, size_t, void*);
static void *library;
static CFArrayRef list;
static CFArrayRef (*createList)(void);
static void (*registerCB)(void*,Callback,void*);
static int32_t (*startDevice)(void*,int32_t);
static void (*stopDevice)(void*);
static bool (*isBuiltIn)(void*), (*isOpaque)(void*);
static int32_t (*familyID)(void*,int32_t*);
static void *runningDevice;
static int runningIndex;
static _Atomic bool enabled;
static _Atomic uint64_t drops;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static GMFrame ring[128];
static int head, tail;
static const char *status = "Not probed";
static void onFrame(void *device, Contact *data, size_t count, double time, size_t frame, void *ref) {
    (void)device; (void)frame; (void)ref;
    if (!atomic_load(&enabled)) return;
    if (count > GM_MAX_CONTACTS || !isfinite(time) || (count && !data)) { atomic_fetch_add(&drops,1); return; }
    GMFrame f = {0}; f.timestamp = time; f.deviceIndex = runningIndex;
    for (size_t i=0;i<count;i++) {
        Contact *c=&data[i];
        if (c->stage != 3 && c->stage != 4) continue;
        float x=c->normalized.position.x, y=c->normalized.position.y;
        if (!isfinite(x) || !isfinite(y) || x<0 || x>1 || y<0 || y>1 || !isfinite(c->total)) { atomic_fetch_add(&drops,1); return; }
        f.contacts[f.count++] = (GMContact){c->fingerID,x,y,c->total};
    }
    if (pthread_mutex_trylock(&mutex) != 0) { atomic_fetch_add(&drops,1); return; }
    int next=(head+1)%128;
    if (next==tail) { tail=head; f.overflow=true; atomic_fetch_add(&drops,1); }
    ring[head]=f; head=next;
    pthread_mutex_unlock(&mutex);
}
bool gm_touch_probe(void) {
    if (atomic_load(&enabled)) return true;
    if (!library) library=dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",RTLD_NOW|RTLD_LOCAL);
    if (!library) { status="Private framework unavailable"; return false; }
    createList=dlsym(library,"MTDeviceCreateList"); registerCB=dlsym(library,"MTRegisterContactFrameCallbackWithRefcon");
    startDevice=dlsym(library,"MTDeviceStart"); stopDevice=dlsym(library,"MTDeviceStop");
    isBuiltIn=dlsym(library,"MTDeviceIsBuiltIn"); isOpaque=dlsym(library,"MTDeviceIsOpaqueSurface"); familyID=dlsym(library,"MTDeviceGetFamilyID");
    if (!createList || !registerCB || !startDevice || !stopDevice || !isBuiltIn || !familyID || !isOpaque) { status="Required private symbols unavailable"; return false; }
    if (list) { CFRelease(list); list=NULL; }
    list=createList();
    if (!list) { status="No multitouch devices reported"; return false; }
    status="Private ABI loaded; hardware validation required"; return true;
}
const char *gm_touch_status(void) { return status; }
int32_t gm_touch_devices(GMDevice *out,int32_t capacity) {
    if (!list || !out || capacity<=0) return 0;
    int count=(int)CFArrayGetCount(list); if (count>capacity) count=capacity; if (count>GM_MAX_DEVICES) count=GM_MAX_DEVICES;
    for (int i=0;i<count;i++) {
        void *d=(void*)CFArrayGetValueAtIndex(list,i); int32_t family=0; familyID(d,&family); bool built=isBuiltIn(d), opaque=isOpaque(d);
        // Family 112 is the legacy Magic Mouse family. New families require explicit ABI research.
        out[i]=(GMDevice){i,family,built,opaque,!built && family==112};
    }
    return count;
}
bool gm_touch_start(int32_t index) {
    gm_touch_stop();
    GMDevice devices[GM_MAX_DEVICES]; int n=gm_touch_devices(devices,GM_MAX_DEVICES);
    if (index<0 || index>=n || !devices[index].mouseCandidate) { status="Selected device is not a validated Magic Mouse candidate"; return false; }
    runningDevice=(void*)CFArrayGetValueAtIndex(list,index); runningIndex=index;
    registerCB(runningDevice,onFrame,NULL); atomic_store(&enabled,true);
    if (startDevice(runningDevice,0)!=0) { atomic_store(&enabled,false); stopDevice(runningDevice); runningDevice=NULL; status="Touch device refused start"; return false; }
    status="Experimental Magic Mouse touch adapter running"; return true;
}
void gm_touch_stop(void) {
    atomic_store(&enabled,false);
    if (runningDevice && stopDevice) stopDevice(runningDevice);
    runningDevice=NULL;
    pthread_mutex_lock(&mutex); head=tail=0; pthread_mutex_unlock(&mutex);
}
bool gm_touch_next(GMFrame *frame) {
    if (!frame) return false;
    pthread_mutex_lock(&mutex);
    if (head==tail) { pthread_mutex_unlock(&mutex); return false; }
    *frame=ring[tail]; tail=(tail+1)%128; pthread_mutex_unlock(&mutex); return true;
}
uint64_t gm_touch_dropped(void) { return atomic_load(&drops); }
