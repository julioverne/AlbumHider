#import <dlfcn.h>
#import <objc/runtime.h>
#import <notify.h>
#import <substrate.h>
#import <prefs.h>

#define NSLog(...)

static UIViewController *_topMostController(UIViewController *cont)
{
    UIViewController *topController = cont;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    if ([topController isKindOfClass:[UINavigationController class]]) {
        UIViewController *visible = ((UINavigationController *)topController).visibleViewController;
        if (visible) {
            topController = visible;
        }
    }
    return (topController != cont ? topController : nil);
}
static UIViewController *topMostController()
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *next = nil;
    while ((next = _topMostController(topController)) != nil) {
        topController = next;
    }
    return topController;
}

@interface PXPhotoKitCollectionsDataSource : NSObject
- (NSArray*)_collectionListBySection;
@end

@interface PHAssetCollection : NSObject
@property (nonatomic,copy) NSString* localIdentifier;
@property (nonatomic,readonly) NSString * localizedTitle;
@property (nonatomic,readonly) NSString * localizedSubtitle;
@end

@interface PHCollectionList : NSObject
@property (nonatomic,readonly) NSArray * collections; 
@end

@interface PUAlbumListViewController : UIViewController
@property (nonatomic,copy) PXPhotoKitCollectionsDataSource* dataSource;
@end

static NSMutableDictionary* knownAlbumDic()
{
	static NSMutableDictionary* knownAlbumIds;
	if(!knownAlbumIds) {
		knownAlbumIds = [[NSMutableDictionary alloc] init];
	}
	return knownAlbumIds;
}

static NSMutableArray* hiddenAlbumIds()
{
	static NSMutableArray* retHiddenAlbumIds;
	if(!retHiddenAlbumIds) {
		retHiddenAlbumIds = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AlbumHider"]?:@[] mutableCopy];
	}
	return retHiddenAlbumIds;
}

@interface AlbumHiderController : PSListController
@property (nonatomic,assign) PXPhotoKitCollectionsDataSource* dataSource;
+ (id)sharedInstance;
@end



%hook PHCollectionList
- (id)collections
{
	NSArray* ret = %orig;
	if(ret) {
		NSMutableArray* retMut = [NSMutableArray array];
		for(PHAssetCollection* assetCol in ret) {

			NSString* albumKey = [NSString stringWithFormat:@"%@|||%@", assetCol.localizedSubtitle, assetCol.localizedTitle];
			[knownAlbumDic() setObject:assetCol forKey:albumKey];
			
			if([hiddenAlbumIds() containsObject:albumKey]) {
				continue;
			}
			
			[retMut addObject:assetCol];
		}
		return retMut;
	}
	return ret;
}
%end





%hook PUAlbumListViewController
- (void)setEditing:(BOOL)arg1 animated:(BOOL)arg2
{
	%orig;
	@try {
	BOOL hasButton = NO;
	UIBarButtonItem* nowButtonIf;
	for(UIBarButtonItem* now in self.navigationItem.rightBarButtonItems) {
		if (now.tag == 476) {
			nowButtonIf = now;
			hasButton = YES;
			break;
		}
	}
	if(arg1) {
		if (!hasButton) {
			__strong UIBarButtonItem* kBTLaunch = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(launchAlbumHider)];
			kBTLaunch.tag = 476;
			NSMutableArray* BT = [self.navigationItem.rightBarButtonItems?:[NSArray array] mutableCopy];
			[BT addObject:kBTLaunch];
			self.navigationItem.rightBarButtonItems = [BT copy];
		}
	} else if(nowButtonIf != nil) {
		NSMutableArray* BT = [self.navigationItem.rightBarButtonItems?:[NSArray array] mutableCopy];
		[BT removeObject:nowButtonIf];
		self.navigationItem.rightBarButtonItems = [BT copy];
	}
	} @catch (NSException * e) {
	}
}
%new
- (void)launchAlbumHider
{
	@try {
		AlbumHiderController* shrd = [AlbumHiderController sharedInstance];
		UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:shrd];
		[topMostController() presentViewController:nav animated:YES completion:nil];
	} @catch (NSException * e) {
	}
}
%end






@implementation AlbumHiderController
+ (id)sharedInstance
{
	static AlbumHiderController* AlbumHiderControllerC;
	if(!AlbumHiderControllerC) {
		AlbumHiderControllerC = [[[self class] alloc] init];
	}
	return AlbumHiderControllerC;
}
- (id)specifiers {
	if (!_specifiers) {
		NSMutableArray* specifiers = [NSMutableArray array];
		PSSpecifier* spec;
		
		for(NSString* keyNow in [knownAlbumDic() allKeys]) {
			
			spec = [PSSpecifier preferenceSpecifierNamed:[keyNow componentsSeparatedByString:@"|||"][1]
													target:self
												set:@selector(setPreferenceValue:specifier:)
												get:@selector(readPreferenceValue:)
													detail:Nil
												cell:PSSwitchCell
												edit:Nil];
												
			[spec setProperty:keyNow forKey:@"key"];
			[spec setProperty:@NO forKey:@"default"];
			[specifiers addObject:spec];
		}
		
		spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"AlbumHider © 2020 julioverne" forKey:@"footerText"];
        [specifiers addObject:spec];
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}
- (void)reset
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AlbumHider"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self reloadSpecifiers];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
	@autoreleasepool {
		BOOL enabled = [value boolValue];
		if(enabled) {
			[hiddenAlbumIds() removeObject:[specifier identifier]];
			[hiddenAlbumIds() addObject:[specifier identifier]];
		} else {
			[hiddenAlbumIds() removeObject:[specifier identifier]];
		}
		[[NSUserDefaults standardUserDefaults] setObject:hiddenAlbumIds() forKey:@"AlbumHider"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self reloadSpecifiers];
	}
}
- (id)readPreferenceValue:(PSSpecifier*)specifier
{
	@autoreleasepool {
		if([hiddenAlbumIds() containsObject:[specifier identifier]]) {
			return @YES;
		}
		return @NO;
	}
}
- (void)_returnKeyPressed:(id)arg1
{
	[super _returnKeyPressed:arg1];
	[self.view endEditing:YES];
}
- (void) loadView
{
	[super loadView];
	self.title = @"AlbumHider";
	[UISwitch appearanceWhenContainedIn:self.class, nil].onTintColor = [UIColor colorWithRed:0.09 green:0.99 blue:0.99 alpha:1.0];
	
	UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(close)];
	self.navigationItem.leftBarButtonItem = kBTClose;
	
	UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"Apply (Exit)" style:UIBarButtonItemStylePlain target:self action:@selector(apply)];
	self.navigationItem.rightBarButtonItem = anotherButton;
}
- (void)close
{
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (void)apply
{
	exit(0);
}
- (void)viewWillAppear:(BOOL)arg1
{
	[super viewWillAppear:arg1];
	[self reloadSpecifiers];
}	
@end