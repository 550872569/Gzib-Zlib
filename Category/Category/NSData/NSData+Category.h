//
//  NSData+Category.h
//  AudioNote
//
//  Created by sogou on 16/12/13.
//  Copyright © 2016年 YY. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Category)

/** 读取文件路径中的Data数据 */
+ (NSData *)readFileContentWithFilePath:(NSString *)filePath;

/** 写入数据到对应文件路径中 */
+ (BOOL)writeFileWithFilePath:(NSString *)filePath data:(NSData *)data;

/** 根据录音日期获取语音数据data */
+ (NSData *)dataWithMP3Date:(NSInteger)date;


/**
 获取分享的缩略图

 @param date 分享图片的名字（时间）
 @return 缩略图
 */
+ (NSData *)dataShareImageThumbnailWithDate:(NSInteger)date;

/**
 获取分享的图片
 
 @param date 分享图片的名字（时间）
 @return 图片
 */
+ (NSData *)dataShareImageImageWithDate:(NSInteger)date;


/**
 压缩图片获取缩略图

 @param image 分享图片
 @param image 图片最大尺寸
 @return 缩略图
 */
+ (NSData *)dataShareImageThumbnailWithImage:(UIImage *)image targetLength:(NSInteger)targetLength;

/**
 压缩图片获取规定大小的图片
 
 @param image 分享图片
 @param image 图片最大尺寸
 @return 规定大小的图片
 */
+ (NSData *)dataShareImageCompressImageWithImage:(UIImage *)image targetLength:(NSInteger)targetLength;


- (NSString *)AES256DecryptWithkeyData:(NSData *)key iv:(NSData *)iv;

@end
