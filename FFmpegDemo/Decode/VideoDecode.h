//
//  VideoDecode.h
//  FFmpegDemo
//
//  Created by 陈剑南 on 2019/11/5.
//  Copyright © 2019 gkoudai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVParseManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface VideoDecode : NSObject


- (void)startDecode:(struct PraseVideoDataInfo *)videoInfo;

- (void)stopDecode;

@end

NS_ASSUME_NONNULL_END
