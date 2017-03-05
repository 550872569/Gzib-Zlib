//
//  NSString+Base64.h
//  Gurpartap Singh
//
//  Created by Gurpartap Singh on 06/05/12.
//  Copyright (c) 2012 Gurpartap Singh. All rights reserved.
//

#import <Foundation/NSString.h>

@interface NSString (Base64Additions)

+ (NSString *)base64StringFromData:(NSData *)data length:(NSUInteger)length;
/**
 *  base64 解密
 *
 *  @param base64 传一个base64类型的字符串进去
 *
 *  @return 返回一个正常的字符串
 */
+ (NSString *)textFromBase64String:(NSString *)base64;

/**
 *  base64 加密
 *
 *  @param text 传入一个正常的字符串进去
 *
 *  @return 返回一个base64的字符串
 */
+ (NSString *)base64StringFromText:(NSString *)text;

@end
