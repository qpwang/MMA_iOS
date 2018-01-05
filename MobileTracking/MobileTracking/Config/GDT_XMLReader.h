//
//  GDT_XMLReader.h
//  GDTMobileTracking
//
//  Created by Wenqi on 14-3-11.
//  Copyright (c) 2014年 Admaster. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GDT_SDKConfig.h"

@interface GDT_XMLReader : NSObject

+ (GDT_SDKConfig *)sdkConfigWithData:(NSData *)data;

@end
