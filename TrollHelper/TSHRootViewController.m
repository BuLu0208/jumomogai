#import "TSHRootViewController.h"
#import <TSUtil.h>
#import <TSPresentationDelegate.h>

// ========== 卡密验证系统 ==========
#define KAMI_API_URL @"https://kami.lengye.top"
#define KAMI_APPKEY @"9VRZ0ATE1YKM"
#define KAMI_ACTIVATED @"kami_activated"

@interface TSHRootViewController ()
@property (nonatomic) BOOL cardVerified;
@property (nonatomic, copy) NSString* cardNotice;
@property (nonatomic) BOOL configLoaded;
@end

@implementation TSHRootViewController

- (BOOL)isTrollStore
{
	return NO;
}

- (NSString*)getDeviceId
{
	return [[UIDevice currentDevice] identifierForVendor].UUIDString;
}

- (BOOL)isActivated
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:KAMI_ACTIVATED];
}

- (void)markActivated
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:KAMI_ACTIVATED];
	_cardVerified = YES;
	_specifiers = nil;
	[self reloadSpecifiers];
}

- (void)fetchConfig
{
	NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/config?appkey=%@", KAMI_API_URL, KAMI_APPKEY]];
	NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
	config.timeoutIntervalForRequest = 10;
	NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
	[[session dataTaskWithURL:url completionHandler:^(NSData* data, NSURLResponse* response, NSError* error)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (!error && data)
			{
				NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
				if ([json isKindOfClass:[NSDictionary class]] && [json[@"code"] intValue] == 0)
				{
					NSDictionary* d = json[@"data"];
					_cardNotice = d[@"notice"];
				}
			}
			_configLoaded = YES;
			[self reloadSpecifiers];
		});
	}] resume];
}

- (void)verifyCard:(NSString*)card completion:(void(^)(BOOL success, NSString* message))completion
{
	NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/login", KAMI_API_URL]];
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
	request.HTTPMethod = @"POST";
	[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

	NSDictionary* body = @{@"appkey": KAMI_APPKEY, @"card": card, @"device_id": [self getDeviceId]};
	request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

	NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
	config.timeoutIntervalForRequest = 10;
	NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
	[[session dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (error)
			{
				if (completion) completion(NO, @"网络错误，请检查网络连接");
				return;
			}
			NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			if (![json isKindOfClass:[NSDictionary class]])
			{
				if (completion) completion(NO, @"服务器响应异常");
				return;
			}
			int code = [json[@"code"] intValue];
			NSString* msg = json[@"msg"];
			if (code == 0)
			{
				[self markActivated];
				if (completion) completion(YES, nil);
			}
			else if (code == 1001)
			{
				if (completion) completion(NO, @"设备不匹配，请先解绑后再验证");
			}
			else if (code == 1002)
			{
				if (completion) completion(NO, @"卡密已过期，请续费或购买新卡密");
			}
			else
			{
				NSString* errMsg = msg ?: @"验证失败";
				if ([errMsg isEqualToString:@"卡密不存在"])
					errMsg = @"卡密无效，请检查后重试";
				else if ([errMsg isEqualToString:@"卡密已禁用"])
					errMsg = @"卡密已被禁用，请联系管理员";
				else if ([errMsg isEqualToString:@"卡密已使用"])
					errMsg = @"此卡密已使用，请获取新卡密";
				if (completion) completion(NO, errMsg);
			}
		});
	}] resume];
}

- (void)unbindCard:(NSString*)card completion:(void(^)(BOOL success, NSString* message))completion
{
	NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/unbind", KAMI_API_URL]];
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
	request.HTTPMethod = @"POST";
	[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

	NSDictionary* body = @{@"appkey": KAMI_APPKEY, @"card": card};
	request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

	NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
	config.timeoutIntervalForRequest = 10;
	NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
	[[session dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (error)
			{
				if (completion) completion(NO, @"网络错误，请检查网络连接");
				return;
			}
			NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			if ([json isKindOfClass:[NSDictionary class]] && [json[@"code"] intValue] == 0)
			{
				int remaining = [json[@"data"][@"remaining_unbind"] intValue];
				if (completion) completion(YES, [NSString stringWithFormat:@"解绑成功，剩余解绑次数：%d", remaining]);
			}
			else
			{
				NSString* msg = [json isKindOfClass:[NSDictionary class]] ? json[@"msg"] : @"解绑失败";
				if (completion) completion(NO, msg);
			}
		});
	}] resume];
}

