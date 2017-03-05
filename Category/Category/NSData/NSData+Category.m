//
//  NSData+Category.m
//  AudioNote
//
//  Created by sogou on 16/12/13.
//  Copyright © 2016年 YY. All rights reserved.
//

#import "NSData+Category.h"

@implementation NSData (Category)

+ (NSData *)readFileContentWithFilePath:(NSString *)filePath {
    
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    if (data.length) {
        //NSLog(@"read success: %ld",data.length);
        return data;
    }
    NSLog(@"read data fail");
    return nil;
}

+ (BOOL)writeFileWithFilePath:(NSString *)filePath data:(NSData *)data {
    
    BOOL isSuccess = [data writeToFile:filePath atomically:YES];
    if (isSuccess) {
        //NSLog(@"write success");
    } else {
        NSLog(@"write fail");
    }
    return isSuccess;
}

+ (NSData *)dataWithMP3Date:(NSInteger)date {
    
    return [NSData dataWithContentsOfFile:[NSString getMp3FilePathWithCurrenttUserDate:date]];
}


+ (NSData *)dataShareImageImageWithDate:(NSInteger)date {
    
    NSString *pathImage = [NSString createShareImagePathCurrentDate:date suffix:kShareImageTypeSuffixJPEG];
    
    NSData *dataImage = [NSData dataWithContentsOfFile:pathImage];
    
    if (dataImage.length) {
        
        return dataImage;
    } else {
        return nil;
    }
}

+ (NSData *)dataShareImageThumbnailWithDate:(NSInteger)date {
    
    NSString *pathImage = [NSString createShareImageThumbnailPathCurrentDate:date suffix:kShareImageTypeSuffixJPEG];
    
    NSData *dataImage = [NSData dataWithContentsOfFile:pathImage];
    
    if (dataImage.length) {
        
        return dataImage;
    } else {
        return nil;
    }
}

+ (NSData *)dataShareImageThumbnailWithImage:(UIImage *)image targetLength:(NSInteger)targetLength {
    
    return [NSData compressImageWithImage:image targetLength:targetLength];
}

+ (NSData *)dataShareImageCompressImageWithImage:(UIImage *)image targetLength:(NSInteger)targetLength {
    
    return [NSData compressImageWithImage:image targetLength:targetLength];
}

+ (NSData *)compressImageWithImage:(UIImage *)image targetLength:(NSInteger)targetLength {
    
    NSData *data = UIImageJPEGRepresentation(image,1);
    if (data.length > targetLength) {
        data = UIImageJPEGRepresentation(image,0.9);
        if (data.length > targetLength) {
            data = UIImageJPEGRepresentation(image,0.8);
            if (data.length > targetLength) {
                data = UIImageJPEGRepresentation(image,0.7);
                if (data.length > targetLength) {
                    data = UIImageJPEGRepresentation(image,0.6);
                    if (data.length > targetLength) {
                        data = UIImageJPEGRepresentation(image,0.5);
                        if (data.length > targetLength) {
                            data = UIImageJPEGRepresentation(image,0.4);
                            if (data.length > targetLength) {
                                data = UIImageJPEGRepresentation(image,0.3);
                                if (data.length > targetLength) {
                                    data = UIImageJPEGRepresentation(image,0.2);
                                    if (data.length > targetLength) {
                                        data = UIImageJPEGRepresentation(image,0.1);                                       
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return data;
}

- (NSString *)AES256DecryptWithkeyData:(NSData *)key iv:(NSData *)iv {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
        return nil;
    }
    if (iv.length != 16 && iv.length != 0) {
        return nil;
    }
    
    NSString *result = nil;
    size_t bufferSize = self.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    if (!buffer) return nil;
    size_t encryptedSize = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                          kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding | kCCOptionECBMode,
                                          key.bytes,
                                          key.length,
                                          iv.bytes,
                                          self.bytes,
                                          self.length,
                                          buffer,
                                          bufferSize,
                                          &encryptedSize);
    if (cryptStatus == kCCSuccess) {
        //result = [[NSString alloc]initWithBytes:buffer length:encryptedSize];
        result = [[NSString alloc]initWithBytes:buffer length:encryptedSize encoding:NSUTF8StringEncoding];
        free(buffer);
        return result;
    } else {
        free(buffer);
        return nil;
    }
}

@end
