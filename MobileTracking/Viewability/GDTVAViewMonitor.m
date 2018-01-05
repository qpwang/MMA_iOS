
//
//  GDTVAViewMonitor.m
//  ViewbilitySDK
//
//  Created by master on 2017/6/15.
//  Copyright © 2017年 AdMaster. All rights reserved.
//

#import "GDTVAViewMonitor.h"

@implementation GDTVAViewMonitor

- (void)captureAdStatus {
    GDTVAMonitorFrame *frame = [[GDTVAMonitorFrame alloc] initWithView:self.adView];
//    NSLog(@"ID:%@ 捕获数据中:%@",self.impressionID,frame);
    [self.timeline enqueueFrame:frame];
}
@end
