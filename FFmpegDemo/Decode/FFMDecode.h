//
//  FFMDecode.h
//  FFmpegDemo
//
//  Created by 陈剑南 on 2019/11/5.
//  Copyright © 2019 gkoudai. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/opt.h"
    
#ifdef __cplusplus
};
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol FFMpegVideoDecoderDelegate <NSObject>

@optional

- (void)getDecodeVideoDataByFFmpeg:(CMSampleBufferRef)sampleBuffer;

@end

@interface FFMDecode : NSObject

@property (nonatomic, weak) id<FFMpegVideoDecoderDelegate>delegate

- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext videoStreamIndex:(int)videoStreamIndex;

- (void)startDecodeVideoDataWithAVPacket:(AVPacket)packet;

- (void)stopDecoder;

@end

NS_ASSUME_NONNULL_END
