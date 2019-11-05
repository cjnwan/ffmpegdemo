//
//  AVParseManager.m
//  FFmpegDemo
//
//  Created by 陈剑南 on 2019/11/4.
//  Copyright © 2019 gkoudai. All rights reserved.
//

#import "AVParseManager.h"

static const int kParseSupportMaxFps     = 60;
static const int kParseFpsOffSet         = 5;
static const int kParseWidth1920         = 1920;
static const int kParseHeight1080        = 1080;
static const int kParseSupportMaxWidth   = 3840;
static const int kParseSupportMaxHeight  = 2160;



@interface AVParseManager() {
    BOOL isStopParse;
    
    AVFormatContext  *formatContext;
    AVBitStreamFilterContext *bitFilterContext;
    
    int videoStreamIndex;
    int audioStreamIndex;
    
    int video_width, video_height, video_fps;
}

@end

@implementation AVParseManager

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

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        av_register_all();
    });
}

- (instancetype)initWithPath:(NSString *)path {
    if (self = [super init]) {
        [self prepareParseWithPath:path];
    }
    return self;
}

- (void)startParseWithCompletionHandle:(void (^)(BOOL, BOOL, struct PraseVideoDataInfo *, struct PraseAudioDataInfo *))handle {
    [self startParseWithFormatContext:formatContext
                     videoStreamIndex:videoStreamIndex
                     audioStreamIndex:audioStreamIndex
                    handle:handle];
}

- (void)startParseGetAVPacketWithCompletionHandle:(void (^)(BOOL, BOOL, AVPacket))handle {
    [self startParseGetAVPacketWithFormatContext:formatContext
                                videoStreamIndex:videoStreamIndex
                                audioStreamIndex:audioStreamIndex
                               completionHandler:handle];
}

- (void)stopParse {
    isStopParse = YES;
}

- (AVFormatContext *)getAVFromatContext {
    return formatContext;
}

- (int)getVideoStreamIndex {
    return videoStreamIndex;
}

- (int)getAudioStreamIndex {
    return audioStreamIndex;
}

- (void)prepareParseWithPath:(NSString *)path {
    formatContext = [self createFormatContextByFilePath:path];
    
    if (formatContext == NULL) {
        return;
    }
    
    // Get video stream index
    videoStreamIndex = [self getAVStreamIndexWithFormatContext:formatContext isVideoStream:YES];
    
    // Get video Stream
    
    AVStream *videoStream = formatContext->streams[videoStreamIndex];
    video_width = videoStream->codecpar->width;
    video_height = videoStream->codecpar->height;
    video_fps = GetAVStreamFPSTimeBase(videoStream);
    
    BOOL isSupport = [self isSupportVideoStream:videoStream formatContext:formatContext width:video_width height:video_height fps:video_fps];
    
    if (!isSupport) {
        return;
    }
    
    // Get audio stream index
    audioStreamIndex = [self getAVStreamIndexWithFormatContext:formatContext isVideoStream:NO];
    
    // Get audio stream
    
    AVStream *audioStream = formatContext->streams[audioStreamIndex];
    
    isSupport = [self isSupportAudioStream:audioStream formatContext:formatContext];
    if(!isSupport) {
        return;
    }
}

