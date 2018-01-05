//
//  GDTMobileTracking.m
//  GDTMobileTracking
//
//  Created by Wenqi on 14-3-11.
//  Copyright (c) 2014年 Admaster. All rights reserved.
//


#import "GDTMobileTracking.h"
#import "GDT_Macro.h"
#import "GDT_SDKConfig.h"
#import "GDT_XMLReader.h"
#import "GDT_Log.h"
#import "GDT_Task.h"
#import "GDT_TaskQueue.h"
#import "GDT_Helper.h"

#import "GDTTrackingInfoService.h"
#import "MMA_EncryptModule.h"
#import "GDT_RequestQueue.h"
#import "GTMNSString+URLArguments.h"
#import "GDTViewabilityService.h"
#import "GDTVAMonitor.h"
#import "GDTVAMonitorConfig.h"

@interface GDTMobileTracking() <GDTVAMonitorDataProtocol>

@property (atomic, strong) GDT_SDKConfig *sdkConfig;
@property (nonatomic, strong) NSString *sdkConfigURL;
@property (nonatomic, strong) GDT_TaskQueue *sendQueue;
@property (nonatomic, strong) GDT_TaskQueue *failedQueue;
@property (nonatomic, strong) GDTTrackingInfoService *trackingInfoService;
@property (nonatomic, strong) NSTimer *failedQueueTimer;
@property (nonatomic, strong) NSTimer *sendQueueTimer;
@property (nonatomic, assign) BOOL isTrackLocation;
@property (nonatomic, strong) GDTVAMonitorConfig *viewabilityConfig;
@property (nonatomic, strong) GDTViewabilityService *viewabilityService;

@property (nonatomic, strong) NSMutableDictionary *impressionDictionary;

@end


@interface VBOpenResult : NSObject
@property (nonatomic) BOOL canOpen;
@property (nonatomic,copy) NSString *url;
//@property (nonatomic,copy) NSString *viewabilityURL;
@property (nonatomic, copy) NSString *redirectURL;
@property (nonatomic, copy) GDTVAMonitorConfig *config;

@end

@implementation VBOpenResult

- (instancetype)init {
    self = [super init];
    self.canOpen = NO;
    self.url = @""; // 普通曝光或viewabilityURL
//    self.viewabilityURL = @""; // 去噪所有viewability字段的url
    self.redirectURL = @""; // u字段
    return self;
}

@end


@implementation GDTMobileTracking

+ (GDTMobileTracking *)sharedInstance {
    static GDTMobileTracking *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        
        _trackingInfoService = [GDTTrackingInfoService sharedInstance];
        _impressionDictionary = [NSMutableDictionary dictionary];
        _isTrackLocation = false;
        
        [self initSdkConfig];
        [self initQueue];
        [self initTimer];
//        [self openLBS];
        [self initViewabilityService];
        
        
    }
    return self;
}

