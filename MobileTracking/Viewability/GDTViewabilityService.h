//
//  ViewbilityService.h
//  ViewbilitySDK
//
//  Created by master on 2017/6/15.
//  Copyright © 2017年 AdMaster. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GDTVAMonitor.h"
@interface GDTViewabilityService : NSObject
@property (nonatomic, strong, readonly) GDTVAMonitorConfig *config;

- (instancetype)initWithConfig:(GDTVAMonitorConfig *)config;

- (void)addGDTVAMonitor:(GDTVAMonitor *)monitor;
- (void)processCacheMonitorsWithDelegate:(id <GDTVAMonitorDataProtocol>)delegate;
- (void)stopGDTVAMonitor:(NSString *)monitorKey;
- (void)start;
@end
