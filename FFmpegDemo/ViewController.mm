//
//  ViewController.m
//  FFmpegDemo
//
//  Created by 陈剑南 on 2019/11/4.
//  Copyright © 2019 gkoudai. All rights reserved.
//

#import "ViewController.h"

#ifdef __cplusplus
extern "C" {
#endif
    
#include "libavutil/opt.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
    
#ifdef __cplusplus
};
#endif

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    av_register_all();
}


@end
