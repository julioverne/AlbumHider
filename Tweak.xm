#import <dlfcn.h>
#import <objc/runtime.h>
#import <notify.h>
#import <substrate.h>
#import <prefs.h>

#define NSLog(...)

@interface PXPhotoKitCollectionsDataSource : NSObject
- (NSArray*)_collectionListBySection;
@end

@interface PHAssetCollection : NSObject
@property (nonatomic,copy) NSString* localIdentifier;
@property (nonatomic,readonly) NSString * localizedTitle;
@end

@interface PHCollectionList : NSObject
@property (nonatomic,readonly) NSArray * collections; 
@end

@interface PUAlbumListViewController : UIViewController
@property (nonatomic,copy) PXPhotoKitCollectionsDataSource* dataSource;
@end

static NSMutableArray* hiddenAlbumIds()
{
	static NSMutableArray* retHiddenAlbumIds;
	if(!retHiddenAlbumIds) {
		retHiddenAlbumIds = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AlbumHider"]?:@[] mutableCopy];
	}
	return retHiddenAlbumIds;
}
static BOOL tmpDisable;

@interface AlbumHiderController : PSListController
@property (nonatomic,assign) PXPhotoKitCollectionsDataSource* dataSource;
+ (id)sharedInstance;
@end



%hook PHCollectionList
- (id)collections
{
	NSArray* ret = %orig;
	if(ret&&!tmpDisable) {
		NSMutableArray* retMut = [NSMutableArray array];
		for(PHAssetCollection* assetCol in ret) {
			if(assetCol.localIdentifier!=nil && [hiddenAlbumIds() containsObject:assetCol.localIdentifier]) {
				continue;
			}
			if(assetCol.localizedTitle!=nil && [hiddenAlbumIds() containsObject:assetCol.localizedTitle]) {
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
		shrd.dataSource = self.dataSource;
		[self.navigationController pushViewController:shrd animated:YES];
	} @catch (NSException * e) {
	}
}
%end






@implementation AlbumHiderController
@synthesize dataSource;
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
		
		tmpDisable = YES;
		for(PHCollectionList* collectionNow in [dataSource _collectionListBySection]) {
			for(PHAssetCollection* assetNow in collectionNow.collections) {
				spec = [PSSpecifier preferenceSpecifierNamed:assetNow.localizedTitle
                                                  target:self
											         set:@selector(setPreferenceValue:specifier:)
											         get:@selector(readPreferenceValue:)
                                                  detail:Nil
											        cell:PSSwitchCell
											        edit:Nil];
				NSString* locIden = assetNow.localIdentifier;
				if([assetNow.localizedTitle isEqualToString:@"PXPhotoKitCollectionsDataSourcePeopleTitle"]) {
					locIden = @"PXPhotoKitCollectionsDataSourcePeopleTitle";
				}
				[spec setProperty:locIden forKey:@"key"];
				[spec setProperty:@NO forKey:@"default"];
				[specifiers addObject:spec];
			}
			spec = [PSSpecifier emptyGroupSpecifier];
			[specifiers addObject:spec];
		}
		tmpDisable = NO;
		
		spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"AlbumHider © 2018 julioverne" forKey:@"footerText"];
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
	
	UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"Apply (Exit)" style:UIBarButtonItemStylePlain target:self action:@selector(apply)];
	self.navigationItem.rightBarButtonItem = anotherButton;
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