- (void)showCardInputAlert
{
	UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"验证卡密"
		message:@"请输入卡密以激活 TrollStore 助手"
		preferredStyle:UIAlertControllerStyleAlert];

	[alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = @"请输入卡密";
		textField.keyboardType = UIKeyboardTypeDefault;
		textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		textField.autocorrectionType = UITextAutocorrectionTypeNo;
	}];

	UIAlertAction* verifyAction = [UIAlertAction actionWithTitle:@"验证" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
	{
		NSString* card = alert.textFields.firstObject.text;
		if (card.length == 0) return;
		[self verifyCard:card completion:^(BOOL success, NSString* message) {
			if (!success)
			{
				UIAlertController* errAlert = [UIAlertController alertControllerWithTitle:@"验证失败"
					message:message preferredStyle:UIAlertControllerStyleAlert];
				[errAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
				[TSPresentationDelegate presentViewController:errAlert animated:YES completion:nil];
			}
		}];
	}];
	[alert addAction:verifyAction];

	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
	[alert addAction:cancelAction];

	[TSPresentationDelegate presentViewController:alert animated:YES completion:nil];
}

- (void)openPurchasePage
{
	NSURL* url = [NSURL URLWithString:@"https://www.820faka.cn/details/180476F2"];
	[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	TSPresentationDelegate.presentationViewController = self;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSpecifiers) name:UIApplicationWillEnterForegroundNotification object:nil];

	// 加载卡密配置和公告
	_cardVerified = [self isActivated];
	[self fetchConfig];

	fetchLatestTrollStoreVersion(^(NSString* latestVersion)
	{
		NSString* currentVersion = [self getTrollStoreVersion];
		NSComparisonResult result = [currentVersion compare:latestVersion options:NSNumericSearch];
		if(result == NSOrderedAscending)
		{
			_newerVersion = latestVersion;
			dispatch_async(dispatch_get_main_queue(), ^
			{
				[self reloadSpecifiers];
			});
		}
	});
}

