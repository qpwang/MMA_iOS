//
//  GDT_SDKConfig.h
//  GDTMobileTracking
//
//  Created by Wenqi on 14-3-11.
//  Copyright (c) 2014年 Admaster. All rights reserved.
//

#import <Foundation/Foundation.h>
/*--------------缓存队列设置--------------*/
@interface GDT_OfflineCache : NSObject

@property (nonatomic, assign) NSInteger length; // 发送队列长度，达到此队列长度时自动提交
@property (nonatomic, assign) NSInteger queueExpirationSecs; // 错误队列发送的重试时间间隔，单位为秒
@property (nonatomic, assign) NSInteger timeout; // 发送超时时间，单位为秒

@end
/*--------------缓存队列设置--------------*/
@interface GDT_Viewability : NSObject

@property (nonatomic, assign) NSInteger intervalTime; // viewability监测的时间间隔（ms）
@property (nonatomic, assign) NSInteger viewabilityFrame; // 满足viewability可见区域占总区域的百分比
@property (nonatomic, assign) NSInteger viewabilityTime; // 满足viewability总时长（s）
@property (nonatomic, assign) NSInteger viewabilityVideoTime; // 视频满足viewability总时长（s）
@property (nonatomic, assign) NSInteger maxExpirationSecs; // 当前广告位最大监测时长
@property (nonatomic, assign) NSInteger maxAmount; // 当前广告位最大上报数量

@end
/*--------------参数设置-----------------*/
@interface GDT_Argument : NSObject

@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, assign) Boolean urlEncode;
@property (nonatomic, assign) Boolean isRequired;

@end
/*--------------事件设置-----------------*/
@interface GDT_Event : NSObject

@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, assign) Boolean urlEncode;

@end
/*--------------事件、参数设置------------*/
@interface GDT_Config : NSObject

@property (nonatomic, strong) NSMutableDictionary *events;
@property (nonatomic, strong) NSMutableDictionary *arguments;
@property (nonatomic, strong) NSMutableDictionary *Adplacement;
@property (nonatomic, strong) NSMutableDictionary *viewabilityarguments;
@end
/*--------------加密签名设置--------------*/
@interface GDT_Signature : NSObject

@property (nonatomic,strong) NSString * publicKey;
@property (nonatomic,strong) NSString * paramKey;

@end
/*--------------公司开关设置--------------*/
@interface GDT_Switch : NSObject
@property (nonatomic, assign) NSInteger viewabilityTrackPolicy;
@property (nonatomic, assign) Boolean isTrackLocation;
@property (nonatomic, assign) NSInteger offlineCacheExpiration;
@property (nonatomic, strong) NSMutableDictionary *encrypt;

@end
/*--------------公司信息-----------------*/
@interface GDT_Company : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSMutableArray *domain;
@property (nonatomic, strong) GDT_Signature *signature;
@property (nonatomic, strong) GDT_Switch *MMASwitch;
@property (nonatomic, strong) GDT_Config *config ;
@property (nonatomic, strong) NSString *separator;
@property (nonatomic, strong) NSString *equalizer;
@property (nonatomic, assign) Boolean timeStampUseSecond;
@property (nonatomic, strong) NSString *jsname;
@property (nonatomic, strong) NSString *jsurl;


@end
/*--------------配置文件信息--------------*/
@interface GDT_SDKConfig : NSObject

@property(strong, nonatomic) GDT_OfflineCache *offlineCache; // 缓存队列设置
@property(strong, nonatomic) GDT_Viewability *viewability; // 缓存队列设置
@property(strong, nonatomic) NSMutableDictionary *companies; // <MMA_Company> 公司的配置信息

@end
