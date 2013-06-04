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

#include <dirent.h>
#include <sys/stat.h>
#import <UIKit/UIKit.h>
#import "MPAdView.h"
#import <AdSdk/AdSdk.h>
#import <RevMobAds/RevMobAds.h>
#import "browser.h"
#import "conf/config_file.h"
#import "moreinfo.h"

#define kDOCSFOLDER [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]

typedef enum
{
  AD_PRIORITY_ADSDK = 0,
  AD_PRIORITY_REVMOB,
  AD_MOPUB,
  AD_REVMOB,
  AD_ADSDK,
  AD_NONE, // AD_NONE MUST BE LAST!
} BANNER_AD_TYPE;

BANNER_AD_TYPE currentBannerAd = AD_NONE;

@implementation RADirectoryItem
+ (RADirectoryItem*)directoryItemFromPath:(const char*)thePath
{
   RADirectoryItem* result = [RADirectoryItem new];
   result.path = [NSString stringWithUTF8String:thePath];

   struct stat statbuf;
   if (stat(thePath, &statbuf) == 0)
      result.isDirectory = S_ISDIR(statbuf.st_mode);
   
   return result;
}
@end


BOOL ra_ios_is_file(NSString* path)
{
   return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil];
}

BOOL ra_ios_is_directory(NSString* path)
{
   BOOL result = NO;
   [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&result];
   return result;
}

static NSArray* ra_ios_list_directory(NSString* path)
{
   NSMutableArray* result = [NSMutableArray arrayWithCapacity:27];
   for (int i = 0; i < 27; i ++)
   {
      [result addObject:[NSMutableArray array]];
   }

   // Build list
   char* cpath = malloc([path length] + sizeof(struct dirent));
   sprintf(cpath, "%s/", [path UTF8String]);
   size_t cpath_end = strlen(cpath);

   DIR* dir = opendir(cpath);
   if (!dir)
      return result;
   
   for(struct dirent* item = readdir(dir); item; item = readdir(dir))
   {
      if (strncmp(item->d_name, ".", 1) == 0)
         continue;
      
      cpath[cpath_end] = 0;
      strcat(cpath, item->d_name);

      uint32_t section = isalpha(item->d_name[0]) ? (toupper(item->d_name[0]) - 'A') + 1 : 0;
      [result[section] addObject:[RADirectoryItem directoryItemFromPath:cpath]];
   }
   
   closedir(dir);
   free(cpath);
   
   // Sort
   for (int i = 0; i < result.count; i ++)
      [result[i] sortUsingComparator:^(RADirectoryItem* left, RADirectoryItem* right)
      {
         return (left.isDirectory != right.isDirectory) ?
                (left.isDirectory ? -1 : 1) :
                ([left.path caseInsensitiveCompare:right.path]);
      }];
     
   return result;
}

NSString* ra_ios_check_path(NSString* path)
{
   if (path && ra_ios_is_directory(path))
      return path;

   if (path)
      [RetroArch_iOS displayErrorMessage:@"Browsed path is not a directory."];

   return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
}

@implementation RADirectoryList
{
   NSString* _path;
   NSArray* _list;
}
@synthesize bannerView;
@synthesize listTableView;
@synthesize adView;

+ (id)directoryListForPath:(NSString*)path
{
   path = ra_ios_check_path(path);
   return [[RADirectoryList alloc] initWithPath:path];
}

- (void)loadView
{
  UIView* contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
  [contentView setAutoresizesSubviews:YES];
  [contentView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
  contentView.backgroundColor = [UIColor clearColor];
  [self setView:contentView];
  
  [self.view setAutoresizesSubviews:YES];

  currentBannerAd = 0;
  self.adView = nil;
  self.bannerView = [[AdSdkBannerView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0f, 50.0f)];
  self.bannerView.contentMode = UIViewContentModeScaleToFill;
  [self.bannerView setAutoresizesSubviews:YES];
  [self.bannerView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth)];
  self.bannerView.clipsToBounds = YES;
  if([self.bannerView superview] != self.view)
  {
    [self.view addSubview:self.bannerView];
  }

  [self.view bringSubviewToFront:self.bannerView];
  [self requestBannerAdvert:self];
  
  self.listTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) style:UITableViewStylePlain];
  [self.listTableView setAutoresizesSubviews:YES];
  [self.listTableView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
	UIEdgeInsets insets = UIEdgeInsetsMake(50.0f, 0, 0, 0);
	self.listTableView.contentInset = insets; //something like margin for content;
	self.listTableView.scrollIndicatorInsets = insets; // and for scroll indicator (scroll bar)
  [self.listTableView setDataSource:self];
  [self.listTableView setDelegate:self];
  
  [[self view] addSubview:self.listTableView];
  
  if ([_path compare:kDOCSFOLDER] == NSOrderedSame)
  {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@"More Info"
                                           style:UIBarButtonItemStyleBordered
                                           target:self
                                           action:@selector(showMoreInfo)];
  }
}

- (IBAction)showMoreInfo
{
   [[RetroArch_iOS get] pushViewController:[[RAMoreInfo alloc] init] animated:YES];
}

