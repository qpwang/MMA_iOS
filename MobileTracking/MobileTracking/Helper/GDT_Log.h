//
//  GDT_Log.h
//  GDTMobileTracking
//
//  Created by Wenqi on 14-3-12.
//  Copyright (c) 2014年 Admaster. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GDT_Log : NSObject

+ (void)setDebug:(BOOL)debug;

+ (void)log:(NSString *)format, ...;

@end