- (void)initSdkConfig
{
//    NSString *localSdkFilePath = [[NSBundle mainBundle] pathForResource:SDK_CONFIG_FILE_NAME ofType:SDK_CONFIG_FILE_EXT];
//    NSData *localSdkData = [[NSData alloc] initWithContentsOfFile:localSdkFilePath];
//    
//    _sdkConfig = [GDT_XMLReader sdkConfigWithData:localSdkData];
//    NSString* contents = [NSString stringWithContentsOfFile:localSdkFilePath
//                                                   encoding:NSUTF8StringEncoding
//                                                      error:nil];
    NSString *xml64 = @"PGNvbmZpZyB4bWxuczp4c2k9Imh0dHA6Ly93d3cudzMub3JnLzIwMDEvWE1MU2NoZW1hLWluc3RhbmNlIiB4c2k6bm9OYW1lc3BhY2VTY2hlbWFMb2NhdGlvbj0iU0RLU2NoZW1hLnhzZCI+PCEtLee8k+WtmOmYn+WIl+iuvue9ri0tPjxvZmZsaW5lQ2FjaGU+PGxlbmd0aD4wPC9sZW5ndGg+PHF1ZXVlRXhwaXJhdGlvblNlY3M+NjA8L3F1ZXVlRXhwaXJhdGlvblNlY3M+PCEtLeWPkemAgei2heaXtuaXtumXtC0tPjx0aW1lb3V0PjYwPC90aW1lb3V0Pjwvb2ZmbGluZUNhY2hlPjx2aWV3YWJpbGl0eT48IS0tdmlld2FiaWxpdHnnm5HmtYvnmoTml7bpl7Tpl7TpmpTvvIhtc++8iS0tPjxpbnRlcnZhbFRpbWU+MTAwPC9pbnRlcnZhbFRpbWU+PCEtLea7oei2s3ZpZXdhYmlsaXR55Y+v6KeB5Yy65Z+f5Y2g5oC75Yy65Z+f55qE55m+5YiG5q+ULS0+PHZpZXdhYmlsaXR5RnJhbWU+NTA8L3ZpZXdhYmlsaXR5RnJhbWU+PCEtLea7oei2s+aZrumAmnZpZXdhYmlsaXR55oC75pe26ZW/77yIc++8iS0tPjx2aWV3YWJpbGl0eVRpbWU+MTwvdmlld2FiaWxpdHlUaW1lPjwhLS3mu6HotrPop4bpopF2aWV3YWJpbGl0eeaAu+aXtumVv++8iHPvvIktLT48dmlld2FiaWxpdHlWaWRlb1RpbWU+Mjwvdmlld2FiaWxpdHlWaWRlb1RpbWU+PCEtLeW9k+WJjeW5v+WRiuS9jeacgOWkp+ebkea1i+aXtumVv++8iHPvvIktLT48bWF4RXhwaXJhdGlvblNlY3M+MTIwPC9tYXhFeHBpcmF0aW9uU2Vjcz48IS0t5b2T5YmN5bm/5ZGK5L2N5pyA5aSn5LiK5oql5pWw6YePLS0+PG1heEFtb3VudD4yMDwvbWF4QW1vdW50Pjwvdmlld2FiaWxpdHk+PGNvbXBhbmllcz48Y29tcGFueT48bmFtZT5hZG1hc3RlcjwvbmFtZT48IS0tIFZpZXdhYmlsaXR5IEpz5pa55byP55uR5rWLIEpz5Zyo57q/5pu05paw5Zyw5Z2AIGUuZy4gaHR0cDovL3h4eHguY29tLmNuL2RvY3MvbW1hLXNkay5qcyAtLT48anN1cmwvPjwhLS0gVmlld2FiaWxpdHkgSnPmlrnlvI/nm5HmtYsg56a757q/anPmlofku7blkI3np7AtLT48anNuYW1lLz48ZG9tYWluPjwhLS0g5q2k5aSE6ZyA5L+u5pS55Li656ys5LiJ5pa55qOA5rWL5YWs5Y+455uR5rWL5Luj56CB55qEIGhvc3Qg6YOo5YiGIC0tPjx1cmw+YWRtYXN0ZXIuY29tLmNuPC91cmw+PC9kb21haW4+PHNpZ25hdHVyZT48cHVibGljS2V5Plo4MzQ3NkhlbDwvcHVibGljS2V5PjxwYXJhbUtleT5zaWduPC9wYXJhbUtleT48L3NpZ25hdHVyZT48c3dpdGNoPjxpc1RyYWNrTG9jYXRpb24+ZmFsc2U8L2lzVHJhY2tMb2NhdGlvbj48IS0tIOWkseaViOaXtumXtO+8jOWNleS9jeenkiAtLT48b2ZmbGluZUNhY2hlRXhwaXJhdGlvbj4yNTkyMDA8L29mZmxpbmVDYWNoZUV4cGlyYXRpb24+PCEtLSDlj6/op4bljJbnm5HmtYvph4fpm4bnrZbnlaUgMCA9IFRyYWNrUG9zaXRpb25DaGFuZ2VkIOS9jee9ruaUueWPmOaXtuiusOW9lSwxID0gVHJhY2tWaXNpYmxlQ2hhbmdlZCDlj6/op4bmlLnlj5jml7borrDlvZUtLT48dmlld2FiaWxpdHlUcmFja1BvbGljeT4wPC92aWV3YWJpbGl0eVRyYWNrUG9saWN5PjxlbmNyeXB0PjxNQUM+bWQ1PC9NQUM+PElEQT5tZDU8L0lEQT48SU1FST5tZDU8L0lNRUk+PEFORFJPSURJRD5yYXc8L0FORFJPSURJRD48L2VuY3J5cHQ+PGFwcGxpc3Q+PCEtLSBhcHBsaXN05LiK5oql5Zyw5Z2AIGUuZy4gaHR0cHM6eHh4eC5jb20uY24vdHJhY2svYXBwbGlzdCAtLT48dXBsb2FkVXJsLz48IS0tIGFwcGxpc3TkuIrmiqXml7bpl7Tpl7TpmpTvvIzljZXkvY3kuLrlsI/ml7Ys6YWN572u5Li6MOaXtu+8jOS4jeS4iuaKpS0tPjx1cGxvYWRUaW1lPjA8L3VwbG9hZFRpbWU+PC9hcHBsaXN0Pjwvc3dpdGNoPjxjb25maWc+PGFyZ3VtZW50cz48IS0tYXJndW1lbnTnmoTlv4XpgInlkozluLjnlKjlj6/pgInlj4LmlbAga2V56ZyA56Gu5a6aLS0+PCEtLeW/hemAieWHveaVsC0tPjxhcmd1bWVudD48a2V5Pk9TPC9rZXk+PHZhbHVlPjBhPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+VFM8L2tleT48dmFsdWU+dDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5Pk1BQzwva2V5Pjx2YWx1ZT5uPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+SURGQTwva2V5Pjx2YWx1ZT56PC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+SURGQU1ENTwva2V5Pjx2YWx1ZT4wajwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PklNRUk8L2tleT48dmFsdWU+MGM8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5BTkRST0lESUQ8L2tleT48dmFsdWU+MGQ8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5XSUZJPC9rZXk+PHZhbHVlPnc8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48IS0tIFdpRmkgTmFtZS0tPjxhcmd1bWVudD48a2V5PldJRklTU0lEPC9rZXk+PHZhbHVlPjFwPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PCEtLSBXaUZpIE1BQy0tPjxhcmd1bWVudD48a2V5PldJRklCU1NJRDwva2V5Pjx2YWx1ZT4xcTwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PkFLRVk8L2tleT48dmFsdWU+eDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PkFOQU1FPC9rZXk+PHZhbHVlPnk8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48IS0t5Y+v6YCJ5Ye95pWwLS0+PGFyZ3VtZW50PjxrZXk+U0NXSDwva2V5Pjx2YWx1ZT4wZjwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5Pk9QRU5VRElEPC9rZXk+PHZhbHVlPm88L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5URVJNPC9rZXk+PHZhbHVlPnI8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5PU1ZTPC9rZXk+PHZhbHVlPnE8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5MQlM8L2tleT48dmFsdWU+bDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PlNES1ZTPC9rZXk+PHZhbHVlPjBsPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+UkVESVJFQ1RVUkw8L2tleT48dmFsdWU+dTwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwvYXJndW1lbnRzPjxldmVudHM+PGV2ZW50PjwhLS08bmFtZT5tMTwvbmFtZT4tLT48a2V5PnN0YXJ0PC9rZXk+PHZhbHVlPm0yMDE8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjwvZXZlbnQ+PGV2ZW50PjwhLS08bmFtZT5lMTwvbmFtZT4tLT48a2V5PmVuZDwva2V5Pjx2YWx1ZT5tMjAzPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48L2V2ZW50PjwvZXZlbnRzPjwhLS0g5bm/5ZGK5L2N5qCH6K+G56ymIC0tPjxBZHBsYWNlbWVudD48YXJndW1lbnQ+PGtleT5BZHBsYWNlbWVudDwva2V5Pjx2YWx1ZT5iPC92YWx1ZT48dXJsRW5jb2RlPmZhbHNlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+ZmFsc2U8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48L0FkcGxhY2VtZW50Pjx2aWV3YWJpbGl0eWFyZ3VtZW50cz48IS0tIOWPr+inhuebkea1i+ivhuWIq0lEIC0tPjxhcmd1bWVudD48a2V5PkltcHJlc3Npb25JRDwva2V5Pjx2YWx1ZT4yZzwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS0g6YeH6ZuG5bGe5oCnIHN0YXJ0IC0tPjwhLS0g5Y+v6KeG6KeG5Zu+6YeH6ZuG6L2o6L+55pWw5o2uIC0tPjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlFdmVudHM8L2tleT48dmFsdWU+Mmo8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48IS0tIOWPr+inhuinhuWbvumHh+mbhueCueaXtumXtOaIsyAtLT48YXJndW1lbnQ+PGtleT5BZHZpZXdhYmlsaXR5VGltZTwva2V5Pjx2YWx1ZT4ydDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS0g5Y+v6KeG6KeG5Zu+5bC65a+4IC0tPjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlGcmFtZTwva2V5Pjx2YWx1ZT4yazwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS0g6KeG5Zu+5Y+v6KeG5Yy65Z+f5Z2Q5qCHIC0tPjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlQb2ludDwva2V5Pjx2YWx1ZT4yZDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS0g5Y+v6KeG6KeG5Zu+6YCP5piO5bqmIC0tPjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlBbHBoYTwva2V5Pjx2YWx1ZT4ybDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS0g5Y+v6KeG6KeG5Zu+5piv5ZCm5pi+56S6IC0tPjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlTaG93bjwva2V5Pjx2YWx1ZT4ybTwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS0g5Y+v6KeG6KeG5Zu+6KKr6KaG55uW546HIC0tPjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlDb3ZlclJhdGU8L2tleT48dmFsdWU+Mm48L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48IS0tIOinhuWbvuWPr+inhuWwuuWvuCAtLT48YXJndW1lbnQ+PGtleT5BZHZpZXdhYmlsaXR5U2hvd0ZyYW1lPC9rZXk+PHZhbHVlPjJvPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PCEtLSDlsY/luZXmmK/lkKbngrnkuq4gLS0+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eUxpZ2h0PC9rZXk+PHZhbHVlPjJyPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PCEtLSBBUFDmmK/lkKblnKjliY3lj7Dov5DooYwgLS0+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eUZvcmdyb3VuZDwva2V5Pjx2YWx1ZT4yczwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS0g5Y+v6KeG6KeG5Zu+5Y+v6KeB5oCnIC0tPjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHk8L2tleT48dmFsdWU+MmY8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48IS0tIOWPr+inhuinhuWbvuWPr+a1i+mHj+aApyAtLT48YXJndW1lbnQ+PGtleT5BZE1lYXN1cmFiaWxpdHk8L2tleT48dmFsdWU+Mmg8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48IS0tIOmHh+mbhuWxnuaApyBlbmQgLS0+PCEtLSDphY3nva7lsZ7mgKcgc3RhcnQgLS0+PCEtLSDmu6HotrPlj6/op4bopobnm5bnjocgLS0+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eUNvbmZpZ0FyZWE8L2tleT48dmFsdWU+MnY8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48IS0tIOa7oei2s+WPr+inhuaXtumVvyAtLT48YXJndW1lbnQ+PGtleT5BZHZpZXdhYmlsaXR5Q29uZmlnVGhyZXNob2xkPC9rZXk+PHZhbHVlPjJ1PC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PCEtLSDlj6/op4bop4bpopHmkq3mlL7ml7bplb8gLS0+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eVZpZGVvRHVyYXRpb248L2tleT48dmFsdWU+Mnc8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48IS0tIOWPr+inhuinhumikeaSreaUvui/m+W6puebkea1i+S6i+S7tuexu+WeiyAtLT48YXJndW1lbnQ+PGtleT5BZHZpZXdhYmlsaXR5VmlkZW9Qcm9ncmVzczwva2V5Pjx2YWx1ZT4yYTwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS0g5Y+v6KeG55uR5rWL5Lyg5YWl55qE6KeG6aKR5pKt5pS+57G75Z6LIC0tPjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlWaWRlb1BsYXlUeXBlPC9rZXk+PHZhbHVlPjFnPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PCEtLSDop4bpopHlj6/op4bljJbmkq3mlL7ov5vluqbphY3nva7kvp3mrKHkuLo6MjUlNTAlNzUlMTAwJSAtLT48YXJndW1lbnQ+PGtleT5BZHZpZXdhYmlsaXR5VmlkZW9Qcm9ncmVzc1BvaW50PC9rZXk+PHZhbHVlPjJ4PC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PCEtLSDphY3nva7lsZ7mgKcgZW5kIC0tPjwhLS0g5o6n5Yi25bGe5oCnIHN0YXJ0IC0tPjwhLS0g5piv5ZCm5byA5ZCvVmlld0FiaWxpdHnnm5HmtYsgLS0+PCEtLQogICAgICAgICAgICAgICAgICAgICA8YXJndW1lbnQ+CiAgICAgICAgICAgICAgICAgICAgIDxrZXk+QWR2aWV3YWJpbGl0eUVuYWJsZTwva2V5PgogICAgICAgICAgICAgICAgICAgICA8dmFsdWU+MnA8L3ZhbHVlPgogICAgICAgICAgICAgICAgICAgICA8dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT4KICAgICAgICAgICAgICAgICAgICAgPGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD4KICAgICAgICAgICAgICAgICAgICAgPC9hcmd1bWVudD4KICAgICAgICAgICAgICAgICAgICAgLS0+PCEtLSDlj6/op4bovajov7nmlbDmja7mmK/lkKbkuIrmiqUgLS0+PCEtLQogICAgICAgICAgICAgICAgICAgICA8YXJndW1lbnQ+CiAgICAgICAgICAgICAgICAgICAgIDxrZXk+QWR2aWV3YWJpbGl0eVJlY29yZDwva2V5PgogICAgICAgICAgICAgICAgICAgICA8dmFsdWU+dmE8L3ZhbHVlPgogICAgICAgICAgICAgICAgICAgICA8dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT4KICAgICAgICAgICAgICAgICAgICAgPGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD4KICAgICAgICAgICAgICAgICAgICAgPC9hcmd1bWVudD4KICAgICAgICAgICAgICAgICAgICAgLS0+PCEtLSDmjqfliLblsZ7mgKcgZW5kIC0tPjwvdmlld2FiaWxpdHlhcmd1bWVudHM+PC9jb25maWc+PCEtLSA8c2VwYXJhdG9yPiZhbXA7PC9zZXBhcmF0b3I+IC0tPjxzZXBhcmF0b3I+LDwvc2VwYXJhdG9yPjwhLS0gPGVxdWFsaXplcj49PC9lcXVhbGl6ZXI+IC0tPjxlcXVhbGl6ZXIvPjwhLS3lpoLmnpzorr7nva50cnVlICAgdGltZVN0YW1wZXLkvb/nlKjnp5ItLT48dGltZVN0YW1wVXNlU2Vjb25kPmZhbHNlPC90aW1lU3RhbXBVc2VTZWNvbmQ+PC9jb21wYW55Pjxjb21wYW55PjxuYW1lPm1pYW96aGVuPC9uYW1lPjwhLS0gVmlld2FiaWxpdHkgSnPmlrnlvI/nm5HmtYsgSnPlnKjnur/mm7TmlrDlnLDlnYAgZS5nLiBodHRwOi8veHh4eC5jb20uY24vZG9jcy9tbWEtc2RrLmpzIC0tPjxqc3VybC8+PCEtLSBWaWV3YWJpbGl0eSBKc+aWueW8j+ebkea1iyDnprvnur9qc+aWh+S7tuWQjeensC0tPjxqc25hbWUvPjxkb21haW4+PCEtLSDmraTlpITpnIDkv67mlLnkuLrnrKzkuInmlrnmo4DmtYvlhazlj7jnm5HmtYvku6PnoIHnmoQgaG9zdCDpg6jliIYgLS0+PHVybD4ubWlhb3poZW4uY29tPC91cmw+PC9kb21haW4+PHNpZ25hdHVyZT48cHVibGljS2V5PkRiWGlVbEVWTjwvcHVibGljS2V5PjxwYXJhbUtleT5tZjwvcGFyYW1LZXk+PC9zaWduYXR1cmU+PHN3aXRjaD48aXNUcmFja0xvY2F0aW9uPnRydWU8L2lzVHJhY2tMb2NhdGlvbj48IS0tIOWkseaViOaXtumXtO+8jOWNleS9jeenkiAtLT48b2ZmbGluZUNhY2hlRXhwaXJhdGlvbj42MDQ4MDA8L29mZmxpbmVDYWNoZUV4cGlyYXRpb24+PCEtLSDlj6/op4bljJbnm5HmtYvph4fpm4bnrZbnlaUgMCA9IFRyYWNrUG9zaXRpb25DaGFuZ2VkIOS9jee9ruaUueWPmOaXtuiusOW9lSwxID0gVHJhY2tWaXNpYmxlQ2hhbmdlZCDlj6/op4bmlLnlj5jml7borrDlvZUtLT48dmlld2FiaWxpdHlUcmFja1BvbGljeT4xPC92aWV3YWJpbGl0eVRyYWNrUG9saWN5PjxlbmNyeXB0PjxNQUM+cmF3PC9NQUM+PElEQT5yYXc8L0lEQT48SU1FST5yYXc8L0lNRUk+PEFORFJPSURJRD5yYXc8L0FORFJPSURJRD48L2VuY3J5cHQ+PGFwcGxpc3Q+PCEtLSBhcHBsaXN05LiK5oql5Zyw5Z2AIGUuZy4gaHR0cHM6eHh4eC5jb20uY24vdHJhY2svYXBwbGlzdCAtLT48dXBsb2FkVXJsPi9hcGwvPC91cGxvYWRVcmw+PCEtLSBhcHBsaXN05LiK5oql5pe26Ze06Ze06ZqU77yM5Y2V5L2N5Li65bCP5pe2LOmFjee9ruS4ujDml7bvvIzkuI3kuIrmiqUtLT48dXBsb2FkVGltZT4yNDwvdXBsb2FkVGltZT48L2FwcGxpc3Q+PC9zd2l0Y2g+PGNvbmZpZz48YXJndW1lbnRzPjwhLS1hcmd1bWVudOeahOW/hemAieWSjOW4uOeUqOWPr+mAieWPguaVsCBrZXnpnIDnoa7lrpotLT48IS0t5b+F6YCJ5Ye95pWwLS0+PGFyZ3VtZW50PjxrZXk+T1M8L2tleT48dmFsdWU+bW88L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5UUzwva2V5Pjx2YWx1ZT5tdDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5Pk1BQzwva2V5Pjx2YWx1ZT5tNzwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PklERkE8L2tleT48dmFsdWU+bTU8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5JTUVJPC9rZXk+PHZhbHVlPm0zPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+QU5EUk9JRElEPC9rZXk+PHZhbHVlPm0xPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+V0lGSTwva2V5Pjx2YWx1ZT5tdzwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PkFLRVk8L2tleT48dmFsdWU+bXA8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5BTkFNRTwva2V5Pjx2YWx1ZT5tbjwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS3lj6/pgInlh73mlbAtLT48YXJndW1lbnQ+PGtleT5TQ1dIPC9rZXk+PHZhbHVlPm1oPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PCEtLSBXaUZpIE5hbWUtLT48YXJndW1lbnQ+PGtleT5XSUZJU1NJRDwva2V5Pjx2YWx1ZT5tajwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwhLS0gV2lGaSBNQUMtLT48YXJndW1lbnQ+PGtleT5XSUZJQlNTSUQ8L2tleT48dmFsdWU+bWw8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5PUEVOVURJRDwva2V5Pjx2YWx1ZT5tMDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PlRFUk08L2tleT48dmFsdWU+bWQ8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5PU1ZTPC9rZXk+PHZhbHVlPm1lPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+TEJTPC9rZXk+PHZhbHVlPm1tPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+U0RLVlM8L2tleT48dmFsdWU+bXY8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5SRURJUkVDVFVSTDwva2V5Pjx2YWx1ZT5vPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PC9hcmd1bWVudHM+PGV2ZW50cz48ZXZlbnQ+PCEtLTxuYW1lPm0xPC9uYW1lPi0tPjxrZXk+c3RhcnQ8L2tleT48dmFsdWU+bWI9c3RhcnQ8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjwvZXZlbnQ+PGV2ZW50PjwhLS08bmFtZT5lMTwvbmFtZT4tLT48a2V5PmVuZDwva2V5Pjx2YWx1ZT5tYj1lbmQ8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjwvZXZlbnQ+PC9ldmVudHM+PEFkcGxhY2VtZW50Pjxhcmd1bWVudD48a2V5PkFkcGxhY2VtZW50PC9rZXk+PHZhbHVlPnA8L3ZhbHVlPjx1cmxFbmNvZGU+ZmFsc2U8L3VybEVuY29kZT48aXNSZXF1aXJlZD5mYWxzZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50PjwvQWRwbGFjZW1lbnQ+PHZpZXdhYmlsaXR5YXJndW1lbnRzPjxhcmd1bWVudD48a2V5PkltcHJlc3Npb25JRDwva2V5Pjx2YWx1ZT52ZjwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlSZWNvcmQ8L2tleT48dmFsdWU+dmE8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5BZHZpZXdhYmlsaXR5RXZlbnRzPC9rZXk+PHZhbHVlPnZkPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eVRpbWU8L2tleT48dmFsdWU+MTwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlGcmFtZTwva2V5Pjx2YWx1ZT4yPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eVBvaW50PC9rZXk+PHZhbHVlPjM8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5BZHZpZXdhYmlsaXR5QWxwaGE8L2tleT48dmFsdWU+NDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlTaG93bjwva2V5Pjx2YWx1ZT41PC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eUNvdmVyUmF0ZTwva2V5Pjx2YWx1ZT42PC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eVNob3dGcmFtZTwva2V5Pjx2YWx1ZT43PC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eUZvcmdyb3VuZDwva2V5Pjx2YWx1ZT44PC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eVJlc3VsdDwva2V5Pjx2YWx1ZT52eDwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlDb25maWdBcmVhPC9rZXk+PHZhbHVlPnZoPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eUNvbmZpZ1RocmVzaG9sZDwva2V5Pjx2YWx1ZT52aTwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlWaWRlb0R1cmF0aW9uPC9rZXk+PHZhbHVlPnZiPC92YWx1ZT48dXJsRW5jb2RlPnRydWU8L3VybEVuY29kZT48aXNSZXF1aXJlZD50cnVlPC9pc1JlcXVpcmVkPjwvYXJndW1lbnQ+PGFyZ3VtZW50PjxrZXk+QWR2aWV3YWJpbGl0eVZpZGVvUHJvZ3Jlc3M8L2tleT48dmFsdWU+dmM8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48YXJndW1lbnQ+PGtleT5BZHZpZXdhYmlsaXR5VmlkZW9QbGF5VHlwZTwva2V5Pjx2YWx1ZT52ZzwvdmFsdWU+PHVybEVuY29kZT50cnVlPC91cmxFbmNvZGU+PGlzUmVxdWlyZWQ+dHJ1ZTwvaXNSZXF1aXJlZD48L2FyZ3VtZW50Pjxhcmd1bWVudD48a2V5PkFkdmlld2FiaWxpdHlWaWRlb1Byb2dyZXNzUG9pbnQ8L2tleT48dmFsdWU+dmo8L3ZhbHVlPjx1cmxFbmNvZGU+dHJ1ZTwvdXJsRW5jb2RlPjxpc1JlcXVpcmVkPnRydWU8L2lzUmVxdWlyZWQ+PC9hcmd1bWVudD48L3ZpZXdhYmlsaXR5YXJndW1lbnRzPjwvY29uZmlnPjxzZXBhcmF0b3I+JmFtcDs8L3NlcGFyYXRvcj48IS0tPHNlcGFyYXRvcj4mYW1wOzwvc2VwYXJhdG9yPi0tPjxlcXVhbGl6ZXI+PTwvZXF1YWxpemVyPjwhLS3lpoLmnpzorr7nva50cnVlICAgdGltZVN0YW1wZXLkvb/nlKjnp5ItLT48dGltZVN0YW1wVXNlU2Vjb25kPnRydWU8L3RpbWVTdGFtcFVzZVNlY29uZD48L2NvbXBhbnk+PC9jb21wYW5pZXM+PC9jb25maWc+";
    NSData *data = [[NSData alloc] initWithBase64EncodedString:xml64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    _sdkConfig = [GDT_XMLReader sdkConfigWithData:data];
}

- (void)initViewabilityService {
    _viewabilityConfig = [GDTVAMonitorConfig defaultConfig];
    
    if(_sdkConfig.viewability) {
        _viewabilityConfig.maxDuration = _sdkConfig.viewability.maxExpirationSecs; // 总时长
        _viewabilityConfig.monitorInterval = _sdkConfig.viewability.intervalTime * 0.001; // 转换秒
        _viewabilityConfig.exposeValidDuration = _sdkConfig.viewability.viewabilityTime; //目标曝光时间
        _viewabilityConfig.videoExposeValidDuration = _sdkConfig.viewability.viewabilityVideoTime; //目标曝光时间
        _viewabilityConfig.maxUploadCount = _sdkConfig.viewability.maxAmount;
        _viewabilityConfig.vaildExposeShowRate = _sdkConfig.viewability.viewabilityFrame * 0.01; //转换百分比

    }
    _viewabilityService = [[GDTViewabilityService alloc] initWithConfig:_viewabilityConfig];
    [_viewabilityService processCacheMonitorsWithDelegate:self];
    
}

- (void)initQueue
{
    _sendQueue = [[GDT_TaskQueue alloc] initWithIdentity:SEND_QUEUE_IDENTITY];
    _failedQueue = [[GDT_TaskQueue alloc] initWithIdentity:FAILED_QUEUE_IDENTITY];
    
    [_sendQueue loadData];
    [_failedQueue loadData];
    
}

- (void)initTimer
{
    NSInteger failedQueueInterval = self.sdkConfig.offlineCache.queueExpirationSecs;
    if (!failedQueueInterval) {
        failedQueueInterval = DEFAULT_FAILED_QUEUE_TIMER_INTERVAL;
    }
    _failedQueueTimer = [NSTimer scheduledTimerWithTimeInterval:failedQueueInterval
                                                         target:self
                                                       selector:@selector(handleFailedQueueTimer:)
                                                       userInfo:nil
                                                        repeats:YES];
    
    _sendQueueTimer = [NSTimer scheduledTimerWithTimeInterval:DEFAULT_SEND_QUEUE_TIMER_INTERVAL
                                                       target:self
                                                     selector:@selector(handleSendQueueTimer:)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)handleFailedQueueTimer:(NSTimer *)timer
{
    @try {
        NSInteger netStatus = [self.trackingInfoService networkCondition];
        if (netStatus == NETWORK_STATUS_NO) {
            return;
        }
        while ([self.failedQueue count] > 0) {
            GDT_Task *task = [self.failedQueue pop];
            
            GDT_Company *company = [self confirmCompany:task.url];
            [GDT_Log log:@"##failed_queue_url:%@" ,task.url];
            NSInteger offlineCacheExpiration = company.MMASwitch.offlineCacheExpiration;
            NSInteger now = [[[NSDate alloc] init] timeIntervalSince1970];
            if (task.timePoint + offlineCacheExpiration < now) {
                continue;
            }
            NSURL *URL = [NSURL URLWithString:task.url];
            NSURLCacheStoragePolicy policy = NSURLRequestReloadIgnoringCacheData;
            NSURLRequest *request = [NSURLRequest requestWithURL:URL cachePolicy:policy timeoutInterval:self.sdkConfig.offlineCache.timeout];
            MMA_RQOperation *operation = [MMA_RQOperation operationWithRequest:request];
            
            operation.completionHandler = ^(__unused NSURLResponse *response, NSData *data, NSError *error)
            {
                if (error) {
                    task.failedCount++;
                    if (task.failedCount <= FAILED_QUEUE_TRY_SEND_COUNT) {
                        [self.failedQueue push:task];
                    }
                } else {
                    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SUCCEED object:nil];
                }
            };
            [[GDT_RequestQueue mainQueue] addOperation:operation];
        }
    }
    @catch (NSException *exception) {
    }
}

- (void)handleSendQueueTimer:(NSTimer *)timer
{
    NSInteger netStatus = [self.trackingInfoService networkCondition];
    if (netStatus == NETWORK_STATUS_NO) {
        return;
    }
    if ([self.sendQueue count] >= self.sdkConfig.offlineCache.length) {
        while ([self.sendQueue count] > 0) {
            GDT_Task *task = [self.sendQueue pop];
            [GDT_Log log:@"##send_queue_url:%@" ,task.url];
            NSURL *URL = [NSURL URLWithString:task.url];
            NSURLCacheStoragePolicy policy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
            NSURLRequest *request = [NSURLRequest requestWithURL:URL cachePolicy:policy timeoutInterval:self.sdkConfig.offlineCache.timeout];
            MMA_RQOperation *operation = [MMA_RQOperation operationWithRequest:request];
            
            operation.completionHandler = ^(__unused NSURLResponse *response, NSData *data, NSError *error)
            {
                if (error) {
                    task.failedCount++;
                    task.hasFailed = true;
                    [self.failedQueue push:task];
                } else {
                    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SUCCEED object:nil];
                    
                }
            };
            [[GDT_RequestQueue mainQueue] addOperation:operation];
        }
    }
}

