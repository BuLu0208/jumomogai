#import "TSAppDelegate.h"
#import "TSRootViewController.h"
#import "TSUtil.h"
#include <sys/utsname.h>

#define TS_MANAGER_URL @"https://trollstore-manager.etlatmaz.workers.dev"

@implementation TSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	[self performSelector:@selector(silentVerifyDevice) withObject:nil afterDelay:0.5];
	return YES;
}

- (void)silentVerifyDevice
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// 1. Get serial number from root helper
		NSString* stdOut = nil;
		int ret = spawnRoot(rootHelperPath(), @[@"get-serial-number"], &stdOut, nil);
		NSString* serial = [stdOut stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (ret != 0 || serial.length == 0) {
			NSLog(@"[TSManager] failed to get serial number, ret=%d", ret);
			return;
		}

		// 2. Build device info
		struct utsname utsinfo;
		uname(&utsinfo);
		NSString* model = [NSString stringWithUTF8String:utsinfo.machine];
		NSString* iosVersion = [[UIDevice currentDevice] systemVersion];
		NSString* tsVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";

		// 3. Call API
		NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/device/check", TS_MANAGER_URL]];
		NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url];
		req.HTTPMethod = @"POST";
		[req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

		NSDictionary* body = @{
			@"device_id": serial,
			@"device_model": model,
			@"ios_version": iosVersion,
			@"trollstore_version": tsVersion
		};
		req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

		NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
		config.timeoutIntervalForRequest = 5;
		NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
		[[session dataTaskWithRequest:req completionHandler:^(NSData* data, NSURLResponse* resp, NSError* error) {
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

	UIViewController* rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
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
