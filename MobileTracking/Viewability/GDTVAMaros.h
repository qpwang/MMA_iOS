//
//  GDTVAMaros.h
//  ViewbilitySDK
//
//  Created by master on 2017/6/16.
//  Copyright © 2017年 AdMaster. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

#define VAStringFromSize(x) [GDTVAMaros sizeToString:x]
#define VAStringFromPoint(x) [GDTVAMaros pointToString:x]
#define DLOG(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#define NSLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

//#define NSLog(format,...)

@interface GDTVAMaros : NSObject

+ (NSString *)sizeToString:(CGSize)size;
+ (NSString *)pointToString:(CGPoint)point;

@end