- (void)startParseWithFormatContext:(AVFormatContext *)context videoStreamIndex:(int)videoIndex audioStreamIndex:(int)audioIndex handle:(void (^)(BOOL, BOOL, struct PraseVideoDataInfo *, struct PraseAudioDataInfo *))handle {
    isStopParse = NO;
    
    dispatch_queue_t parseQueue = dispatch_queue_create("parse_queue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(parseQueue, ^{
        int fps = GetAVStreamFPSTimeBase(context->streams[videoIndex]);
        
        AVPacket packet;
        AVRational input_base;
        
        input_base.num = 1;
        input_base.den = 1000;
        
        Float64 current_timestamp = [self getCurrentTimestamp];
        
        while (!isStopParse) {
            av_init_packet(&packet);
            
            if (!context) {
                break;
            }
            
            int size = av_read_frame(context, &packet);
            if (size < 0 || packet.size < 0) {
                handle(YES,YES,NULL,NULL);
                break;
            }
            
            if (packet.stream_index == videoIndex) {
                PraseVideoDataInfo videoInfo = {0};
                
                AVDictionaryEntry *tag = NULL;
                
                tag = av_dict_get(context->streams[videoIndex]->metadata, "rotate", tag, 0);
                if (tag != NULL) {
                    int rotate = [[NSString stringWithFormat:@"%s",tag->value] intValue];
                    switch (rotate) {
                        case 90:
                            videoInfo.videoRotate = 90;
                            break;
                        case 180:
                            videoInfo.videoRotate = 180;
                            break;
                        case 270:
                            videoInfo.videoRotate = 270;
                            break;
                        default:
                            videoInfo.videoRotate = 0;
                            break;
                    }
                }
                
                if (videoInfo.videoRotate != 0 /* &&  <= iPhone 8*/) {
                    break;
                }
                
                int video_size = packet.size;
                
                uint8_t *video_data = (uint8_t*)malloc(video_size);
                memcpy(video_data, packet.data, video_size);
                
                static char filter_name[32];
                
                if(context->streams[videoIndex]->codecpar->codec_id == AV_CODEC_ID_H264) {
                    strncpy(filter_name, "h264_mp4toannexb", 32);
                    videoInfo.videoFormat = H264EncodeFormat;
                } else if(context->streams[videoIndex]->codecpar->codec_id == AV_CODEC_ID_HEVC) {
                    strncpy(filter_name, "hevc_mp4toannexb", 32);
                    videoInfo.videoFormat = H265EncodeFormat;
                } else {
                    break;
                }
                
                AVPacket new_packet = packet;
                if (self->bitFilterContext == NULL) {
                    self->bitFilterContext = av_bitstream_filter_init(filter_name);
                }
                av_bitstream_filter_filter(self->bitFilterContext, formatContext->streams[videoStreamIndex]->codec, NULL, &new_packet.data, &new_packet.size, packet.data, packet.size, 0);
                

                CMSampleTimingInfo timingInfo;
                CMTime presentationTimeStamp     = kCMTimeInvalid;
                presentationTimeStamp            = CMTimeMakeWithSeconds(current_timestamp + packet.pts * av_q2d(formatContext->streams[videoStreamIndex]->time_base), fps);
                timingInfo.presentationTimeStamp = presentationTimeStamp;
                timingInfo.decodeTimeStamp       = CMTimeMakeWithSeconds(current_timestamp + av_rescale_q(packet.dts, formatContext->streams[videoStreamIndex]->time_base, input_base), fps);
                
                videoInfo.data          = video_data;
                videoInfo.dataSize      = video_size;
                videoInfo.extraDataSize = formatContext->streams[videoStreamIndex]->codec->extradata_size;
                videoInfo.extraData     = (uint8_t *)malloc(videoInfo.extraDataSize);
                videoInfo.timingInfo    = timingInfo;
                videoInfo.pts           = packet.pts * av_q2d(formatContext->streams[videoStreamIndex]->time_base);
                videoInfo.fps           = fps;
                
                memcpy(videoInfo.extraData, formatContext->streams[videoStreamIndex]->codec->extradata, videoInfo.extraDataSize);
                av_free(new_packet.data);
                
                // send videoInfo
                if (handle) {
                    handle(YES, NO, &videoInfo, NULL);
                }
                
                free(videoInfo.extraData);
                free(videoInfo.data);
            }
            
            if (packet.stream_index == audioIndex) {
                PraseAudioDataInfo audioInfo = {0};
                audioInfo.data = (uint8_t *)malloc(packet.size);
                memcpy(audioInfo.data, packet.data, packet.size);
                audioInfo.dataSize = packet.size;
                audioInfo.channel = formatContext->streams[audioStreamIndex]->codecpar->channels;
                audioInfo.sampleRate = formatContext->streams[audioStreamIndex]->codecpar->sample_rate;
                audioInfo.pts = packet.pts * av_q2d(formatContext->streams[audioStreamIndex]->time_base);
                
                // send audio info
                if (handle) {
                    handle(NO, NO, NULL, &audioInfo);
                }
                
                free(audioInfo.data);
            }
            
            av_packet_unref(&packet);
        }
        [self freeAllResources];
        
    });
}

- (void)startParseGetAVPacketWithFormatContext:(AVFormatContext *)formatContext videoStreamIndex:(int)videoStreamIndex audioStreamIndex:(int)audioStreamIndex completionHandler:(void (^)(BOOL isVideoFrame, BOOL isFinish, AVPacket packet))handler{
    isStopParse = NO;
    dispatch_queue_t parseQueue = dispatch_queue_create("parse_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(parseQueue, ^{
        AVPacket    packet;
        while (!isStopParse) {
            if (!formatContext) {
                break;
            }
            
            av_init_packet(&packet);
            int size = av_read_frame(formatContext, &packet);
            if (size < 0 || packet.size < 0) {
                handler(YES, YES, packet);

                break;
            }
            
            if (packet.stream_index == videoStreamIndex) {
                handler(YES, NO, packet);
            }else {
                handler(NO, NO, packet);
            }
            
            av_packet_unref(&packet);
        }
        
        [self freeAllResources];
    });
}

