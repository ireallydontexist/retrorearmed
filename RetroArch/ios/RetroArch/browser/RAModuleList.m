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

#import <UIKit/UIKit.h>
#import <AdSdk/AdSdk.h>
#import <RevMobAds/RevMobAds.h>
#import "MPInterstitialAdController.h"
#import "RAMOduleInfo.h"
#import "browser.h"
#import "settings.h"

typedef enum
{
  AD_PRIORITY_ADSDK = 0,
  AD_PRIORITY_REVMOB,
  AD_MOPUB,
  AD_REVMOB,
  AD_ADSDK,
  AD_NONE, // AD_NONE MUST BE LAST!
} FULLSCREEN_AD_TYPE;

FULLSCREEN_AD_TYPE currentFullscreenAd = AD_NONE;


@implementation RAModuleList
{
   NSMutableArray* _supported;
   NSMutableArray* _other;

   NSString* _game;
}
@synthesize videoInterstitialViewController;
@synthesize adTimer;
@synthesize interstitial;

- (id)initWithGame:(NSString*)path
{
   self = [super initWithStyle:UITableViewStyleGrouped];
   [self setTitle:[path lastPathComponent]];
   
   _game = path;

   //
   NSArray* moduleList = [RAModuleInfo getModules];
   
   if (moduleList.count == 0)
      [RetroArch_iOS displayErrorMessage:@"No libretro cores were found."];

   // Load the modules with their data
   _supported = [NSMutableArray array];
   _other = [NSMutableArray array];
   
   for (RAModuleInfo* i in moduleList)
   {
      NSMutableArray* target = [i supportsFileAtPath:_game] ? _supported : _other;
      [target addObject:i];
   }

   // No sort, [RAModuleInfo getModules] is already sorted by display name

   return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
}

- (void)viewDidUnload
{
  [super viewDidUnload];
}

- (void)runGame
{
  [self.view setUserInteractionEnabled:YES];
  currentFullscreenAd = 0;
  if(self.interstitial != nil)
  {
    self.interstitial = nil;
  }
  if(self.videoInterstitialViewController != nil)
  {
    if(self.videoInterstitialViewController.view != nil)
    {
      [self.videoInterstitialViewController.view removeFromSuperview];
    }
    self.videoInterstitialViewController = nil;
  }
  
  [RetroArch_iOS.get runGame:_game withModule:self.gameModule];
}

