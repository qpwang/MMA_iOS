//
//  GDT_TaskQueue.h
//  GDTMobileTracking
//
//  Created by Wenqi on 14-3-12.
//  Copyright (c) 2014年 Admaster. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GDT_Task.h"

@interface GDT_TaskQueue : NSObject

- (instancetype)initWithIdentity: (NSString *)identity;

- (void)push: (GDT_Task *)task;

- (GDT_Task *)pop;

- (void)clear;

- (NSInteger)count;

- (void)loadData;

- (void)persistData;

@end
