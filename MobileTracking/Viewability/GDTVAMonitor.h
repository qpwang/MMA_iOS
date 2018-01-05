//
//  GDTVAMonitor.h
//  ViewbilitySDK
//
//  Created by master on 2017/6/15.
//  Copyright © 2017年 AdMaster. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIView+GDTMonitor.h"
#import "GDTVAMonitorFrame.h"
#import "GDTVAMonitorTimeline.h"
#import "GDTVAMonitorConfig.h"
#import "GDT_Macro.h"
#import "GDTVAMaros.h"
@class GDTVAMonitor;

@protocol GDTVAMonitorDataProtocol <NSObject>

- (void)monitor:(GDTVAMonitor *)monitor didReceiveData:(NSDictionary *)monitorData edid:(NSString *)edid;
@end


typedef NS_ENUM(NSUInteger, GDTVAMonitorStatus) {
    GDTVAMonitorStatusRuning = 0,              // 正常工作
//    GDTVAMonitorStatusTimeout = 1,              // 超过最大可持续监测时间
    GDTVAMonitorStatusWaitingUpload = 1,           // 等待上传
    GDTVAMonitorStatusUploaded = 2              // 上传完成
    
};

typedef NS_ENUM(NSUInteger, VAProgressStatus) {
    VAProgressStatusRuning = 0,              // 正常工作
    VAProgressStatusEnd = 3              // 上传完成
};


@interface GDTVAMonitor : NSObject <NSCoding>
{
    BOOL _canMeasurable;

}

@property (nonatomic, weak, readonly) UIView *adView;
@property (nonatomic, copy, readonly) NSString *url;
@property (nonatomic, copy, readonly) NSString *redirectURL;

@property (nonatomic, copy, readonly) NSString *impressionID;
@property (nonatomic, copy, readonly) NSString *adID;
@property (nonatomic, copy, readonly) NSString *domain;
@property (nonatomic, copy, readonly) NSString *edid;

@property (nonatomic, strong, readonly) GDTVAMonitorTimeline *timeline;
@property (nonatomic) GDTVAMonitorStatus status;
@property (nonatomic) VAProgressStatus progressStatus;

@property (nonatomic, strong,readonly) GDTVAMonitorConfig *config;
@property (nonatomic, readonly) BOOL isValid;
@property (nonatomic, readonly) BOOL isVideo;


@property (nonatomic, weak) id<GDTVAMonitorDataProtocol> delegate;


+ (GDTVAMonitor *)monitorWithView:(UIView *)view isVideo:(BOOL)isVideo url:(NSString *)url redirectURL:(NSString *)redirectURL impressionID:(NSString *)impID adID:(NSString *)adID keyValueAccess:(NSDictionary *)keyValueAccess config:(GDTVAMonitorConfig *)config domain:(NSString *)domain edid:(NSString *)edid;

//- (void)setConfig:(GDTVAMonitorConfig *)config;

- (void)captureAdStatusAndVerify;

//private method for subclass
- (void)captureAdStatus;

- (void)stopAndUpload;

- (NSString *)keyQuery:(NSString *)key;
- (BOOL)canRecord:(NSString *)key;
@end