- (void)didEnterBackground
{
    if (self.sendQueueTimer) {
        [self.sendQueueTimer invalidate];
        self.sendQueueTimer = nil;
    }
    
    if (self.failedQueueTimer) {
        [self.failedQueueTimer invalidate];
        self.failedQueueTimer = nil;
    }
    
    [self.sendQueue persistData];
    [self.failedQueue persistData];
    
}

- (void)willTerminate
{
    [self didEnterBackground];
}

- (void)didEnterForeground
{
    [self initSdkConfig];
//    [self initQueue];
    [self initTimer];
//    [self openLBS];
}


- (void)enableLog:(BOOL)enableLog {
    [GDT_Log setDebug:enableLog];
}

- (BOOL)clearAll
{
    [self.failedQueue clear];
    [self.sendQueue clear];
    return YES;
}

- (BOOL)clearErrorList
{
    [self.failedQueue clear];
    return YES;
}

//- (void)openLBS
//{
//    [self.sdkConfig.companies enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
//        MMA_Company *company = (MMA_Company *)obj;
//        if (company.MMASwitch.isTrackLocation) {
//            [LocationService sharedInstance];
//            self.isTrackLocation = true;
//        }
//    }];
//}

- (NSString *)getAdIDForURL:(NSString *)url {
    @try {
        GDT_Company *company = [self confirmCompany:url];
        if(!company) {
            [GDT_Log log:@"%@" ,@"company is nil,please check your 'sdkconfig.xml' file"];
            return nil;
        }
        // 找出impressionID
        NSArray *arr = [url componentsSeparatedByString:company.separator];
        for (int i = 1; i<[arr count]; i++) {
            NSString *str = [arr objectAtIndex:i];
            GDT_Argument *argument = [company.config.Adplacement valueForKey:AD_PLACEMENT];
            NSString *key = argument.value;
            if(key && key.length) {
                /*过滤字段的*/
                NSString *checkStr= [NSString stringWithFormat:@"%@%@",key,company.equalizer];//枚举满足关键key+赋值符号的字符串（例如：z=）
                BOOL hasPrefix = [str hasPrefix:checkStr];//监测按分隔符拆分的数组元素，是否包含checkStr前缀。
                if (hasPrefix){
                    str = [str substringFromIndex:key.length];
                    return str;
                }
            }
            
        }
        
        return nil;
    } @catch (NSException *exception) {
        [GDT_Log log:@"##exception getImpressionIDForURL:%@" ,exception];
        return nil;
    }
    
    /********************************************/
}


