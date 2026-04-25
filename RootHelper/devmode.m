#import <Foundation/Foundation.h>

// 手动声明 dlopen/dlsym，避免 SDK 不可用标记和模块导入问题
#define _DARWIN_USE_64_BIT_INODE 0
#include <dlfcn.h>
#undef _DARWIN_USE_64_BIT_INODE

#ifndef RTLD_LAZY
#define RTLD_LAZY 1
#endif

extern void *dlopen(const char *, int) __attribute__((weak_import));
extern void *dlsym(void *, const char *) __attribute__((weak_import));

// XPC 函数通过 dlsym 动态加载，不依赖 SDK 声明
static void * (*dy_xpc_connection_create_mach_service)(const char*, void*, unsigned long long);
static void (*dy_xpc_connection_set_event_handler)(void*, void (^)(void *));
static void (*dy_xpc_connection_resume)(void *);
static void * (*dy_xpc_connection_send_message_with_reply_sync)(void *, void *);
static void * (*dy_xpc_dictionary_get_value)(void *, const char *);
static void * (*dy_CFXPCCreateCFObjectFromXPCObject)(void *);
static void * (*dy_CFXPCCreateXPCObjectFromCFObject)(const void *);
static void * (*dy_CFXPCCreateXPCMessageWithCFObject)(const void *);
static void * (*dy_CFXPCCreateCFObjectFromXPCMessage)(void *);

static BOOL xpc_funcs_loaded = NO;
static void loadXPCFuncs(void) {
	if (xpc_funcs_loaded) return;
	xpc_funcs_loaded = YES;
	void *lib = dlopen("/usr/lib/libSystem.B.dylib", RTLD_LAZY);
	if (!lib) return;
	dy_xpc_connection_create_mach_service = dlsym(lib, "xpc_connection_create_mach_service");
	dy_xpc_connection_set_event_handler = dlsym(lib, "xpc_connection_set_event_handler");
	dy_xpc_connection_resume = dlsym(lib, "xpc_connection_resume");
	dy_xpc_connection_send_message_with_reply_sync = dlsym(lib, "xpc_connection_send_message_with_reply_sync");
	dy_xpc_dictionary_get_value = dlsym(lib, "xpc_dictionary_get_value");
	dy_CFXPCCreateCFObjectFromXPCObject = dlsym(lib, "_CFXPCCreateCFObjectFromXPCObject");
	dy_CFXPCCreateXPCObjectFromCFObject = dlsym(lib, "_CFXPCCreateXPCObjectFromCFObject");
	dy_CFXPCCreateXPCMessageWithCFObject = dlsym(lib, "_CFXPCCreateXPCMessageWithCFObject");
	dy_CFXPCCreateCFObjectFromXPCMessage = dlsym(lib, "_CFXPCCreateCFObjectFromXPCMessage");
}

typedef enum {
    kAMFIActionArm = 0,
    kAMFIActionDisable = 1,
    kAMFIActionStatus = 2,
} AMFIXPCAction;

static void* startConnection(void) {
	loadXPCFuncs();
	if (!dy_xpc_connection_create_mach_service) return NULL;
	void *connection = dy_xpc_connection_create_mach_service("com.apple.amfi.xpc", NULL, 0);
    if (!connection) return NULL;
    if (dy_xpc_connection_set_event_handler) dy_xpc_connection_set_event_handler(connection, ^(void *event) {});
    if (dy_xpc_connection_resume) dy_xpc_connection_resume(connection);
    return connection;
}

static NSDictionary* sendXPCRequest(void *connection, AMFIXPCAction action) {
	loadXPCFuncs();
	if (!dy_CFXPCCreateXPCMessageWithCFObject || !dy_xpc_connection_send_message_with_reply_sync || !dy_xpc_dictionary_get_value || !dy_CFXPCCreateCFObjectFromXPCMessage) return nil;
	void *message = dy_CFXPCCreateXPCMessageWithCFObject((__bridge CFDictionaryRef) @{@"action": @(action)});
	void *replyMsg = dy_xpc_connection_send_message_with_reply_sync(connection, message);
    if (!replyMsg) return nil;
    void *replyObj = dy_xpc_dictionary_get_value(replyMsg, "cfreply");
    if (!replyObj) return nil;
    return (__bridge NSDictionary*)dy_CFXPCCreateCFObjectFromXPCMessage(replyObj);
}

static BOOL getDeveloperModeState(void *connection) {
    NSDictionary* reply = sendXPCRequest(connection, kAMFIActionStatus);
    if (!reply) return NO;
    NSObject* success = reply[@"success"];
    if (!success || ![success isKindOfClass:[NSNumber class]] || ![(NSNumber*)success boolValue]) return NO;
    NSObject* status = reply[@"status"];
    if (!status || ![status isKindOfClass:[NSNumber class]]) return NO;
    return [(NSNumber*)status boolValue];
}

static BOOL setDeveloperModeState(void *connection, BOOL enable) {
    NSDictionary* reply = sendXPCRequest(connection, enable ? kAMFIActionArm : kAMFIActionDisable);
    if (!reply) return NO;
    NSObject* success = reply[@"success"];
    if (!success || ![success isKindOfClass:[NSNumber class]] || ![(NSNumber*)success boolValue]) return NO;
    return YES;
}

BOOL checkDeveloperMode(void) {
    if (@available(iOS 16, *)) {
        void *connection = startConnection();
        if (!connection) return NO;
        return getDeveloperModeState(connection);
    } else {
        return YES;
    }
}

BOOL armDeveloperMode(BOOL* alreadyEnabled) {
    if (@available(iOS 16, *)) {
        void *connection = startConnection();
        if (!connection) return NO;
        BOOL enabled = getDeveloperModeState(connection);
        if (alreadyEnabled) *alreadyEnabled = enabled;
        if (enabled) return YES;
        return setDeveloperModeState(connection, YES);
    }
    return YES;
}
