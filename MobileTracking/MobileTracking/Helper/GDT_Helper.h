//
//  GDT_Helper.h
//  GDTMobileTracking
//
//  Created by Wenqi on 14-3-13.
//  Copyright (c) 2014年 Admaster. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

@interface GDT_Helper : NSObject

+ (NSString *)md5HexDigest:(NSString *)url;
+ (NSString *)URLEncoded:(NSString *)string;

@end
