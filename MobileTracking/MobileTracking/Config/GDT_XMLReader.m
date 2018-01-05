//
//  GDT_XMLReader.m
//  GDTMobileTracking
//
//  Created by Wenqi on 14-3-11.
//  Copyright (c) 2014年 Admaster. All rights reserved.
//

#import "GDT_XMLReader.h"
#import "GDTGDataXMLNode.h"

@interface GDT_XMLReader()

+ (void)initOfflineCache:(GDT_SDKConfig *)sdkConfig rootElement:(GDataXMLElement *)rootElement;
+ (void)initCompanies:(GDT_SDKConfig *)sdkConfig rootElement:(GDataXMLElement *)rootElement;

@end

@implementation GDT_XMLReader

+ (GDT_SDKConfig *)sdkConfigWithData:(NSData *)data
{
    
    GDT_SDKConfig *sdkConfig = [[GDT_SDKConfig alloc] init];
    
    GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:data  options:0 error:nil];
    [doc setCharacterEncoding:@"utf-8"];
    
    GDataXMLElement *rootElement = [doc rootElement];
    
    [self initOfflineCache:sdkConfig rootElement:rootElement];
    [self initViewability:sdkConfig rootElement:rootElement];
    
    [self initCompanies:sdkConfig rootElement:rootElement];
    
    return sdkConfig;
}

+ (NSInteger)stringToIntergetFromElement:(GDataXMLElement *)element name:(NSString *)name
{
    NSString *string = [[[element elementsForName:name] firstObject] stringValue] ;
    NSCharacterSet *characterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return  [[string stringByTrimmingCharactersInSet:characterSet] integerValue];
}