// 去掉字段2g 如果有2j 去掉AdMeasurability Adviewability AdviewabilityEvents ImpressionID四个字段生成链接
- (VBOpenResult *)vbFilterURL:(NSString *)url isForViewability:(BOOL)viewability isVideo:(BOOL)isVideo {
    @try {
        
        GDT_Company *company = [self confirmCompany:url];
        VBOpenResult *res = [[VBOpenResult alloc] init];
        res.config = self.viewabilityConfig; // 初始化默认配置为当前的配置
        res.url = url;
        res.canOpen = NO;
        
        if(!company) {
            res.canOpen = NO;
            res.url = @"";
            res.redirectURL = @"";
            return res;
        }
        
        NSMutableString *trackURL = [NSMutableString stringWithString:url];
        
        /******确保TRACKING_KEY_REDIRECTURL参数传递放在url最后面*******/
        NSString *redirecturl = @"";
        //        for (MMA_Argument *argument in [company.config.arguments objectEnumerator]) {
        GDT_Argument *argument = [company.config.arguments objectForKey:TRACKING_KEY_REDIRECTURL];
        NSString *queryArgsKey = [argument value];
        if([argument.key isEqualToString:TRACKING_KEY_REDIRECTURL]&&argument.isRequired){
            NSString *redirect_key = [NSString stringWithFormat:@"%@%@%@",company.separator,queryArgsKey,company.equalizer];
            NSRange ff = [trackURL rangeOfString:redirect_key];
            if (ff.location !=NSNotFound ) {
                NSRange u_range = [trackURL rangeOfString:redirect_key];
                NSString *subStr = [trackURL substringToIndex:u_range.location];
                redirecturl = [trackURL substringFromIndex:u_range.location];
                trackURL = [NSMutableString stringWithString:subStr];
                res.redirectURL = redirecturl;
            }
        }
        
        NSString *noRedirectURL = [NSString stringWithString:trackURL];
        NSMutableString *filterURL = [[NSMutableString alloc] initWithString:noRedirectURL];
        
        NSArray *exposeKeys = @[IMPRESSIONID];
        
//        NSArray *viewabilityKeys = @[AD_MEASURABILITY,
//                                     AD_VB,
//                                     AD_VB_RESULT,
//                                     AD_VB_EVENTS,
//                                     IMPRESSIONID];
        
//        NSArray *ignoreKeys    =   @[AD_VB_ENABLE,
//                                    AD_VB_AREA,
//                                    AD_VB_THRESHOLD,
//                                    AD_VB_VIDEODURATION,
//                                     AD_VB_VIDEOPOINT,
//                                     AD_VB_RECORD
//                                     ];
        
     
        //viewability 监测
        if(viewability) {
            res.canOpen = YES;
            NSString *separator = company.separator;
            NSString *equalizer = company.equalizer;
            for (GDT_Argument *argument in [company.config.viewabilityarguments objectEnumerator]) {
                NSString *key = argument.key;
                NSString *reWriteString = @"";
                if (key && key.length) {
                    NSString *value = argument.value;
                    if (value && value.length) {
                        NSString *replacedString = @"";
                        if([key isEqualToString:AD_VB_AREA]) { //2v
                            NSString *parValue = [self getValueFromUrl:filterURL withCompany:company withArgumentKey:value];
                            NSScanner* scan = [NSScanner scannerWithString:parValue];
                            float val;
                            BOOL isfloat = [scan scanFloat:&val] && [scan isAtEnd];
                            if(parValue && parValue.length && isfloat && parValue.floatValue > 0 && parValue.floatValue < 100) {
                                res.config.vaildExposeShowRate = val * 0.01;
                                continue;

                            } else {
                                reWriteString = [NSString stringWithFormat:@"%@%@%@%g",separator,value,equalizer,res.config.vaildExposeShowRate * 100];
                            }
                        } else if([key isEqualToString:AD_VB_THRESHOLD]) { //2u
                            NSString *parValue = [self getValueFromUrl:filterURL withCompany:company withArgumentKey:value];
                            NSScanner* scan = [NSScanner scannerWithString:parValue];
                            float val;
                            BOOL isfloat = [scan scanFloat:&val] && [scan isAtEnd];
                            //配置已存在覆盖video和普通view
                            if(parValue && parValue.length && isfloat && parValue.floatValue > 0) {
                                res.config.videoExposeValidDuration = val;
                                res.config.exposeValidDuration = val;
                                continue;

                            } else {
                                reWriteString = [NSString stringWithFormat:@"%@%@%@%g",separator,value,equalizer,isVideo ? res.config.videoExposeValidDuration : res.config.exposeValidDuration];

                            }
                            
                        } else if([key isEqualToString:AD_VB_VIDEODURATION]) { //2w
                            NSString *parValue = [self getValueFromUrl:filterURL withCompany:company withArgumentKey:value];
                            NSScanner* scan = [NSScanner scannerWithString:parValue];
                            float val;
                            BOOL isfloat = [scan scanFloat:&val] && [scan isAtEnd];
                            //值大于0 才赋值
                            if(parValue && parValue.length && isfloat && parValue.floatValue > 0) {
                                res.config.videoDuration = val;
                            }
                            continue;
                            //config key. get need upload viewability info or not from this key
                        } else if([key isEqualToString:AD_VB_RECORD]) { //va
                            NSString *parValue = [self getValueFromUrl:filterURL withCompany:company withArgumentKey:value];
                            NSScanner* scan = [NSScanner scannerWithString:parValue];
                            int val;
                            BOOL isInt = [scan scanInt:&val] && [scan isAtEnd];
                            //值为0 才设置不监测数据,否则都使用默认值监测
                            if(parValue && parValue.length && isInt && val == 0) {
                                res.config.needRecordData = NO;
                            }
                            continue;
                            //config key. get config from url according to this key.ep.1111
                        } else if([key isEqualToString:AD_VB_VIDEOPOINT]) { //2x
                            NSString *parValue = [self getValueFromUrl:filterURL withCompany:company withArgumentKey:value];
                            // 值的长度必须为四位才赋值,每位只能为1才会添加相关点监测.
                            if(parValue && parValue.length == 4) {
                                VAVideoProgressTrackType type = VAVideoProgressTrackTypeNone;
                                for (int i = 0; i < 4; i++) {
                                    NSString *flag = [parValue substringWithRange:NSMakeRange(i, 1)];
                                    if([flag isEqualToString: @"1"]) {
                                        type = type | ([flag integerValue] << i);
                                    } else if([flag isEqualToString: @"0"]){
                                        continue;
                                    } else {
                                        type = VAVideoProgressTrackTypeNone;
                                        break;
                                    }
                                }
                                res.config.trackProgressPointsTypes = type;
                            }
                            continue;
                            // if include progress upload key in config.xml, set YES to track progress event.
                        } else if([key isEqualToString:AD_VB_VIDEOPROGRESS]) { //2a
                            res.config.needRecordProgress = YES;
                        }
                        // if contain enable key in url set viewability service OPEN(yes)
//                        else if ([key isEqualToString:AD_VB_ENABLE]) { //2p
//                            if([self isExitKey:value inURL:url withCompany:company]) {
//                                res.canOpen = YES;
//                            } else {
//                                res.canOpen = NO;
//                            }
//                            continue;
//                        }
                        [filterURL replaceOccurrencesOfString:[NSString stringWithFormat:@"%@%@%@[^%@]*", separator, value, equalizer, separator] withString:replacedString options:NSRegularExpressionSearch range:NSMakeRange(0, filterURL.length)];
                        if(reWriteString && reWriteString.length) {
                            [filterURL appendString:reWriteString];
                        }
                    }
                }
            }
            // 曝光监测
        } else {
            for (NSString *parmater in exposeKeys) {
                argument = [company.config.viewabilityarguments valueForKey:parmater];
                NSString *key = argument.key;
                if(key && key.length) {
                    if(argument.value && argument.value.length) {
                        NSString *regular = [NSString stringWithFormat:@"%@%@%@[^%@]*", company.separator, argument.value, company.equalizer, company.separator];
                        [filterURL replaceOccurrencesOfString:regular withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, filterURL.length)];
                    }
                }
            }
            res.canOpen = NO;
        }
        res.url = filterURL;
        return res;
    } @catch (NSException *exception) {
        [GDT_Log log:@"##exception vbFilterURL:%@" ,exception];
    }
    
}