- (RAModuleInfo*)moduleInfoForIndexPath:(NSIndexPath*)path
{
   NSMutableArray* sectionData = (_supported.count && path.section == 0) ? _supported : _other;
   return (RAModuleInfo*)sectionData[path.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
   return _supported.count ? 2 : 1;
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section
{
   if (_supported.count)
      return (section == 0) ? @"Suggested Cores" : @"Other Cores";

   return @"All Cores";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
   NSMutableArray* sectionData = (_supported.count && section == 0) ? _supported : _other;
   return sectionData.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   currentFullscreenAd = 0;
   self.videoInterstitialViewController = [[AdSdkVideoInterstitialViewController alloc] init];
   self.videoInterstitialViewController.delegate = self;
   self.interstitial = nil;
   [self.view addSubview:self.videoInterstitialViewController.view];
   [self.view setUserInteractionEnabled:NO];
   self.gameModule = [self moduleInfoForIndexPath:indexPath];
   [self requestInterstitialAdvert:self];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
   [RetroArch_iOS.get pushViewController:[[RAModuleInfoList alloc] initWithModuleInfo:[self moduleInfoForIndexPath:indexPath]] animated:YES];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
   UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"module"];
   cell = (cell) ? cell : [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"module"];

   RAModuleInfo* info = [self moduleInfoForIndexPath:indexPath];

   cell.textLabel.text = info.displayName;
   cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

   return cell;
}

#pragma mark AdSdk Interstitial Methods

- (void)adTimedOut
{
  self.adTimer = nil;
  [self.videoInterstitialViewController.view setHidden:YES];
  currentFullscreenAd = AD_NONE;
  [self runGame];
}

- (IBAction)requestInterstitialAdvert:(id)sender
{
  if(currentFullscreenAd < AD_NONE && self.videoInterstitialViewController != nil)
  {
    self.videoInterstitialViewController.requestURL = @"http://www.appjams.mobi/ads/md.request.php";
    self.adTimer = [NSTimer scheduledTimerWithTimeInterval:12.0 target:self selector:@selector(adTimedOut) userInfo:nil repeats:NO];
    [self.videoInterstitialViewController requestAd];
  }
  else
  {
    currentFullscreenAd = AD_NONE;
    [self runGame];
  }
}

#pragma mark AdSdk Interstitial Delegate Methods

- (NSString *)publisherIdForAdSdkVideoInterstitialView:(AdSdkVideoInterstitialViewController *)videoInterstitial
{
  
  if(currentFullscreenAd == AD_PRIORITY_ADSDK)
  {
    return @"e308bfab1a3b8a1d471a2ae1c44197c6";
  }
  else if(currentFullscreenAd == AD_PRIORITY_REVMOB)
  {
    return @"2569dd14fc09ac444ec6f19e1d5548e2";
  }
  else if(currentFullscreenAd == AD_MOPUB)
  {
    return @"c9c924ac3309a59d456ccae8324660dc";
  }
  else if(currentFullscreenAd == AD_REVMOB)
  {
    return @"a4317f8b832a1ae7b18781484a15efaa";
  }
  
  // currentFullscreenAd == AD_ADSDK
  return @"f89e202b1f15023cfef026a7fb75ac50";
}

- (void)adsdkVideoInterstitialViewDidLoadAdSdkAd:(AdSdkVideoInterstitialViewController *)videoInterstitial advertTypeLoaded:(AdSdkAdType)advertType
{
  // Means an advert has been retrieved and configured.
  // Display the ad using the presentAd method and ensure you pass back the advertType
  
  if(self.adTimer != nil)
  {
    [self.adTimer invalidate];
    self.adTimer = nil;
  }
  else
  {
    return;
  }
  
  if(currentFullscreenAd == AD_PRIORITY_ADSDK)
  {
    [self.view setUserInteractionEnabled:YES];
    [videoInterstitial.view setHidden:NO];
    [self.view bringSubviewToFront:videoInterstitial.view];
    [videoInterstitial presentAd:advertType];
  }
  else if(currentFullscreenAd == AD_PRIORITY_REVMOB)
  {
    [videoInterstitial.view setHidden:YES];
    RevMobFullscreen* fs = [[RevMobAds session] fullscreen];
    fs.delegate = self;
    [fs showAd];
  }
  else if(currentFullscreenAd == AD_MOPUB)
  {
    [videoInterstitial.view setHidden:YES];
    if(self.interstitial != nil)
    {
      self.interstitial = nil;
    }
    
    // Instantiate the interstitial using the class convenience method.
    self.interstitial = [MPInterstitialAdController
                         interstitialAdControllerForAdUnitId:@"b644a0c0cb0811e295fa123138070049"];
    self.interstitial.delegate = self;
    // Fetch the interstitial ad.
    [self.interstitial loadAd];
  }
  else if(currentFullscreenAd == AD_REVMOB)
  {
    [videoInterstitial.view setHidden:YES];
    RevMobFullscreen* fs = [[RevMobAds session] fullscreen];
    fs.delegate = self;
    [fs showAd];
  }
  else if(currentFullscreenAd == AD_ADSDK)
  {
    [self.view setUserInteractionEnabled:YES];
    [videoInterstitial.view setHidden:NO];
    [self.view bringSubviewToFront:videoInterstitial.view];
    [videoInterstitial presentAd:advertType];
  }
}

- (void)adsdkVideoInterstitialView:(AdSdkVideoInterstitialViewController *)banner didFailToReceiveAdWithError:(NSError *)error
{
  if(self.adTimer != nil)
  {
    [self.adTimer invalidate];
    self.adTimer = nil;
  }
  else
  {
    return;
  }
  
  NSRange r1 = [[error localizedDescription] rangeOfString:@"inventory" options:NSCaseInsensitiveSearch];
  NSRange r2 = [[error localizedDescription] rangeOfString:@"no ad" options:NSCaseInsensitiveSearch];
  if(r1.length > 0 || r2.length > 0)
  {
    currentFullscreenAd++;
    [self requestInterstitialAdvert:self];
  }
  else
  {
    currentFullscreenAd = AD_NONE;
    if(self.videoInterstitialViewController != nil)
    {
      [self.videoInterstitialViewController.view setHidden:YES];
    }
    RevMobFullscreen* fs = [[RevMobAds session] fullscreen];
    fs.delegate = self;
    [fs showAd];
  }
}

- (void)adsdkVideoInterstitialViewDidDismissScreen:(AdSdkVideoInterstitialViewController *)videoInterstitial
{
  currentFullscreenAd = AD_NONE;
  [self runGame];
}

- (void)adsdkVideoInterstitialViewActionWillLeaveApplication:(AdSdkVideoInterstitialViewController *)videoInterstitial
{
  currentFullscreenAd = AD_NONE;
  //[self runGame];
}

#pragma mark - MoPub delegate methods

- (void)interstitialDidLoadAd:(MPInterstitialAdController *)interstitial
{
  [self.view setUserInteractionEnabled:YES];
  [self.interstitial showFromViewController:self];
}

- (void)interstitialDidFailToLoadAd:(MPInterstitialAdController *)interstitial
{
  currentFullscreenAd++;
  [self requestInterstitialAdvert:self];
}

- (void)interstitialDidDisappear:(MPInterstitialAdController *)interstitial
{
  currentFullscreenAd = AD_NONE;
  [self runGame];
}

- (void)interstitialDidExpire:(MPInterstitialAdController *)interstitial
{
  currentFullscreenAd++;
  [self requestInterstitialAdvert:self];
}

#pragma mark - RevMobAdsDelegate methods

- (void)revmobAdDidReceive
{
}

- (void)revmobAdDidFailWithError:(NSError *)error
{
  if(currentFullscreenAd == AD_NONE)
  {
    if(self.videoInterstitialViewController != nil)
    {
      [self.videoInterstitialViewController.view setHidden:YES];
    }
    if(self.interstitial != nil)
    {
      self.interstitial = nil;
    }
    
    // Instantiate the interstitial using the class convenience method.
    self.interstitial = [MPInterstitialAdController
                         interstitialAdControllerForAdUnitId:@"b644a0c0cb0811e295fa123138070049"];
    self.interstitial.delegate = self;
    // Fetch the interstitial ad.
    [self.interstitial loadAd];
  }
  else
  {
    currentFullscreenAd++;
    [self requestInterstitialAdvert:self];
  }
}

- (void)revmobAdDisplayed
{
  [self.view setUserInteractionEnabled:YES];
}

- (void)revmobUserClosedTheAd
{
  currentFullscreenAd = AD_NONE;
  [self runGame];
}

- (void)revmobUserClickedInTheAd
{
  currentFullscreenAd = AD_NONE;
  //[self runGame];
}

- (void)installDidReceive
{
}

- (void)installDidFail
{
}

@end
