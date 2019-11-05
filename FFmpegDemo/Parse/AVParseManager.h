//
//  AVParseManager.h
//  FFmpegDemo
//
//  Created by 陈剑南 on 2019/11/4.
//  Copyright © 2019 gkoudai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

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

typedef enum :NSInteger {
    H264EncodeFormat,
    H265EncodeFormat,
} VideoEncodeFormat;


struct PraseVideoDataInfo {
    uint8_t     *data;
    int         dataSize;
    uint8_t     *extraData;
    int         extraDataSize;
    Float64     pts;
    Float64     time_base;
    int         videoRotate;
    int         fps;
    CMSampleTimingInfo timingInfo;
    VideoEncodeFormat  videoFormat;
};

struct PraseAudioDataInfo {
    uint8_t     *data;
    int         dataSize;
    int         channel;
    int         sampleRate;
    Float64     pts;

};

@interface AVParseManager : NSObject

- (instancetype)initWithPath:(NSString *)path;

- (void)startParseWithCompletionHandle:(void(^)(BOOL isVideoFrame, BOOL isFinished, struct PraseVideoDataInfo *videoInfo, struct PraseAudioDataInfo *audioInfo))handle;

- (void)startParseGetAVPacketWithCompletionHandle:(void(^)(BOOL isVideoFrame, BOOL isFinish, AVPacket packet))handle;

- (AVFormatContext *)getAVFromatContext;
- (int)getVideoStreamIndex;
- (int)getAudioStreamIndex;

@end