// 视频Viewaility曝光请求: 视频曝光判断是否含有相关AdViewabilityEvents字段决定是否开启viewability 不需要redirectURL
- (void)viewVideo:(NSString *)url ad:(UIView *)adView videoPlayType:(NSInteger)type edid:(NSString *)edid
{
    [_viewabilityService start];
    BOOL viewability = YES;
    VBOpenResult *result = [self vbFilterURL:url isForViewability:viewability isVideo:YES];
    
    [self view:url ad:adView isVideo:YES videoPlayType:type handleResult:result edid:edid];
}

// 停止可见监测
- (void)stop:(NSString *)url {
    @try {
        NSString *adID = [self getAdIDForURL:url];
        if(!adID || !adID.length) {
            [GDT_Log log:@"adplacement get failed: %@" ,@"no adplacement"];
            return;
        }
        
        GDT_Company *company = [self confirmCompany:url];
        NSString *domain = company.domain[0];
        if(!domain || !domain.length) {
            domain = @"";
        }

        NSString *monitorKey = [NSString stringWithFormat:@"%@-%@",domain,adID];

        [_viewabilityService stopGDTVAMonitor:monitorKey];
    } @catch (NSException *exception) {
        [GDT_Log log:@"##stop: exception:%@" ,exception];
    }
}


