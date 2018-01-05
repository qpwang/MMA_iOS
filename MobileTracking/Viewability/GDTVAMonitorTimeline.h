//
//  VAMontorTimeline.h
//  ViewbilitySDK
//
//  Created by master on 2017/6/15.
//  Copyright © 2017年 AdMaster. All rights reserved.
//

#import <UIKit/UIKit.h>
@class GDTVAMonitorFrame;
@class GDTVAMonitor;
@interface GDTVAMonitorTimeline : NSObject <NSCoding>
@property (nonatomic) CGFloat exposeDuration;
@property (nonatomic) CGFloat monitorDuration;
@property (nonatomic, weak) GDTVAMonitor *monitor;

- (instancetype)initWithMonitor:(GDTVAMonitor *)monitor;

- (void)enqueueFrame:(GDTVAMonitorFrame *)frame;

- (NSInteger)count;
- (NSString *)generateUploadEvents;
@end