+(NSString *)StringTrimFromElement:(GDataXMLElement*)element name:(NSString*)name{
    NSString *string = [[[element elementsForName:name] firstObject] stringValue] ;
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (void)initOfflineCache:(GDT_SDKConfig *)sdkConfig rootElement:(GDataXMLElement *)rootElement
{
    NSArray *array = [rootElement elementsForName:@"offlineCache"];
    if (array == nil || [array count] == 0) {
        return;
    }
    
    GDataXMLElement *element = [array firstObject];
    GDT_OfflineCache *offlineCache = [[GDT_OfflineCache alloc] init];
    
    offlineCache.length = [self stringToIntergetFromElement:element name:@"length"];
    offlineCache.queueExpirationSecs =[self stringToIntergetFromElement:element name:@"queueExpirationSecs"];
    offlineCache.timeout = [self stringToIntergetFromElement:element name:@"timeout"];
    
    sdkConfig.offlineCache = offlineCache;
}

+ (void)initViewability:(GDT_SDKConfig *)sdkConfig rootElement:(GDataXMLElement *)rootElement {
    NSArray *array = [rootElement elementsForName:@"viewability"];
    if (array == nil || [array count] == 0) {
        return;
    }
    
    GDataXMLElement *element = [array firstObject];
    GDT_Viewability *viewability = [[GDT_Viewability alloc] init];
    
    viewability.intervalTime = [self stringToIntergetFromElement:element name:@"intervalTime"];
    viewability.viewabilityFrame = [self stringToIntergetFromElement:element name:@"viewabilityFrame"];
    
    viewability.viewabilityTime = [self stringToIntergetFromElement:element name:@"viewabilityTime"];
    viewability.viewabilityVideoTime = [self stringToIntergetFromElement:element name:@"viewabilityVideoTime"];
    
    viewability.maxExpirationSecs = [self stringToIntergetFromElement:element name:@"maxExpirationSecs"];
    viewability.maxAmount = [self stringToIntergetFromElement:element name:@"maxAmount"];
    
    sdkConfig.viewability = viewability;
    
}

+ (void)initCompanies:(GDT_SDKConfig *)sdkConfig rootElement:(GDataXMLElement *)rootElement
{
    sdkConfig.companies = [NSMutableDictionary dictionary];
    NSArray *companys = [rootElement nodesForXPath:@"//companies/company" error:nil];
    
    for (GDataXMLElement *element in companys) {
        GDT_Company *company = [[GDT_Company alloc] init];
        
        
        company.name = [[[element elementsForName:@"name" ] firstObject] stringValue];
        company.jsurl = [[[element elementsForName:@"jsurl" ] firstObject] stringValue];
        company.jsname = [[[element elementsForName:@"jsname" ] firstObject] stringValue];
        
        company.domain = [NSMutableArray array];
        NSArray *urls = [element nodesForXPath:@"domain/url" error:nil];
        for (GDataXMLElement *url in urls) {
            [company.domain addObject:[url stringValue]];
        }
        
        company.signature = [[GDT_Signature alloc] init];
        company.signature.publicKey = [[[element nodesForXPath:@"signature/publicKey" error:nil] firstObject] stringValue];
        company.signature.paramKey = [[[element nodesForXPath:@"signature/paramKey" error:nil] firstObject] stringValue];
        
        company.separator = [[[element elementsForName:@"separator" ] firstObject] stringValue];
        company.equalizer = [[[element elementsForName:@"equalizer" ] firstObject] stringValue];
        if (company.equalizer == nil) {
            company.equalizer = @"";
        }
        
        if ([[element elementsForName:@"timeStampUseSecond" ] firstObject]) {
            company.timeStampUseSecond = [[[[element elementsForName:@"timeStampUseSecond" ] firstObject] stringValue] boolValue];
        } else {
            company.timeStampUseSecond = false;
        }
        
        company.MMASwitch = [[GDT_Switch alloc] init];
        
        company.MMASwitch.isTrackLocation = [[[[element nodesForXPath:@"switch/isTrackLocation" error:nil] firstObject] stringValue] boolValue];
        GDataXMLElement *offlineCacheExpiration = [[element elementsForName:@"switch"] firstObject];
        company.MMASwitch.offlineCacheExpiration = [self stringToIntergetFromElement:offlineCacheExpiration name:@"offlineCacheExpiration"];
        
        GDataXMLElement *viewabilityTrackPolicy = [[element elementsForName:@"switch"] firstObject];
        company.MMASwitch.viewabilityTrackPolicy = [self stringToIntergetFromElement:viewabilityTrackPolicy name:@"viewabilityTrackPolicy"];

        
        
        GDataXMLElement *encryptElement = [[element nodesForXPath:@"switch/encrypt" error:nil] firstObject];
        company.MMASwitch.encrypt = [NSMutableDictionary dictionary];
        for(GDataXMLElement *el  in [encryptElement children]){
            [company.MMASwitch.encrypt setValue:[el stringValue] forKey:[el name]];
        }
        
        company.config = [[GDT_Config alloc] init];
        
        company.config.arguments = [NSMutableDictionary dictionary];
        NSArray *arguments = [element nodesForXPath:@"config/arguments/argument" error:nil];
        for(GDataXMLElement *el  in arguments){
            GDT_Argument *argument = [[GDT_Argument alloc] init];
            argument.key = [self StringTrimFromElement:el name:@"key"];
            argument.value = [self StringTrimFromElement:el name:@"value"];
            argument.urlEncode = [[self StringTrimFromElement:el name:@"urlEncode"] boolValue];
            argument.isRequired = [[self StringTrimFromElement:el name:@"isRequired"] boolValue];
            [company.config.arguments setValue:argument forKey:argument.key];
        }
        
        company.config.events = [NSMutableDictionary dictionary];
        NSArray *events = [element nodesForXPath:@"config/events/event" error:nil];
        for(GDataXMLElement *el  in events){
            GDT_Event *event = [[GDT_Event alloc] init];
            event.key = [self StringTrimFromElement:el name:@"key" ];
            event.value = [self StringTrimFromElement:el name:@"value" ];
            event.urlEncode = [[self StringTrimFromElement:el name:@"urlEncode" ] boolValue];
            [company.config.events setValue:event forKey:event.key];
            
        }
        
        //        GDataXMLElement *impressionplaceElement = [[element nodesForXPath:@"config/Adplacement/argument" error:nil] firstObject];
        NSArray *impressionplaceElement = [element nodesForXPath:@"config/Adplacement/argument" error:nil];
        company.config.Adplacement = [NSMutableDictionary dictionary];
        for(GDataXMLElement *el  in impressionplaceElement){
            GDT_Argument *argument = [[GDT_Argument alloc] init];
            argument.key = [self StringTrimFromElement:el name:@"key" ];
            argument.value = [self StringTrimFromElement:el name:@"value" ];
            argument.urlEncode = [[self StringTrimFromElement:el name:@"urlEncode" ] boolValue];
            [company.config.Adplacement setValue:argument forKey:argument.key];
        }
        
        company.config.viewabilityarguments = [NSMutableDictionary dictionary];
        NSArray *viewabilityarguments = [element nodesForXPath:@"config/viewabilityarguments/argument" error:nil];
        for(GDataXMLElement *el  in viewabilityarguments){
            GDT_Argument *argument = [[GDT_Argument alloc] init];
            argument.key = [self StringTrimFromElement:el name:@"key"];
            argument.value = [self StringTrimFromElement:el name:@"value"];
            argument.urlEncode = [[self StringTrimFromElement:el name:@"urlEncode"] boolValue];
            argument.isRequired = [[self StringTrimFromElement:el name:@"isRequired"] boolValue];
            [company.config.viewabilityarguments setValue:argument forKey:argument.key];
        }
        
        [sdkConfig.companies setValue:company forKey:company.name];
    }
}


@end
