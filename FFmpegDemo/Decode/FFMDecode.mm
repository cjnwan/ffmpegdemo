//
//  FFMDecode.m
//  FFmpegDemo
//
//  Created by 陈剑南 on 2019/11/5.
//  Copyright © 2019 gkoudai. All rights reserved.
//

#import "FFMDecode.h"

@interface FFMDecode() {
    AVFormatContext  *formatContext;
    AVCodecContext   *videoCodecContext;
    AVFrame          *videoFrame;
    
    
    int videoStreamIndex;
    BOOL isFindIDR;
    int64_t base_time;
}

@end

@implementation FFMDecode


AVBufferRef *hw_device_ctx = NULL;

static int InitHardwareDecoder(AVCodecContext *ctx, const enum AVHWDeviceType type) {
    int err  =av_hwdevice_ctx_create(&hw_device_ctx, type, NULL, NULL, 0);
    if (err < 0) {
        return err;
    }
    
    ctx->hw_device_ctx = av_buffer_ref(hw_device_ctx);
    return err;
}

static int GetAVStreamFPSTimeBase(AVStream *str) {
    CGFloat fps, timebase = 0;
    
    if (str->time_base.den && str->time_base.num) {
        timebase = av_q2d(str->time_base);
    } else if (str->codec->time_base.den && str->codec->time_base.num) {
        timebase = av_q2d(str->codec->time_base);
    }
    
    if(str->avg_frame_rate.den && str->avg_frame_rate.num) {
        fps = av_q2d(str->avg_frame_rate);
    } else if (str->r_frame_rate.den && str->r_frame_rate.num) {
        fps = av_q2d(str->r_frame_rate);
    } else {
        fps = 1.0/timebase;
    }
    
    return fps;
}

- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext videoStreamIndex:(int)videoStreamIndex {
    if (self = [super init]) {
        formatContext = formatContext;
        videoStreamIndex = videoStreamIndex;
        
        isFindIDR = NO;
        base_time = 0;
        
        [self initDecoder];
    }
    return self;
}

- (void)initDecoder {
    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    videoCodecContext = NULL;
    
    if (!videoCodecContext) {
        return;
    }
    
    videoFrame = av_frame_alloc();
    if (!videoFrame) {
        avcodec_close(videoCodecContext);
    }
}

- (void)startDecodeVideoDataWithAVPacket:(AVPacket)packet {
    if (packet.flags == 1 && isFindIDR == NO) {
        isFindIDR = YES;
        base_time = videoFrame->pts;
    }
    
    if (isFindIDR) {
        
    }
}

- (void)stopDecoder {
    
}

- (AVCodecContext *)createVideoiEncodrWithFormatContext:(AVFormatContext *)formatContext stream:(AVStream *)stream videoStreamIndex:(int)videoStreamIndex {
    
    AVCodecContext *context = NULL:
    AVCodec *codec = NULL:
    
    const char * codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
    
    enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
    if (type != AV_HWDEVICE_TYPE_VIDEOTOOLBOX) {
        
        return NULL;
    }
    
    int ret = av_find_best_stream(context, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
    if (ret < 0) {
        return NULL:
    }
    
    context = avcodec_alloc_context3(codec);
    if (!context) {
        return NULL;
    }
    
    ret = avcodec_parameters_to_context(context, formatContext->streams[videoStreamIndex]->codecpar);
    
    if (ret < 0) {
        return NULL;
    }
    
    ret = InitHardwareDecoder(context, type);
    
    if (ret < 0) {
        return NULL;
    }
    
    ret = avcodec_open2(context, codec, NULL);
    if (ret < 0) {
        
        return NULL;
    }
    
    return context;
    
}

- (void)startDecodeVideoDataWithAVPacket:(AVPacket)packet videoCodecContext:(AVCodecContext *)videoCodecContext videoFrame:(AVFrame *)videoFrame baseTime:(int64_t)baseTime videoStreamIndex:(int)videoStreamIndex {
    Float64 current_timestamp = [self getCurrentTimestamp];
    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    int fps = GetAVStreamFPSTimeBase(videoStream);
    
    
    avcodec_send_packet(videoCodecContext, &packet);
    while (0 == avcodec_receive_frame(videoCodecContext, videoFrame))
    {
        CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)videoFrame->data[3];
        CMTime presentationTimeStamp = kCMTimeInvalid;
        int64_t originPTS = videoFrame->pts;
        int64_t newPTS    = originPTS - baseTime;
        presentationTimeStamp = CMTimeMakeWithSeconds(current_timestamp + newPTS * av_q2d(videoStream->time_base) , fps);
        CMSampleBufferRef sampleBufferRef = [self convertCVImageBufferRefToCMSampleBufferRef:(CVPixelBufferRef)pixelBuffer
                                                                   withPresentationTimeStamp:presentationTimeStamp];
        
        if (sampleBufferRef) {
            if ([self.delegate respondsToSelector:@selector(getDecodeVideoDataByFFmpeg:)]) {
                [self.delegate getDecodeVideoDataByFFmpeg:sampleBufferRef];
            }
            
            CFRelease(sampleBufferRef);
        }
    }
}

- (void)freeAllResources {
    if (m_videoCodecContext) {
        avcodec_send_packet(videoCodecContext, NULL);
        avcodec_flush_buffers(videoCodecContext);
        
        if (videoCodecContext->hw_device_ctx) {
            av_buffer_unref(&videoCodecContext->hw_device_ctx);
            videoCodecContext->hw_device_ctx = NULL;
        }
        avcodec_close(videoCodecContext);
        videoCodecContext = NULL;
    }
    
    if (videoFrame) {
        av_free(videoFrame);
        videoFrame = NULL;
    }
}

#pragma mark - Other
- (CMSampleBufferRef)convertCVImageBufferRefToCMSampleBufferRef:(CVImageBufferRef)pixelBuffer withPresentationTimeStamp:(CMTime)presentationTimeStamp
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CMSampleBufferRef newSampleBuffer = NULL;
    OSStatus res = 0;
    
    CMSampleTimingInfo timingInfo;
    timingInfo.duration              = kCMTimeInvalid;
    timingInfo.decodeTimeStamp       = presentationTimeStamp;
    timingInfo.presentationTimeStamp = presentationTimeStamp;
    
    CMVideoFormatDescriptionRef videoInfo = NULL;
    res = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    if (res != 0) {
       
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
    }
    
    res = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                             pixelBuffer,
                                             true,
                                             NULL,
                                             NULL,
                                             videoInfo,
                                             &timingInfo, &newSampleBuffer);
    
    CFRelease(videoInfo);
    if (res != 0) {
        log4cplus_error(kModuleName, "%s: Create sample buffer failed!",__func__);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
        
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return newSampleBuffer;
}


- (Float64)getCurrentTimestamp {
    CMClockRef hostClockRef = CMClockGetHostTimeClock();
    CMTime hostTime = CMClockGetTime(hostClockRef);
    return CMTimeGetSeconds(hostTime);
}

@end