- (AVFormatContext *)createFormatContextByFilePath:(NSString *)filePath {
    if(filePath.length == 0) {
        return NULL;
    }
    
    AVFormatContext *context = NULL;
    AVDictionary *opts = NULL;
    
    // 设置超时时间
    av_dict_set(&opts, "timeout", "1000000", 0);
    
    
    context = avformat_alloc_context();
    
    BOOL isSuccess = avformat_open_input(&context, [filePath cStringUsingEncoding:NSUTF8StringEncoding], NULL, &opts);
    
    av_dict_free(&opts);
    
    if (!isSuccess) {
        if (context) {
            avformat_free_context(context);
        }
        return NULL;
    }
    
    if (avformat_find_stream_info(context, NULL) < 0) {
        avformat_close_input(&context);
        return NULL;
    }
    
    return context;
}

- (int)getAVStreamIndexWithFormatContext:(AVFormatContext *)context isVideoStream:(BOOL)isVideoStream {
    int avSTreamIndex = -1;
    
    for (int i = 0; i<context->nb_streams; i++) {
        if ((isVideoStream ? AVMEDIA_TYPE_VIDEO : AVMEDIA_TYPE_AUDIO) == context->streams[i]->codecpar->codec_type) {
            avSTreamIndex = i;
        }
    }
    
    if (avSTreamIndex == -1) {
        return NULL;
    }
    return avSTreamIndex;
}

- (BOOL)isSupportVideoStream:(AVStream *)stream formatContext:(AVFormatContext *)context width:(int)width height:(int)height fps:(int)fps {
    
    if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
        AVCodecID codecID = stream->codecpar->codec_id;
        
        if ((codecID != AV_CODEC_ID_H264 && codecID != AV_CODEC_ID_HEVC) || ((codecID == AV_CODEC_ID_HEVC && [[UIDevice currentDevice].systemVersion floatValue] < 11.0))) {
            return NO;
        }
        
        // iPhone 8以上机型支持有旋转角度的视频
        AVDictionaryEntry *tag = NULL;
        tag = av_dict_get(formatContext->streams[videoStreamIndex]->metadata, "rotate", tag, 0);
        if(tag != NULL) {
            int rotate = [[NSString stringWithFormat:@"%s",tag->value] intValue];
            if (rotate != 0 /* && >= iPhone 8P*/) {
               
            }
        }
        
        // 目前最高支持到60FPS
        if (fps > kParseSupportMaxFps + kParseFpsOffSet) {
            return NO;
        }
        
        // 目前最高支持到3840*2160
        if (width > kParseSupportMaxWidth || height > kParseSupportMaxHeight) {

            return NO;
        }
        
        // 60FPS -> 1080P
        if (fps > kParseSupportMaxFps - kParseFpsOffSet && (width > kParseWidth1920 || height > kParseHeight1080)) {
            return NO;
        }
        
        // 30FPS -> 4K
        if (fps > kParseSupportMaxFps / 2 + kParseFpsOffSet && (width >= kParseSupportMaxWidth || height >= kParseSupportMaxHeight)) {
            return NO;
        }
        
        return YES;
        
    } else {
        return NO;
    }
}

- (BOOL)isSupportAudioStream:(AVStream *)stream formatContext:(AVFormatContext *)formatContext {
    if (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
        AVCodecID codecID = stream->codecpar->codec_id;
        // 本项目只支持AAC格式的音频
        if (codecID != AV_CODEC_ID_AAC) {
            return NO;
        }
        
        return YES;
    }else {
        return NO;
    }
}

- (void)freeAllResources {
    if (formatContext) {
        avformat_close_input(&formatContext);
        formatContext = NULL;
    }
    
    if (bitFilterContext) {
        av_bitstream_filter_close(bitFilterContext);
        bitFilterContext = NULL;
    }
}

- (Float64)getCurrentTimestamp {
    CMClockRef hostClockRef = CMClockGetHostTimeClock();
    CMTime hostTime = CMClockGetTime(hostClockRef);
    return CMTimeGetSeconds(hostTime);
}
@end
