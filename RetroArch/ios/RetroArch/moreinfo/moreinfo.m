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
#import "moreinfo.h"
#import "conf/config_file.h"

@implementation RAMoreInfo
{
}

- (void)loadView
{
  UIView* contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
  [contentView setAutoresizesSubviews:YES];
  [contentView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
  contentView.backgroundColor = [UIColor clearColor];
  [self setView:contentView];
  [self.view setAutoresizesSubviews:YES];

  UIWebView* moreInfoWebView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
  [moreInfoWebView setAutoresizesSubviews:YES];
  [moreInfoWebView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
  [self.view addSubview:moreInfoWebView];

  [moreInfoWebView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle]pathForResource:@"moreinfo" ofType:@"html" inDirectory:nil]]]];
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@"Back"
                                           style:UIBarButtonItemStyleBordered
                                           target:moreInfoWebView
                                           action:@selector(goBack)];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
}

- (void)viewDidUnload
{
  [super viewDidUnload];
}

@end
