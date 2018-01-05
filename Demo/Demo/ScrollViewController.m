//
//  ScrollViewController.m
//  Demo
//
//  Created by master on 2017/6/27.
//  Copyright © 2017年 Admaster. All rights reserved.
//

#import "ScrollViewController.h"
#import "GDTMobileTracking.h"
@interface ScrollViewController ()
@property (weak, nonatomic) IBOutlet UIView *adView;

@end

@implementation ScrollViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//测试u字段点击拼接到最后 2g 有无情况下
//    NSString *url = @"http://vxyz.admaster.com.cn/pppp,2g1111,2j1111,2t1111,2k1111,2l1111,2m1111,2n1111,2o1111,2r1111,2s1111,2f1111,2a1111,1g1111,2d1111,2j1111,2h1111,2v60,2u1.8,2w15,2x0001,va1,b123456,uhttp://redirecturl.com";
    /* 去噪测试
     以下参数不覆盖原值: AdviewabilityEnable AdviewabilityConfigArea AdviewabilityConfigThreshold AdviewabilityVideoDuration AdviewabilityVideoProgressPoint AdviewabilityRecord
     */
//    NSString *url = @"http://v.admaster.com.cn/i/a90981,b1899467,c2,i0,m202,8a2,8b2,h,2j,2u2,2v50,2w15,2x1111,2d1234,va1";

    /* 去噪测试
     以下参数不覆盖原值: AdviewabilityEnable AdviewabilityConfigArea AdviewabilityConfigThreshold AdviewabilityVideoDuration AdviewabilityVideoProgressPoint AdviewabilityRecord
     */
//    NSString *url = @"http://v.admaster.com.cn/i/a90981,b1899467,c2,i0,m202,8a2,8b2,h,2p,2jtt,2w15,2x1101,2d1234,va1,2g0101,uhttp://www.baidu.com";
////        NSString *url2 = @"http://v.miaozhen.com/i/a90981,p1899467,c2,i0,m202,8a2,8b2,h,2p,2jtt,2w15,2x1101,2d1234,va1,2g0101";
//    NSString *url2 = @"http://v.admaster.com.cn/i/a90981,b1899467,c2,i0,m202,8a2,8b2,h,2p,2jtt,2w15,2x1101,2d1234,va1,2g0101";
    NSString *url = @"http://v.admaster.com.cn/i/a100170,b2178782,c2,i0,m202,8a2,8b1,2v50,2u2,h";
//    NSString *url = @"http://v.admaster.com.cn/i/a90981,b1899467,c2,i0,m202,8a2,8b2,h,2p,2jtt,2w15,2x1101,2d1234,va1,2g0101,uhttp://www.baidu.com";

//    NSLog(@"普通曝光链接");
//    [[GDTMobileTracking sharedInstance] view:url];
    
//    static BOOL vb = YES;
//    if(vb = !vb) {
//        printf("\n-----------------------viewability曝光链接\n");
//        [[GDTMobileTracking sharedInstance] view:url ad:_adView];
    
    //开始监测
    [[GDTMobileTracking sharedInstance] viewVideo:url ad:_adView videoPlayType:2 edid:@"edid6666"];
    
    //5秒后停止监测
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        NSLog(@"url stop concurrent:");
//        for(int i =0; i< 10;i++) {
//            dispatch_async(dispatch_get_global_queue(0, 0), ^{
//                [[GDTMobileTracking sharedInstance] stop:url];
//            });
//
//        }
//    });
//        [[GDTMobileTracking sharedInstance] view:url2 ad:_adView];

        
       
//    } else {
//        printf("\n-----------------------viewability视频曝光链接\n");
//        [[GDTMobileTracking sharedInstance] viewVideo:url ad:_adView videoPlayType:11];
//    }
    
//    NSLog(@"视频曝光链接");
//    [[GDTMobileTracking sharedInstance] viewVideo:url ad:_adView];
//    NSLog(@"点击链接");
//    [[GDTMobileTracking sharedInstance] click:url];

    // Do any additional setup after loading the view.
    //
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