// viewability曝光不需要redirectURL已在前面剔除,普通曝光需要redirectURL
- (void)view:(NSString *)url ad:(UIView *)adView isVideo:(BOOL)isVideo videoPlayType:(NSInteger)type handleResult:(VBOpenResult *)result edid:(NSString *)edid
{
    @try {
        /**
         *  获取是否含有使用viewability字段
         */
        result.config.videoPlayType = type;
    
        

        BOOL useViewabilityService = result.canOpen;
        GDT_Company *company = [self confirmCompany:url];
//        ==========
        result.config.trackPolicy = company.MMASwitch.viewabilityTrackPolicy;
        if(!company) {
            [GDT_Log log:@"%@" ,@"company is nil,please check your 'sdkconfig.xml' file"];
            return;
        }
        
        /**
         *  获取广告位ID,如果没有扔回MMA
         */
        NSString *adID = [self getAdIDForURL:url];
        if(!adID || !adID.length) {
            [self filterURL:url edid:edid];
            [GDT_Log log:@"adplacement get failed: %@" ,@"no adplacement"];
            return;
        }
        
        NSString *domain = company.domain[0];
        if(!domain || !domain.length) {
            domain = @"";
        }
        
        /**
         *  拼接impressionID
         */
        NSString *impressKey = [NSString stringWithFormat:@"%@-%@",domain,adID];
        
        //iOS:MD5(edid+广告位ID+时间戳（ms）+随机字符串（UUID））
        NSString * timestamp = [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970] * 1000];
        NSString * compString = [NSString stringWithFormat:@"%@%@%@%@", edid, adID, timestamp, [[NSUUID UUID] UUIDString]];
        NSString *impressID  = [GDT_Helper md5HexDigest:compString];
        _impressionDictionary[impressKey] = impressID;
        
        /**
         *  发送正常的url 监测使用去噪impressionID曝光url,拼接AD_VB (2f),AD_VB_RESULT(vx)
         */
        [self filterURL:[self handleImpressURL:result.url impression:impressID redirectURL:result.redirectURL additionKey:YES] edid:edid];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_EXPOSE object:nil];
        
        /**
         *  Viewability功能模块
         */
        if(useViewabilityService) {
            
            NSMutableDictionary *keyvalueAccess = [NSMutableDictionary dictionary];
            [VIEW_ABILITY_KEY enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                GDT_Argument *argument = company.config.viewabilityarguments[obj];
                if(argument.key&& argument.key.length && argument.value && argument.value.length) {
                    keyvalueAccess[obj] = argument.value;
                }
            }];
            
            // 如果view非法或为空 不可测量参数置为0
            if(!adView || ![adView isKindOfClass:[UIView class]]) {
                
                NSDictionary *dictionary = @{
                                             AD_VB_EVENTS : @"[]",
                                             AD_VB : @"0",
                                             AD_VB_RESULT : @"2",
                                             IMPRESSIONID : impressID,
                                             AD_MEASURABILITY : @"0"
                                             };
                NSMutableDictionary *accessDictionary = [NSMutableDictionary dictionary];
                [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString * key, id obj, BOOL * _Nonnull stop) {
                    NSString *accessKey = keyvalueAccess[key];
                    if(accessKey && accessKey.length) {
                        accessDictionary[accessKey] = obj;
                    }
                }];
                NSString *url = [self monitorHandleWithURL:result.url data:accessDictionary redirectURL:@""];
                [self filterURL:url edid:edid];
            } else {
                GDTVAMonitor *monitor = [GDTVAMonitor monitorWithView:adView isVideo:isVideo url:result.url redirectURL:@"" impressionID:impressID adID:adID keyValueAccess:[keyvalueAccess copy] config:result.config domain:domain edid:edid];
                monitor.delegate = self;
                [_viewabilityService addGDTVAMonitor:monitor];
            }
            
        }
        
        
        
    } @catch (NSException *exception) {
        [GDT_Log log:@"##view:ad: exception:%@" ,exception];
        
    }
}

