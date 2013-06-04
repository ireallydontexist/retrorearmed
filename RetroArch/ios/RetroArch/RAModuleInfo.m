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

#include <glob.h>
#import "RAModuleInfo.h"

static NSMutableArray* moduleList;
static NSString* const labels[3] = {@"Core Name", @"Developer", @"Name"};
static const char* const keys[3] = {"corename", "manufacturer", "systemname"};
static NSString* const sectionNames[2] = {@"Emulator", @"Hardware"};
static const uint32_t sectionSizes[2] = {1, 2};

@implementation RAModuleInfo
+ (NSArray*)getModules
{
   if (!moduleList)
   {
      char pattern[PATH_MAX];
      snprintf(pattern, PATH_MAX, "%s/modules/*.dylib", [[NSBundle mainBundle].bundlePath UTF8String]);

      glob_t files = {0};
      glob(pattern, 0, 0, &files);
      
      moduleList = [NSMutableArray arrayWithCapacity:files.gl_pathc];
   
      for (int i = 0; i != files.gl_pathc; i ++)
      {
         RAModuleInfo* newInfo = [RAModuleInfo new];
         newInfo.path = [NSString stringWithUTF8String:files.gl_pathv[i]];
         
         NSString* infoPath = [newInfo.path stringByReplacingOccurrencesOfString:@"_ios.dylib" withString:@".dylib"];
         infoPath = [infoPath stringByReplacingOccurrencesOfString:@".dylib" withString:@".info"];

         newInfo.data = config_file_new([infoPath UTF8String]);

         char* dispname = 0;
         char* extensions = 0;
   
         if (newInfo.data)
         {
            config_get_string(newInfo.data, "display_name", &dispname);
            config_get_string(newInfo.data, "supported_extensions", &extensions);
         }

         newInfo.configPath = [NSString stringWithFormat:@"%@/%@.cfg", [RetroArch_iOS get].system_directory, [[newInfo.path lastPathComponent] stringByDeletingPathExtension]];
         newInfo.displayName = dispname ? [NSString stringWithUTF8String:dispname] : [[newInfo.path lastPathComponent] stringByDeletingPathExtension];
         newInfo.supportedExtensions = extensions ? [[NSString stringWithUTF8String:extensions] componentsSeparatedByString:@"|"] : [NSArray array];

         free(dispname);
         free(extensions);

         [moduleList addObject:newInfo];
      }
      
      globfree(&files);
      
      [moduleList sortUsingComparator:^(RAModuleInfo* left, RAModuleInfo* right)
      {
         return [left.displayName caseInsensitiveCompare:right.displayName];
      }];
   }
   
   return moduleList;
}

- (void)dealloc
{
   config_file_free(self.data);
}

- (bool)supportsFileAtPath:(NSString*)path
{
   return [self.supportedExtensions containsObject:[[path pathExtension] lowercaseString]];
}

@end

@implementation RAModuleInfoList
{
   RAModuleInfo* _data;
}

- (id)initWithModuleInfo:(RAModuleInfo*)info
{
   self = [super initWithStyle:UITableViewStyleGrouped];

   _data = info;
   return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
   return sizeof(sectionSizes) / sizeof(sectionSizes[0]);
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section
{
   return sectionNames[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
   return sectionSizes[section];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
   UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"datacell"];
   cell = (cell != nil) ? cell : [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"datacell"];
   
   uint32_t sectionBase = 0;
   for (int i = 0; i != indexPath.section; i ++)
   {
      sectionBase += sectionSizes[i];
   }

   cell.textLabel.text = labels[sectionBase + indexPath.row];
   
   char* val = 0;
   if (_data.data)
      config_get_string(_data.data, keys[sectionBase + indexPath.row], &val);
   
   cell.detailTextLabel.text = val ? [NSString stringWithUTF8String:val] : @"Unspecified";
   free(val);

   return cell;
}

@end
