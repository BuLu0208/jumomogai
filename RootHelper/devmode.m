@import Foundation;

// XPC 函数通过 dlopen/dlsym 动态加载，避免 SDK unavailable 编译错误
typedef NSObject* xpc_object_t;
typedef xpc_object_t xpc_connection_t;
typedef void (^xpc_handler_t)(xpc_object_t object);

static xpc_connection_t (*dy_xpc_connection_create_mach_service)(const char*, dispatch_queue_t, uint64_t);
static void (*dy_xpc_connection_set_event_handler)(xpc_connection_t, xpc_handler_t);
static void (*dy_xpc_connection_resume)(xpc_connection_t);
static xpc_object_t (*dy_xpc_connection_send_message_with_reply_sync)(xpc_connection_t, xpc_object_t);
static xpc_object_t (*dy_xpc_dictionary_get_value)(xpc_object_t, const char*);
static CFTypeRef (*dy_CFXPCCreateCFObjectFromXPCObject)(xpc_object_t);
static xpc_object_t (*dy_CFXPCCreateXPCObjectFromCFObject)(CFTypeRef);
static xpc_object_t (*dy_CFXPCCreateXPCMessageWithCFObject)(CFTypeRef);
static CFTypeRef (*dy_CFXPCCreateCFObjectFromXPCMessage)(xpc_object_t);

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

xpc_connection_t startConnection(void) {
	loadXPCFuncs();
	if (!dy_xpc_connection_create_mach_service) return nil;
	xpc_connection_t connection = dy_xpc_connection_create_mach_service("com.apple.amfi.xpc", NULL, 0);
    if (!connection) return nil;
    if (dy_xpc_connection_set_event_handler) dy_xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {});
    if (dy_xpc_connection_resume) dy_xpc_connection_resume(connection);
    return connection;
}

NSDictionary* sendXPCRequest(xpc_connection_t connection, AMFIXPCAction action) {
	loadXPCFuncs();
	if (!dy_CFXPCCreateXPCMessageWithCFObject || !dy_xpc_connection_send_message_with_reply_sync || !dy_xpc_dictionary_get_value || !dy_CFXPCCreateCFObjectFromXPCMessage) return nil;
    xpc_object_t message = dy_CFXPCCreateXPCMessageWithCFObject((__bridge CFDictionaryRef) @{@"action": @(action)});
    xpc_object_t replyMsg = dy_xpc_connection_send_message_with_reply_sync(connection, message);
    if (!replyMsg) return nil;
    xpc_object_t replyObj = dy_xpc_dictionary_get_value(replyMsg, "cfreply");
    if (!replyObj) return nil;
    return (__bridge NSDictionary*)dy_CFXPCCreateCFObjectFromXPCMessage(replyObj);
}

BOOL getDeveloperModeState(xpc_connection_t connection) {
    NSDictionary* reply = sendXPCRequest(connection, kAMFIActionStatus);
    if (!reply) return NO;
    NSObject* success = reply[@"success"];
    if (!success || ![success isKindOfClass:[NSNumber class]] || ![(NSNumber*)success boolValue]) return NO;
    NSObject* status = reply[@"status"];
    if (!status || ![status isKindOfClass:[NSNumber class]]) return NO;
    return [(NSNumber*)status boolValue];
}

BOOL setDeveloperModeState(xpc_connection_t connection, BOOL enable) {
    NSDictionary* reply = sendXPCRequest(connection, enable ? kAMFIActionArm : kAMFIActionDisable);
    if (!reply) return NO;
    NSObject* success = reply[@"success"];
    if (!success || ![success isKindOfClass:[NSNumber class]] || ![(NSNumber*)success boolValue]) return NO;
    return YES;
}

BOOL checkDeveloperMode(void) {
    if (@available(iOS 16, *)) {
        xpc_connection_t connection = startConnection();
        if (!connection) return NO;
        return getDeveloperModeState(connection);
    } else {
        return YES;
    }
}

BOOL armDeveloperMode(BOOL* alreadyEnabled) {
    if (@available(iOS 16, *)) {
        xpc_connection_t connection = startConnection();
        if (!connection) return NO;
        BOOL enabled = getDeveloperModeState(connection);
        if (alreadyEnabled) *alreadyEnabled = enabled;
        if (enabled) return YES;
        return setDeveloperModeState(connection, YES);
    }
    return YES;
}