//Viewability可视化监测Delegate 接收数据
- (void)monitor:(GDTVAMonitor *)monitor didReceiveData:(NSDictionary *)monitorData edid:(NSString *)edid
{
    NSString *url = [self monitorHandleWithURL:monitor.url data:monitorData redirectURL:monitor.redirectURL];
    
    NSLog(@"viewabilityURL-----------------------%@",url);

    [self filterURL:url edid:edid];
}

- (NSString *)handleImpressURL:(NSString *)url impression:(NSString *)impressionID redirectURL:(NSString *)redirectURL additionKey:(BOOL)additionKey {
    GDT_Company *company = [self confirmCompany:url];
    NSMutableString *trackURL = [NSMutableString stringWithString:url];
    GDT_Argument *impressionArgument = [company.config.viewabilityarguments valueForKey:IMPRESSIONID];
    
    if(impressionArgument.value && impressionID && impressionID.length) {
        [trackURL appendFormat:@"%@%@%@%@",company.separator,impressionArgument.value,company.equalizer,impressionID];
    }
    
    if(additionKey) {
        GDT_Argument *adViewability = [company.config.viewabilityarguments valueForKey:AD_VB];
        if(adViewability.value && adViewability.value.length) {
            [trackURL appendFormat:@"%@%@",company.separator,adViewability.value];
        }
        
        GDT_Argument *adViewabilityResult = [company.config.viewabilityarguments valueForKey:AD_VB_RESULT];
        if(adViewabilityResult.value && adViewabilityResult.value.length) {
            [trackURL appendFormat:@"%@%@%@%@",company.separator,adViewabilityResult.value,company.equalizer,@"0"];
        }
    }
    
    
    if (redirectURL !=nil&&![redirectURL isEqualToString:@""]) {
        [trackURL appendString:redirectURL];
    }
    
    return trackURL;
}

// 处理监测数据 忽略redirectURL 但是没有去掉参数
- (NSString *)monitorHandleWithURL:(NSString *)url data:(NSDictionary *)monitorData redirectURL:(NSString *)redirectURL {
    @try {
        
        GDT_Company *company = [self confirmCompany:url];
        NSMutableString *trackURL = [NSMutableString stringWithString:url];
        
        [monitorData enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString * obj, BOOL * _Nonnull stop) {
            [trackURL appendFormat:@"%@%@%@%@",company.separator,key,company.equalizer,[GDT_Helper URLEncoded:obj]];
        }];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_VB object:nil];
        
//        NSLog(@"-----------------------%@",trackURL);
        //        [self filterURL:trackURL];
        return trackURL;
    } @catch (NSException *exception) {
        [GDT_Log log:@"##monitorrHandleWithURL exception:%@" ,exception];
        
    }
}

// 从url 获取是否存在关键字key
- (BOOL)isExitKey:(NSString *)key inURL:(NSString *)url withCompany:(GDT_Company *)company {
    if (!key || !key.length) {
        return 0;
    }
    NSString *separator = company.separator;
    NSString *equalizer = company.equalizer;
    NSString *prefix= [NSString stringWithFormat:@"%@%@%@",separator,key,equalizer];
    return [url rangeOfString:prefix].location != NSNotFound;
}

// 从url 获取配置相关参数后面具体的值
- (NSString *)getValueFromUrl:(NSString *)url withCompany:(GDT_Company *)company withArgumentKey:(NSString *)key
{
    if (!key || !key.length) {
        return 0;
    }
    
    NSString *separator = company.separator;
    NSString *equalizer = company.equalizer;
    NSString *prefix= [NSString stringWithFormat:@"%@%@%@",separator,key,equalizer];
    NSScanner *scanner = [NSScanner scannerWithString:url];
    NSString *value;

    if([scanner scanUpToString:prefix intoString:nil]) {
        [scanner scanString:prefix intoString:nil];
        [scanner scanUpToString:separator intoString:&value];
    }
    return value;
}