- (id)initWithPath:(NSString*)path
{
   self = [super init];

   _path = path;
   _list = ra_ios_list_directory(_path);

   [self setTitle: [_path lastPathComponent]];
   
   return self;
}


- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.listTableView reloadData];
}

- (void)viewDidUnload
{
  [super viewDidUnload];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   RADirectoryItem* path = _list[indexPath.section][indexPath.row];

   if(path.isDirectory)
      [[RetroArch_iOS get] pushViewController:[RADirectoryList directoryListForPath:path.path] animated:YES];
   else
      [[RetroArch_iOS get] pushViewController:[[RAModuleList alloc] initWithGame:path.path] animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
   return _list.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
   return [_list[section] count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
   RADirectoryItem* path = _list[indexPath.section][indexPath.row];

   UITableViewCell* cell = [self.listTableView dequeueReusableCellWithIdentifier:@"path"];
   cell = (cell != nil) ? cell : [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"path"];
   cell.textLabel.text = [path.path lastPathComponent];
   cell.accessoryType = (path.isDirectory) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
   cell.imageView.image = [UIImage imageNamed:(path.isDirectory) ? @"ic_dir" : @"ic_file"];
   return cell;
}

- (NSArray*)sectionIndexTitlesForTableView:(UITableView*)tableView
{
   return [NSArray arrayWithObjects:@"#", @"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M",
                                          @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", nil];
}



#pragma mark AdSdk Banner Methods

- (IBAction)requestBannerAdvert:(id)sender
{
  if(currentBannerAd < AD_NONE && self.bannerView != nil)
  {
    self.bannerView.allowDelegateAssigmentToRequestAd = NO;
    self.bannerView.delegate = self;
    self.bannerView.refreshTimerOff = YES;
    self.bannerView.backgroundColor = [UIColor clearColor];
    self.bannerView.refreshAnimation = UIViewAnimationTransitionFlipFromLeft;
    
    self.bannerView.requestURL = @"http://www.appjams.mobi/ads/md.request.php";
    
    [self.bannerView requestAd];
  }
  else
  {
    currentBannerAd = AD_NONE;
    [self.bannerView setHidden:NO];
  }
}

#pragma mark AdSdk Banner Delegate Methods

- (NSString *)publisherIdForAdSdkBannerView:(AdSdkBannerView *)banner
{
  if(currentBannerAd == AD_PRIORITY_ADSDK)
  {
    return @"1910f02e5c6e18aebcf73ec0eea6c64a";
  }
  else if(currentBannerAd == AD_PRIORITY_REVMOB)
  {
    return @"a8d45a60ef42c13037e625a7846a531e";
  }
  else if(currentBannerAd == AD_MOPUB)
  {
    return @"8d1f3858772d4e1f7d60654cced8d744";
  }
  else if(currentBannerAd == AD_REVMOB)
  {
    return @"a975172ce5bcc3ff78e5f01364638725";
  }
  
  // currentBannerAd == AD_ADSDK
  return @"5fcd0cc5498b3dedccc7bdfc9e8450ff";
}

- (void)adsdkBannerViewDidLoadAdSdkAd:(AdSdkBannerView *)banner
{
  if(currentBannerAd == AD_PRIORITY_ADSDK)
  {
    [banner setHidden:NO];
    [self.view bringSubviewToFront:banner];
  }
  else if(currentBannerAd == AD_PRIORITY_REVMOB)
  {
    [banner setHidden:NO];
    RevMobBannerView* revMobBannerView = [[RevMobAds session] bannerView];
    
    [revMobBannerView loadWithSuccessHandler:^(RevMobBannerView* revMobBanner) {
      [revMobBanner setFrame:CGRectMake(0, 0, 320, 50)];
      revMobBanner.contentMode = UIViewContentModeScaleToFill;
      revMobBanner.autoresizesSubviews = YES;
      revMobBanner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
      revMobBanner.clipsToBounds = YES;
      if([revMobBanner superview] != self.view)
      {
        [self.view addSubview:revMobBanner];
      }
      [self.view bringSubviewToFront:revMobBanner];
      [self revmobAdDidReceive];
    } andLoadFailHandler:^(RevMobBannerView* revMobBanner, NSError* error) {
      [self revmobAdDidFailWithError:error];
    } onClickHandler:^(RevMobBannerView* revMobBanner) {
      [self revmobUserClickedInTheAd];
    }];
  }
  else if(currentBannerAd == AD_MOPUB)
  {
    [banner setHidden:NO];
    if(self.adView == nil)
    {
      self.adView = [[MPAdView alloc] initWithAdUnitId:@"a550a4b2cb0811e281c11231392559e4"
                                                  size:MOPUB_BANNER_SIZE];
    }
    
    self.adView.delegate = self;
    self.adView.frame = CGRectMake(0, 0,
                                   MOPUB_BANNER_SIZE.width, MOPUB_BANNER_SIZE.height);
    self.adView.contentMode = UIViewContentModeScaleToFill;
    self.adView.autoresizesSubviews = YES;
    self.adView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.adView.clipsToBounds = YES;
    if([self.adView superview] != self.view)
    {
      [self.view addSubview:self.adView];
    }
    [self.view bringSubviewToFront:self.adView];
    [self.adView loadAd];
  }
  else if(currentBannerAd == AD_REVMOB)
  {
    [banner setHidden:NO];
    RevMobBannerView* revMobBannerView = [[RevMobAds session] bannerView];
    
    [revMobBannerView loadWithSuccessHandler:^(RevMobBannerView* revMobBanner) {
      [revMobBanner setFrame:CGRectMake(0, 0, 320, 50)];
      revMobBanner.contentMode = UIViewContentModeScaleToFill;
      revMobBanner.autoresizesSubviews = YES;
      revMobBanner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
      revMobBanner.clipsToBounds = YES;
      if([revMobBanner superview] != self.view)
      {
        [self.view addSubview:revMobBanner];
      }
      [self.view bringSubviewToFront:revMobBanner];
      [self revmobAdDidReceive];
    } andLoadFailHandler:^(RevMobBannerView* revMobBanner, NSError* error) {
      [self revmobAdDidFailWithError:error];
    } onClickHandler:^(RevMobBannerView* revMobBanner) {
      [self revmobUserClickedInTheAd];
    }];
  }
  else // AD_ADSDK
  {
    [banner setHidden:NO];
    [self.view bringSubviewToFront:banner];
  }
}

- (void)adsdkBannerView:(AdSdkBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
  NSRange r1 = [[error localizedDescription] rangeOfString:@"inventory" options:NSCaseInsensitiveSearch];
  NSRange r2 = [[error localizedDescription] rangeOfString:@"no ad" options:NSCaseInsensitiveSearch];
  if(r1.length > 0 || r2.length > 0)
  {
    currentBannerAd++;
    [self requestBannerAdvert:self];
  }
  else
  {
    currentBannerAd = AD_NONE;
    if(self.bannerView != nil)
    {
      [self.bannerView setHidden:NO];
    }
    RevMobBannerView* revMobBannerView = [[RevMobAds session] bannerView];
    
    [revMobBannerView loadWithSuccessHandler:^(RevMobBannerView* revMobBanner) {
      [revMobBanner setFrame:CGRectMake(0, 0, 320, 50)];
      revMobBanner.contentMode = UIViewContentModeScaleToFill;
      revMobBanner.autoresizesSubviews = YES;
      revMobBanner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
      revMobBanner.clipsToBounds = YES;
      if([revMobBanner superview] != self.view)
      {
        [self.view addSubview:revMobBanner];
      }
      //[revMobBanner sizeToFit];
      [self.view bringSubviewToFront:revMobBanner];
      [self revmobAdDidReceive];
    } andLoadFailHandler:^(RevMobBannerView* revMobBanner, NSError* error) {
      [self revmobAdDidFailWithError:error];
    } onClickHandler:^(RevMobBannerView* revMobBanner) {
      [self revmobUserClickedInTheAd];
    }];
    
  }
}

- (void)adsdkBannerViewDidLoadRefreshedAd:(AdSdkBannerView *)banner
{
  [self adsdkBannerViewDidLoadAdSdkAd:banner];
}

#pragma mark - MoPub delegate methods

- (UIViewController *)viewControllerForPresentingModalView
{
  return self;
}

- (void)adViewDidLoadAd:(MPAdView *)view
{
}

- (void)adViewDidFailToLoadAd:(MPAdView *)view
{
  
  currentBannerAd++;
  [self requestBannerAdvert:self];
}

#pragma mark - RevMobAdsDelegate methods

- (void)revmobAdDidReceive
{
}

- (void)revmobAdDidFailWithError:(NSError *)error
{
  
  if(currentBannerAd == AD_NONE)
  {
    if(self.bannerView != nil)
    {
      [self.bannerView setHidden:NO];
    }
    
    if(self.adView == nil)
    {
      self.adView = [[MPAdView alloc] initWithAdUnitId:@"a550a4b2cb0811e281c11231392559e4"
                                                  size:MOPUB_BANNER_SIZE];
    }
    
    self.adView.delegate = self;
    self.adView.frame = CGRectMake(0, 0,
                                   MOPUB_BANNER_SIZE.width, MOPUB_BANNER_SIZE.height);
    self.adView.contentMode = UIViewContentModeScaleToFill;
    self.adView.autoresizesSubviews = YES;
    self.adView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.adView.clipsToBounds = YES;
    if([self.adView superview] != self.view)
    {
      [self.view addSubview:self.adView];
    }
    //[self.adView sizeToFit];
    [self.view bringSubviewToFront:self.adView];
    [self.adView loadAd];
  }
  else
  {
    currentBannerAd++;
    [self requestBannerAdvert:self];
  }
}

- (void)revmobAdDisplayed
{
}

- (void)revmobUserClosedTheAd
{
  currentBannerAd = AD_NONE;
}

- (void)revmobUserClickedInTheAd
{
  currentBannerAd = AD_NONE;
}

- (void)installDidReceive
{
}

- (void)installDidFail
{
}

@end
