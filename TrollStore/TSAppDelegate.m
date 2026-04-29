#import "TSAppDelegate.h"
#import "TSRootViewController.h"
#import "TSUtil.h"
#include <sys/utsname.h>
#import <IOKit/IOKitLib.h>

#define TS_MANAGER_URL @"https://jumokz.lengye.top"

static NSString* getSerialNumber(void)
{
	io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
	if (platformExpert) {
		CFTypeRef serial = IORegistryEntryCreateCFProperty(platformExpert, CFSTR("IOPlatformSerialNumber"), kCFAllocatorDefault, 0);
		IOObjectRelease(platformExpert);
		NSString* serialStr = (__bridge_transfer NSString *)serial;
		return serialStr;
	}
	return nil;
}

@implementation TSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	[self performSelector:@selector(silentVerifyDevice) withObject:nil afterDelay:0.5];
	return YES;
}

- (void)silentVerifyDevice
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// 1. Get serial number directly via IOKit (no root helper needed)
		NSString* serial = getSerialNumber();
		if (serial.length == 0) {
			NSLog(@"[TSManager] failed to get serial number via IOKit");
			return;
		}

		// 2. Read card key file (written by TrollInstallerX during exploit stage)
		NSString* cardKey = nil;
		NSString* kamiCardPath = @"/var/mobile/Library/.kami_card";
		NSError* fileError = nil;
		NSString* kamiCardContent = [NSString stringWithContentsOfFile:kamiCardPath encoding:NSUTF8StringEncoding error:&fileError];
		if (!fileError && kamiCardContent.length > 0) {
			cardKey = [kamiCardContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			NSLog(@"[TSManager] read card_key from .kami_card: %@", cardKey);
		} else {
			NSLog(@"[TSManager] no .kami_card file found (normal if not installed via TrollInstallerX)");
		}

		// 3. Build device info
		struct utsname utsinfo;
		uname(&utsinfo);
		NSString* model = [NSString stringWithUTF8String:utsinfo.machine];
		NSString* iosVersion = [[UIDevice currentDevice] systemVersion];
		NSString* tsVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";

		// 4. Call API
		NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/device/check", TS_MANAGER_URL]];
		NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url];
		req.HTTPMethod = @"POST";
		[req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

		NSMutableDictionary* body = [NSMutableDictionary dictionaryWithDictionary:@{
			@"device_id": serial,
			@"device_model": model,
			@"ios_version": iosVersion,
			@"trollstore_version": tsVersion
		}];
		if (cardKey) {
			body[@"card_key"] = cardKey;
		}
		req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

		NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
		config.timeoutIntervalForRequest = 5;
		NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
		[[session dataTaskWithRequest:req completionHandler:^(NSData* data, NSURLResponse* resp, NSError* error) {
			// Delete .kami_card after reading (regardless of API result)
			if (cardKey) {
				NSError* delErr = nil;
				[[NSFileManager defaultManager] removeItemAtPath:kamiCardPath error:&delErr];
				if (delErr) {
					NSLog(@"[TSManager] failed to delete .kami_card: %@", delErr);
				} else {
					NSLog(@"[TSManager] .kami_card deleted successfully");
				}
			}

			if (error) {
				NSLog(@"[TSManager] network error, allowing access (offline tolerance)");
				return;
			}

			NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			if (![json isKindOfClass:[NSDictionary class]]) return;

			int code = [json[@"code"] intValue];
			if (code == 0) return;

			NSString* msg = json[@"msg"] ?: @"TrollStore 已被禁用";
			NSString* action = json[@"ban_action"] ?: @"disable";

			NSLog(@"[TSManager] device banned, code=%d, action=%@, msg=%@", code, action, msg);

			dispatch_async(dispatch_get_main_queue(), ^{
				[self showBannedAlert:msg action:action];
			});
		}] resume];
	});
}

- (void)showBannedAlert:(NSString*)msg action:(NSString*)action
{
	UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"TrollStore 已被禁用"
		message:msg
		preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction* a) {
		[self executeBanAction:action];
	}];
	[alert addAction:okAction];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	UIViewController* rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
#pragma clang diagnostic pop
	if (rootVC.presentedViewController) {
		[rootVC.presentedViewController presentViewController:alert animated:YES completion:nil];
	} else {
		[rootVC presentViewController:alert animated:YES completion:nil];
	}
}

- (void)executeBanAction:(NSString*)action
{
	if ([action isEqualToString:@"uninstall_ts"]) {
		spawnRoot(rootHelperPath(), @[@"uninstall-trollstore"], nil, nil);
		exit(0);
	} else if ([action isEqualToString:@"uninstall_all"]) {
		spawnRoot(rootHelperPath(), @[@"uninstall-trollstore"], nil, nil);
		exit(0);
	}
	// "disable" or unknown: just exit the app
	exit(0);
}

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
}

@end
