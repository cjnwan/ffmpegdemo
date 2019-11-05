//
//  VideoDecode.m
//  FFmpegDemo
//
//  Created by 陈剑南 on 2019/11/5.
//  Copyright © 2019 gkoudai. All rights reserved.
//

#import "VideoDecode.h"
#import <VideoToolbox/VideoToolbox.h>
#import <pthread.h>

typedef struct {
    CVPixelBufferRef outputPixelBuffer;
    int rotate;
    Float64 pts;
    int fps;
    int source_index;
}DecodeVideoInfo;

typedef struct {
    uint8_t *vps;
    uint8_t *sps;
    
    uint8_t *f_pps;
    uint8_t *r_pps;
    
    int vps_size;
    int sps_size;
    
    int f_pps_size;
    int r_pps_size;
    
    Float64 last_decode_pts;
}DecoderInfo;

@implementation VideoDecode {
    VTDecompressionSessionRef _decoderSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
    
    DecoderInfo _decodeInfo;
    pthread_mutex_t _decode_lock;
    
    uint8_t *_lastExtraData;
    int     _lastExtraDataSize;
       
    BOOL _isFirstFrame;
    
    
}

- (instancetype)init {
    if (self = [super init]) {
         _decodeInfo = {
                   .vps = NULL, .sps = NULL, .f_pps = NULL, .r_pps = NULL,
                   .vps_size = 0, .sps_size = 0, .f_pps_size = 0, .r_pps_size = 0, .last_decode_pts = 0,
               };
        _isFirstFrame = YES;
        pthread_mutex_init(&_decode_lock,NULL);
    }
    return self;
}

- (void)startDecode:(struct PraseVideoDataInfo *)videoInfo {
    if (videoInfo->extraData && videoInfo->extraDataSize) {
        uint8_t *extraData = videoInfo->extraData;
        int     size       = videoInfo->extraDataSize;
        
        
    }
}

- (VTDecompressionSessionRef)createDecoderWithVideoInfo:(PraseVideoDataInfo *)videoInfo                                                     videoDescRef:(CMVideoFormatDescriptionRef)videoDescRef
                                            videoformat:(OSType)videoformat
                                                   lock:(pthread_mutex_t)lock
                                               callback:(NSInteger)callback
                                            decoderInfo:(DecoderInfo)decodeInfo {
    pthread_mutex_lock(&lock);
    
    OSStatus status;
    
    if (videoInfo->videoFormat == H264EncodeFormat) {
        const uint8_t *const parameterSetPointers[2] = {decodeInfo.sps, decodeInfo.f_pps};
        const size_t parameterSetSizes[2] = {static_cast<size_t>(decodeInfo.sps_size), static_cast<size_t>(decodeInfo.f_pps_size)};
        status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, videoDescRef);
    }
}

@end