- (NSMutableArray*)specifiers
{
	if(!_specifiers)
	{
		_specifiers = [NSMutableArray new];

		#ifdef LEGACY_CT_BUG
		NSString* credits = @"Powered by Fugu15 CoreTrust & installd bugs\n\n修改自 opa334 的 TrollStore\n\n冷夜 | 微信: BuLu-0208";
		#else
		NSString* credits = @"Powered by CVE-2023-41991\n\n修改自 opa334 的 TrollStore\n\n冷夜 | 微信: BuLu-0208";
		#endif

		// ========== 卡密验证区域 ==========
		PSSpecifier* cardGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
		cardGroupSpecifier.name = @"卡密验证";

		if (_cardVerified)
		{
			[cardGroupSpecifier setProperty:@"已激活" forKey:@"footerText"];

			PSSpecifier* cardInfoSpecifier = [PSSpecifier preferenceSpecifierNamed:@"✅ 卡密已激活"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSStaticTextCell
											edit:nil];
			[cardInfoSpecifier setProperty:@NO forKey:@"enabled"];
			[_specifiers addObject:cardGroupSpecifier];
			[_specifiers addObject:cardInfoSpecifier];

			PSSpecifier* purchaseSpecifier = [PSSpecifier preferenceSpecifierNamed:@"购买卡密"
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSButtonCell
												edit:nil];
			purchaseSpecifier.identifier = @"purchaseCard";
			[purchaseSpecifier setProperty:@YES forKey:@"enabled"];
			purchaseSpecifier.buttonAction = @selector(openPurchasePage);
			[_specifiers addObject:purchaseSpecifier];
		}
		else
		{
			NSString* footerText = @"请输入卡密激活后使用 TrollStore 助手功能";
			if (_cardNotice.length > 0)
			{
				footerText = [NSString stringWithFormat:@"📢 %@\n\n%@", _cardNotice, footerText];
			}
			[cardGroupSpecifier setProperty:footerText forKey:@"footerText"];

			PSSpecifier* cardVerifySpecifier = [PSSpecifier preferenceSpecifierNamed:@"验证卡密"
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSButtonCell
												edit:nil];
			cardVerifySpecifier.identifier = @"verifyCard";
			[cardVerifySpecifier setProperty:@YES forKey:@"enabled"];
			cardVerifySpecifier.buttonAction = @selector(showCardInputAlert);
			[_specifiers addObject:cardGroupSpecifier];
			[_specifiers addObject:cardVerifySpecifier];

			PSSpecifier* purchaseSpecifier = [PSSpecifier preferenceSpecifierNamed:@"购买卡密"
												target:self
												set:nil
												get:nil
												detail:nil
												cell:PSButtonCell
												edit:nil];
			purchaseSpecifier.identifier = @"purchaseCard";
			[purchaseSpecifier setProperty:@YES forKey:@"enabled"];
			purchaseSpecifier.buttonAction = @selector(openPurchasePage);
			[_specifiers addObject:purchaseSpecifier];
		}

		// ========== 以下功能仅在验证通过后显示 ==========
		if (!_cardVerified)
		{
			// 未验证时不显示 TrollStore 功能
			PSSpecifier* lockGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
			[lockGroupSpecifier setProperty:@"验证卡密后即可使用 TrollStore 安装和管理功能。" forKey:@"footerText"];
			[_specifiers addObject:lockGroupSpecifier];
		}
		else
		{
			// 已验证，显示正常功能
			PSSpecifier* infoGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
			infoGroupSpecifier.name = @"信息";
			[_specifiers addObject:infoGroupSpecifier];

			PSSpecifier* infoSpecifier = [PSSpecifier preferenceSpecifierNamed:@"TrollStore"
												target:self
												set:nil
												get:@selector(getTrollStoreInfoString)
												detail:nil
												cell:PSTitleValueCell
												edit:nil];
			infoSpecifier.identifier = @"info";
			[infoSpecifier setProperty:@YES forKey:@"enabled"];

			[_specifiers addObject:infoSpecifier];

			BOOL isInstalled = trollStoreAppPath();

			if(_newerVersion && isInstalled)
			{
				PSSpecifier* updateTrollStoreSpecifier = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"更新 TrollStore 到 %@", _newerVersion]
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSButtonCell
											edit:nil];
				updateTrollStoreSpecifier.identifier = @"updateTrollStore";
				[updateTrollStoreSpecifier setProperty:@YES forKey:@"enabled"];
				updateTrollStoreSpecifier.buttonAction = @selector(updateTrollStorePressed);
				[_specifiers addObject:updateTrollStoreSpecifier];
			}

			PSSpecifier* lastGroupSpecifier;

			PSSpecifier* utilitiesGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
			[_specifiers addObject:utilitiesGroupSpecifier];

			lastGroupSpecifier = utilitiesGroupSpecifier;

			if(isInstalled || trollStoreInstalledAppContainerPaths().count)
			{
				PSSpecifier* refreshAppRegistrationsSpecifier = [PSSpecifier preferenceSpecifierNamed:@"刷新应用注册"
													target:self
													set:nil
													get:nil
													detail:nil
													cell:PSButtonCell
													edit:nil];
				refreshAppRegistrationsSpecifier.identifier = @"refreshAppRegistrations";
				[refreshAppRegistrationsSpecifier setProperty:@YES forKey:@"enabled"];
				refreshAppRegistrationsSpecifier.buttonAction = @selector(refreshAppRegistrationsPressed);
				[_specifiers addObject:refreshAppRegistrationsSpecifier];
			}
			if(isInstalled)
			{
				PSSpecifier* uninstallTrollStoreSpecifier = [PSSpecifier preferenceSpecifierNamed:@"卸载 TrollStore"
											target:self
											set:nil
											get:nil
											detail:nil
											cell:PSButtonCell
											edit:nil];
				uninstallTrollStoreSpecifier.identifier = @"uninstallTrollStore";
				[uninstallTrollStoreSpecifier setProperty:@YES forKey:@"enabled"];
				[uninstallTrollStoreSpecifier setProperty:NSClassFromString(@"PSDeleteButtonCell") forKey:@"cellClass"];
				uninstallTrollStoreSpecifier.buttonAction = @selector(uninstallTrollStorePressed);
				[_specifiers addObject:uninstallTrollStoreSpecifier];
			}
			else
			{
				PSSpecifier* installTrollStoreSpecifier = [PSSpecifier preferenceSpecifierNamed:@"安装 TrollStore"
													target:self
													set:nil
													get:nil
													detail:nil
													cell:PSButtonCell
													edit:nil];
				installTrollStoreSpecifier.identifier = @"installTrollStore";
				[installTrollStoreSpecifier setProperty:@YES forKey:@"enabled"];
				installTrollStoreSpecifier.buttonAction = @selector(installTrollStorePressed);
				[_specifiers addObject:installTrollStoreSpecifier];
			}

			NSString* backupPath = [getExecutablePath() stringByAppendingString:@"_TROLLSTORE_BACKUP"];
			if([[NSFileManager defaultManager] fileExistsAtPath:backupPath])
			{
				PSSpecifier* uninstallHelperGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
				[_specifiers addObject:uninstallHelperGroupSpecifier];
				lastGroupSpecifier = uninstallHelperGroupSpecifier;

				PSSpecifier* uninstallPersistenceHelperSpecifier = [PSSpecifier preferenceSpecifierNamed:@"卸载持久化助手"
													target:self
													set:nil
													get:nil
													detail:nil
													cell:PSButtonCell
													edit:nil];
				uninstallPersistenceHelperSpecifier.identifier = @"uninstallPersistenceHelper";
				[uninstallPersistenceHelperSpecifier setProperty:@YES forKey:@"enabled"];
				[uninstallPersistenceHelperSpecifier setProperty:NSClassFromString(@"PSDeleteButtonCell") forKey:@"cellClass"];
				uninstallPersistenceHelperSpecifier.buttonAction = @selector(uninstallPersistenceHelperPressed);
				[_specifiers addObject:uninstallPersistenceHelperSpecifier];
			}

			#ifdef EMBEDDED_ROOT_HELPER
			LSApplicationProxy* persistenceHelperProxy = findPersistenceHelperApp(PERSISTENCE_HELPER_TYPE_ALL);
			BOOL isRegistered = [persistenceHelperProxy.bundleIdentifier isEqualToString:NSBundle.mainBundle.bundleIdentifier];

			if((isRegistered || !persistenceHelperProxy) && ![[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/TrollStorePersistenceHelper.app"])
			{
				PSSpecifier* registerUnregisterGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
				lastGroupSpecifier = nil;

				NSString* bottomText;
				PSSpecifier* registerUnregisterSpecifier;

				if(isRegistered)
				{
					bottomText = @"此应用已注册为 TrollStore 持久化助手，可用于在应用注册回退到\"用户\"状态时修复 TrollStore 应用注册。";
					registerUnregisterSpecifier = [PSSpecifier preferenceSpecifierNamed:@"注销持久化助手"
													target:self
													set:nil
													get:nil
													detail:nil
													cell:PSButtonCell
													edit:nil];
					registerUnregisterSpecifier.identifier = @"registerUnregisterSpecifier";
					[registerUnregisterSpecifier setProperty:@YES forKey:@"enabled"];
					[registerUnregisterSpecifier setProperty:NSClassFromString(@"PSDeleteButtonCell") forKey:@"cellClass"];
					registerUnregisterSpecifier.buttonAction = @selector(unregisterPersistenceHelperPressed);
				}
				else if(!persistenceHelperProxy)
				{
					bottomText = @"如果您想将此应用用作 TrollStore 持久化助手，可以在此注册。";
					registerUnregisterSpecifier = [PSSpecifier preferenceSpecifierNamed:@"注册持久化助手"
													target:self
													set:nil
													get:nil
													detail:nil
													cell:PSButtonCell
													edit:nil];
					registerUnregisterSpecifier.identifier = @"registerUnregisterSpecifier";
					[registerUnregisterSpecifier setProperty:@YES forKey:@"enabled"];
					registerUnregisterSpecifier.buttonAction = @selector(registerPersistenceHelperPressed);
				}

				[registerUnregisterGroupSpecifier setProperty:[NSString stringWithFormat:@"%@\n\n%@", bottomText, credits] forKey:@"footerText"];
				lastGroupSpecifier = nil;

				[_specifiers addObject:registerUnregisterGroupSpecifier];
				[_specifiers addObject:registerUnregisterSpecifier];
			}
			#endif

			if(lastGroupSpecifier)
			{
				[lastGroupSpecifier setProperty:credits forKey:@"footerText"];
			}
		}
	}

	[(UINavigationItem *)self.navigationItem setTitle:@"TrollStore 助手"];
	return _specifiers;
}

- (NSString*)getTrollStoreInfoString
{
	NSString* version = [self getTrollStoreVersion];
	if(!version)
	{
		return @"未安装";
	}
	else
	{
		return [NSString stringWithFormat:@"已安装, %@", version];
	}
}

- (void)handleUninstallation
{
	_newerVersion = nil;
	[super handleUninstallation];
}

- (void)registerPersistenceHelperPressed
{
	int ret = spawnRoot(rootHelperPath(), @[@"register-user-persistence-helper", NSBundle.mainBundle.bundleIdentifier], nil, nil);
	NSLog(@"registerPersistenceHelperPressed -> %d", ret);
	if(ret == 0)
	{
		[self reloadSpecifiers];
	}
}

- (void)unregisterPersistenceHelperPressed
{
	int ret = spawnRoot(rootHelperPath(), @[@"uninstall-persistence-helper"], nil, nil);
	if(ret == 0)
	{
		[self reloadSpecifiers];
	}
}

@end