- (void)filterURL:(NSString *)url edid:(NSString *)edid
{
    if ([self confirmCompany:url] == nil) {
        [GDT_Log log:@"%@" ,@"company is nil,please check your 'sdkconfig.xml' file"];
        return;
    }
    
    [self pushTask:url edid:edid];
}

- (GDT_Company *)confirmCompany:(NSString *)url
{
    GDT_Company *company = nil;
    NSString *host = [[NSURL URLWithString:url] host];
    
    for (GDT_Company *__company in [self.sdkConfig.companies objectEnumerator]) {
        for (NSString *domain in __company.domain) {
            /*将公司domain的匹配逻辑改为host的suffix匹配，避免冒充域名的漏洞。*/
            //         if ([host rangeOfString:domain].length > 0) {
            if ([host hasSuffix:domain]) {
                company = __company;
                break;
            }
            /* */
        }
    }
    return company;
}


- (void)pushTask: (NSString *)url edid:(NSString *)edid
{
    @try {
        NSString *trackURL = [self generateTrackingURL:url edid:edid];
        GDT_Task *task = [[GDT_Task alloc] init];
        task.url = trackURL;
        task.timePoint = [[[NSDate alloc] init] timeIntervalSince1970];
        task.failedCount = 0;
        task.hasFailed = false;
        task.hasLock = false;
        [self.sendQueue push:task];
    }
    @catch (NSException *exception) {
        [GDT_Log log:@"##pushTask exception:%@" ,exception];
    }
}


- (NSString *)generateTrackingURL:(NSString *)url edid:(NSString *)edid
{
    
    GDT_Company *company = [self confirmCompany:url] ;
    NSMutableString *trackURL = [NSMutableString stringWithString:url];
    
    /******确保TRACKING_KEY_REDIRECTURL参数传递放在url最后面*******/
    NSString *redirecturl = @"";
    for (GDT_Argument *argument in [company.config.arguments objectEnumerator]) {
        NSString *queryArgsKey = [(GDT_Argument *)[company.config.arguments objectForKey:argument.key] value];
        if([argument.key isEqualToString:TRACKING_KEY_REDIRECTURL]&&argument.isRequired){
            NSString *redirect_key = [NSString stringWithFormat:@"%@%@%@",company.separator,queryArgsKey,company.equalizer];
            NSRange ff = [trackURL rangeOfString:redirect_key];
            if (ff.location !=NSNotFound ) {
                NSRange u_range = [trackURL rangeOfString:redirect_key];
                NSString *subStr = [trackURL substringToIndex:u_range.location];
                redirecturl = [trackURL substringFromIndex:u_range.location];
                trackURL = [NSMutableString stringWithString:subStr];
            }
        }
    }
    /********************************************/
    
    
    /*确保过滤掉xml文件里需要重新拼接的字段*/
    NSArray *arr = [trackURL componentsSeparatedByString:company.separator];
    for (int i = 1; i<[arr count]; i++) {
        NSString *str = [arr objectAtIndex:i];
        for (GDT_Argument *argument in [company.config.arguments objectEnumerator]) {
            
            NSString *queryArgsKey = [(GDT_Argument *)[company.config.arguments objectForKey:argument.key] value];
            
            /*过滤字段的bug*/
            NSString *checkStr= [NSString stringWithFormat:@"%@%@",queryArgsKey,company.equalizer];//枚举满足关键key+赋值符号的字符串（例如：z=）
            BOOL hasPrefix = [str hasPrefix:checkStr];//监测按分隔符拆分的数组元素，是否包含checkStr前缀。
            if (hasPrefix){//如果包含前缀，从原始串中删除该字段（分隔符+符合格式的字段）
                NSString *deleteStr = [NSString stringWithFormat:@"%@%@",company.separator,str];
                NSRange deleteStrRange = [trackURL rangeOfString:deleteStr];
                if (deleteStrRange.location !=NSNotFound) {
                    [trackURL deleteCharactersInRange:deleteStrRange];
                }
            }
        }
    }
    /********************************************/
    
    for (GDT_Argument *argument in [company.config.arguments objectEnumerator]) {
        NSString *queryArgsKey = [(GDT_Argument *)[company.config.arguments objectForKey:argument.key] value];
        if ([argument.key isEqualToString:TRACKING_KEY_OS]) {
            [trackURL appendFormat:@"%@%@%@%d", company.separator, queryArgsKey, company.equalizer, TRACKING_KEY_OS_VALUE];
        } else if ([argument.key isEqualToString:TRACKING_KEY_IDFA] && IOSV >= IOS6) {
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer, edid];
        }
        else if ([argument.key isEqualToString:TRACKING_KEY_TS]) {
            /*增加了根据配置文件选择客户端传输的时间精度为妙或者毫秒*/
            NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970] * 1000];
            if (company.timeStampUseSecond) {//使用秒级
                timestamp = [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]];
            }
            /**/
            
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer, timestamp];
            
        }
        else if ([argument.key isEqualToString:TRACKING_KEY_OSVS]) {
            
            NSString *osVersion = [[self.trackingInfoService systemVerstion] gtm_stringByEscapingForURLArgument];
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer, osVersion];
            
        } else if ([argument.key isEqualToString:TRACKING_KEY_TERM]) {
            
            NSString *term = [[self.trackingInfoService term] gtm_stringByEscapingForURLArgument];
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer, term];
            
        } else if ([argument.key isEqualToString:TRACKING_KEY_WIFI]) {
            
            NSInteger netStatus = [self.trackingInfoService networkCondition];
            [trackURL appendFormat:@"%@%@%@%d", company.separator, queryArgsKey, company.equalizer,(int)netStatus];
            
        } else if ([argument.key isEqualToString:TRACKING_KEY_WIFISSID]) {
            
            NSString *ssid = [[self.trackingInfoService wifiSSID] gtm_stringByEscapingForURLArgument];
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer,ssid];
            
        } else if ([argument.key isEqualToString:TRACKING_KEY_WIFIBSSID]) {
            
            NSString *bssid = [self.trackingInfoService wifiBSSID];
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer,[GDT_Helper md5HexDigest:bssid]];
            
        } else if ([argument.key isEqualToString:TRACKING_KEY_SCWH]) {
            
            NSString *scwh = [self.trackingInfoService scwh];
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer, scwh];
            
        } else if ([argument.key isEqualToString:TRACKING_KEY_AKEY]) {
            
            NSString *appKey = [[self.trackingInfoService appKey] gtm_stringByEscapingForURLArgument];
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer, appKey];
            
            
        } else if ([argument.key isEqualToString:TRACKING_KEY_ANAME]) {
            
            NSString *appName = [[self.trackingInfoService appName] gtm_stringByEscapingForURLArgument];
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer, appName];
            
        } else if ([argument.key isEqualToString:TRACKING_KEY_SDKVS]) {
            
            [trackURL appendFormat:@"%@%@%@%@", company.separator, queryArgsKey, company.equalizer, MMA_SDK_VERSION];
        }
    }
    
    // 添加签名加密模块
    NSString *signString = [[MMA_EncryptModule sharedEncryptModule] signUrl:trackURL];
    [GDT_Log log:@"signString: %@"  ,signString];
    [trackURL appendFormat:@"%@%@%@%@", company.separator, company.signature.paramKey, company.equalizer, signString];
    
    if (redirecturl !=nil&&![redirecturl isEqualToString:@""]) {
        [trackURL appendString:redirecturl];
    }
    
    [GDT_Log log:@"trackURL: %@"  ,trackURL];
    
    return trackURL;
    
}
@end
