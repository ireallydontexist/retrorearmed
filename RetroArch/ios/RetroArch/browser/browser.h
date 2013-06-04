/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2013 - Jason Fetters
 * 
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#import "MPAdView.h"
#import <AdSdk/AdSdk.h>
#import <RevMobAds/RevMobAds.h>
#import "MPInterstitialAdController.h"

extern BOOL ra_ios_is_directory(NSString* path);
extern BOOL ra_ios_is_file(NSString* path);
extern NSString* ra_ios_check_path(NSString* path);

@interface RADirectoryItem : NSObject
@property (strong) NSString* path;
@property bool isDirectory;
@end

@interface RADirectoryList : UIViewController <AdSdkBannerViewDelegate, MPAdViewDelegate, RevMobAdsDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, retain) MPAdView* adView;
@property (strong, nonatomic) IBOutlet AdSdkBannerView* bannerView;
@property (nonatomic, strong) IBOutlet UITableView* listTableView;
+ (id)directoryListForPath:(NSString*)path;
- (id)initWithPath:(NSString*)path;
- (IBAction)showMoreInfo;
@end

@interface RAModuleList : UITableViewController <AdSdkVideoInterstitialViewControllerDelegate, MPInterstitialAdControllerDelegate, RevMobAdsDelegate>
@property (strong, nonatomic) AdSdkVideoInterstitialViewController* videoInterstitialViewController;
@property (nonatomic, retain) MPInterstitialAdController* interstitial;
@property (nonatomic, retain) NSTimer* adTimer;
@property (strong, nonatomic) RAModuleInfo* gameModule;
- (id)initWithGame:(NSString*)path;
- (IBAction)requestInterstitialAdvert:(id)sender;
- (void)runGame;
@end
