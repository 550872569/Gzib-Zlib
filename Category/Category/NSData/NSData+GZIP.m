//
//  GZIP.m
//
//  Version 1.1.1
//
//  Created by Nick Lockwood on 03/06/2012.
//  Copyright (C) 2012 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/GZIP
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//


#import "NSData+GZIP.h"
#import <zlib.h>
#import <dlfcn.h>

#define kAESEncryptionBlockSize     kCCBlockSizeAES128
#define kAESEncryptionKeySize       kCCKeySizeAES256
#pragma clang diagnostic ignored "-Wcast-qual"


@implementation NSData (GZIP)

static void *libzOpen() {
    static void *libz;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        libz = dlopen("/usr/lib/libz.dylib", RTLD_LAZY);
    });
    return libz;
}

- (NSData *)gzippedDataWithCompressionLevel:(float)level {
    if (self.length == 0 || [self isGzippedData])
    {
        return self;
    }

    void *libz = libzOpen();
    int (*deflateInit2_)(z_streamp, int, int, int, int, int, const char *, int) =
    (int (*)(z_streamp, int, int, int, int, int, const char *, int))dlsym(libz, "deflateInit2_");
    int (*deflate)(z_streamp, int) = (int (*)(z_streamp, int))dlsym(libz, "deflate");
    int (*deflateEnd)(z_streamp) = (int (*)(z_streamp))dlsym(libz, "deflateEnd");

    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.opaque = Z_NULL;
    stream.avail_in = (uint)self.length;
    stream.next_in = (Bytef *)(void *)self.bytes;
    stream.total_out = 0;
    stream.avail_out = 0;

    static const NSUInteger ChunkSize = 16384;

    NSMutableData *output = nil;
    int compression = (level < 0.0f)? Z_DEFAULT_COMPRESSION: (int)(roundf(level * 9));
    if (deflateInit2(&stream, compression, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY) == Z_OK)
    {
        output = [NSMutableData dataWithLength:ChunkSize];
        while (stream.avail_out == 0)
        {
            if (stream.total_out >= output.length)
            {
                output.length += ChunkSize;
            }
            stream.next_out = (uint8_t *)output.mutableBytes + stream.total_out;
            stream.avail_out = (uInt)(output.length - stream.total_out);
            deflate(&stream, Z_FINISH);
        }
        deflateEnd(&stream);
        output.length = stream.total_out;
    }

    return output;
}
- (NSData *)gzippedData {
    return [self gzippedDataWithCompressionLevel:-1.0f];
}
- (NSData *)gunzippedData {
    if (self.length == 0 || ![self isGzippedData])
    {
        return self;
    }

    void *libz = libzOpen();
    int (*inflateInit2_)(z_streamp, int, const char *, int) =
    (int (*)(z_streamp, int, const char *, int))dlsym(libz, "inflateInit2_");
    int (*inflate)(z_streamp, int) = (int (*)(z_streamp, int))dlsym(libz, "inflate");
    int (*inflateEnd)(z_streamp) = (int (*)(z_streamp))dlsym(libz, "inflateEnd");

    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.avail_in = (uint)self.length;
    stream.next_in = (Bytef *)self.bytes;
    stream.total_out = 0;
    stream.avail_out = 0;

    NSMutableData *output = nil;
    if (inflateInit2(&stream, 47) == Z_OK)
    {
        int status = Z_OK;
        output = [NSMutableData dataWithCapacity:self.length * 2];
        while (status == Z_OK)
        {
            if (stream.total_out >= output.length)
            {
                output.length += self.length / 2;
            }
            stream.next_out = (uint8_t *)output.mutableBytes + stream.total_out;
            stream.avail_out = (uInt)(output.length - stream.total_out);
            status = inflate (&stream, Z_SYNC_FLUSH);
        }
        if (inflateEnd(&stream) == Z_OK)
        {
            if (status == Z_STREAM_END)
            {
                output.length = stream.total_out;
            }
        }
    }

    return output;
}
- (BOOL)isGzippedData {
    const UInt8 *bytes = (const UInt8 *)self.bytes;
    return (self.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b);
}


#pragma mark - 压缩解压缩
+ (NSData *)compressData:(NSData *)uncompressedData {
    
    if ([uncompressedData length] == 0) return uncompressedData;
    
    z_stream strm;
    
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.total_out = 0;
    strm.next_in=(Bytef *)[uncompressedData bytes];
    strm.avail_in = (unsigned int)[uncompressedData length];
    
    if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) return nil;
    
    NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chunks for expansion
    
    do {
        
        if (strm.total_out >= [compressed length])
            [compressed increaseLengthBy: 16384];
        
        strm.next_out = [compressed mutableBytes] + strm.total_out;
        strm.avail_out = (unsigned int)([compressed length] - strm.total_out);
        
        deflate(&strm, Z_FINISH);
        
    } while (strm.avail_out == 0);
    
    deflateEnd(&strm);
    
    [compressed setLength: strm.total_out];
    return [NSData dataWithData:compressed];
}
+ (NSData *)uncompressZippedData:(NSData *)compressedData {
    
    if ([compressedData length] == 0) return compressedData;
    
    unsigned full_length = (int)[compressedData length];
    
    unsigned half_length = (int)[compressedData length] / 2;
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    z_stream strm;
    strm.next_in = (Bytef *)[compressedData bytes];
    strm.avail_in = (int)[compressedData length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
    while (!done) {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy: half_length];
        }
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (int)([decompressed length] - strm.total_out);
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) {
            done = YES;
        } else if (status != Z_OK) {
            break;
        }
        
    }
    if (inflateEnd (&strm) != Z_OK) return nil;
    // Set real length.
    if (done) {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    } else {
        return nil;
    }    
}

#pragma mark - zlib
+ (NSData *)zlibCompressData:(NSData *)sourceData {
    
    NSUInteger sourceDataLength = [sourceData length];
    
    if (sourceDataLength == 0) {
        return sourceData;
    }
    
    z_stream stream;
    memset(&stream, 0, sizeof(z_stream));
    
    stream.next_in = (Bytef *)[sourceData bytes];
    stream.avail_in = (uInt)sourceDataLength;
    stream.total_out = 0;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    
    if (deflateInit(&stream, Z_DEFAULT_COMPRESSION) != Z_OK) {
        return nil;
    }
    
    const int KBufLen = 1024;
    Byte buf[KBufLen];
    memset(buf, 0, KBufLen * sizeof(Byte));
    
    BOOL isCompressOK = NO;
    
    NSMutableData *compressedData =
    [NSMutableData dataWithLength:sourceDataLength];
    [compressedData setData:nil]; //必须得加
    
    int res = 0;
    
    while (stream.avail_out == 0) {
        
        memset(buf, 0, KBufLen * sizeof(Byte));
        stream.avail_out = KBufLen;
        stream.next_out = buf;
        
        res = deflate(&stream, Z_FINISH);
        ;
        
        switch (res) {
            case Z_NEED_DICT:
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
            case Z_STREAM_ERROR:
            case Z_BUF_ERROR: {
                isCompressOK = NO;
                break;
            }
                
            default: {
                if (res == Z_OK || res == Z_STREAM_END) {
                    const int dataLen = KBufLen - stream.avail_out;
                    isCompressOK = YES;
                    
                    if (dataLen > 0) {
                        [compressedData appendBytes:buf length:dataLen];
                    }
                }
                
                break;
            }
        }
        
        if (!isCompressOK) {
            break;
        }
    }
    
    res = deflateEnd(&stream);
    if (res != Z_OK) {
        return nil;
    }
    
    if (isCompressOK) {
        return compressedData;
    } else {
        return nil;
    }
}
+ (NSData *)zlibUncompressData:(NSData *)sourceData {
    
    NSUInteger sourceDataLength = [sourceData length];
    
    if (sourceDataLength == 0) {
        return sourceData;
    }
    
    z_stream stream;
    memset(&stream, 0, sizeof(z_stream));
    
    stream.next_in = (Bytef *)[sourceData bytes];
    stream.avail_in = (uInt)sourceDataLength;
    stream.total_out = 0;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    
    int res = inflateInit(&stream);
    // inflateInit2(&strm, (15+32))
    
    if (res != Z_OK) {
        return nil;
    }
    
    const int KBufLen = 1024;
    Byte buf[KBufLen];
    memset(buf, 0, KBufLen * sizeof(Byte));
    
    BOOL isUncompressOK = NO;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength:sourceDataLength];
    [decompressed setData:nil]; //必须得加
    
    while (stream.avail_out == 0) {
        
        memset(buf, 0, KBufLen * sizeof(Byte));
        stream.avail_out = KBufLen;
        stream.next_out = buf;
        
        res = inflate(&stream, Z_NO_FLUSH);
        
        switch (res) {
            case Z_NEED_DICT:
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
            case Z_STREAM_ERROR:
            case Z_BUF_ERROR: {
                isUncompressOK = NO;
                break;
            }
                
            default: {
                if (res == Z_OK || res == Z_STREAM_END) {
                    const int dataLen = KBufLen - stream.avail_out;
                    isUncompressOK = YES;
                    
                    if (dataLen > 0) {
                        [decompressed appendBytes:buf length:dataLen];
                    }
                }
                
                break;
            }
        }
        
        if (!isUncompressOK) {
            break;
        }
    }
    
    if (inflateEnd(&stream) != Z_OK) {
        return nil;
    }
    
    if (isUncompressOK) {
        return decompressed;
    } else {
        return nil;
    }
}

#pragma mark - gzip
+ (NSData *)gzipCompress:(NSData *)sourceData {
    
    NSUInteger sourceDataLength = [sourceData length];
    
    if (sourceDataLength == 0) {
        return sourceData;
    }
    
    z_stream stream;
    memset(&stream, 0, sizeof(z_stream));
    
    stream.next_in = (Bytef *)[sourceData bytes];
    stream.avail_in = (uInt)sourceDataLength;
    stream.total_out = 0;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    
    //只有设置为MAX_WBITS + 16才能在在压缩文本中带header和trailer
    if (deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, MAX_WBITS + 16,
                     8, Z_DEFAULT_STRATEGY) != Z_OK) {
        return nil;
    }
    
    const int KBufLen = 1024;
    Byte buf[KBufLen];
    memset(buf, 0, KBufLen * sizeof(Byte));
    
    BOOL isCompressOK = NO;
    
    NSMutableData *compressedData =
    [NSMutableData dataWithLength:sourceDataLength];
    [compressedData setData:nil]; //必须得加
    
    int res = 0;
    
    while (stream.avail_out == 0) {
        
        memset(buf, 0, KBufLen * sizeof(Byte));
        stream.avail_out = KBufLen;
        stream.next_out = buf;
        
        res = deflate(&stream, Z_FINISH);
        ;
        
        switch (res) {
            case Z_NEED_DICT:
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
            case Z_STREAM_ERROR:
            case Z_BUF_ERROR: {
                isCompressOK = NO;
                break;
            }
                
            default: {
                if (res == Z_OK || res == Z_STREAM_END) {
                    const int dataLen = KBufLen - stream.avail_out;
                    isCompressOK = YES;
                    
                    if (dataLen > 0) {
                        [compressedData appendBytes:buf length:dataLen];
                    }
                }
                
                break;
            }
        }
        
        if (!isCompressOK) {
            break;
        }
    }
    
    res = deflateEnd(&stream);
    if (res != Z_OK) {
        return nil;
    }
    
    if (isCompressOK) {
        return compressedData;
    } else {
        return nil;
    }
}
+ (NSData *)gzipUncompress:(NSData *)sourceData {
    
    NSUInteger sourceDataLength = [sourceData length];
    
    if (sourceDataLength == 0) {
        return sourceData;
    }
    
    z_stream stream;
    memset(&stream, 0, sizeof(z_stream));
    
    stream.next_in = (Bytef *)[sourceData bytes];
    stream.avail_in = (uInt)sourceDataLength;
    stream.total_out = 0;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    
    int res = inflateInit2(&stream, MAX_WBITS + 16);
    // inflateInit2(&strm, (15+32))
    //只有设置为MAX_WBITS + 16才能在解压带header和trailer的文本
    
    if (res != Z_OK) {
        return nil;
    }
    
    const int KBufLen = 1024;
    Byte buf[KBufLen];
    memset(buf, 0, KBufLen * sizeof(Byte));
    
    BOOL isUncompressOK = NO;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength:sourceDataLength];
    [decompressed setData:nil]; //必须得加
    
    while (stream.avail_out == 0) {
        
        memset(buf, 0, KBufLen * sizeof(Byte));
        stream.avail_out = KBufLen;
        stream.next_out = buf;
        
        res = inflate(&stream, Z_SYNC_FLUSH);
        
        switch (res) {
            case Z_NEED_DICT:
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
            case Z_STREAM_ERROR:
            case Z_BUF_ERROR: {
                isUncompressOK = NO;
                break;
            }
                
            default: {
                if (res == Z_OK || res == Z_STREAM_END) {
                    const int dataLen = KBufLen - stream.avail_out;
                    isUncompressOK = YES;
                    
                    if (dataLen > 0) {
                        [decompressed appendBytes:buf length:dataLen];
                    }
                }
                
                break;
            }
        }
        
        if (!isUncompressOK) {
            break;
        }
    }
    
    if (inflateEnd(&stream) != Z_OK) {
        return nil;
    }
    
    if (isUncompressOK) {
        return decompressed;
    } else {
        return nil;
    }
}


#pragma mark - 
+ (NSData*)gzipData: (NSData*)pUncompressedData
{
    /*
     Special thanks to Robbie Hanson of Deusty Designs for sharing sample code
     showing how deflateInit2() can be used to make zlib generate a compressed
     file with gzip headers:
     http://deusty.blogspot.com/2007/07/gzip-compressiondecompression.html
     */
    
    if (!pUncompressedData || [pUncompressedData length] == 0)
    {
        NSLog(@"%s: Error: Can't compress an empty or null NSData object.", __func__);
        return nil;
    }
    
    /* Before we can begin compressing (aka "deflating") data using the zlib
     functions, we must initialize zlib. Normally this is done by calling the
     deflateInit() function; in this case, however, we'll use deflateInit2() so
     that the compressed data will have gzip headers. This will make it easy to
     decompress the data later using a tool like gunzip, WinZip, etc.
     deflateInit2() accepts many parameters, the first of which is a C struct of
     type "z_stream" defined in zlib.h. The properties of this struct are used to
     control how the compression algorithms work. z_stream is also used to
     maintain pointers to the "input" and "output" byte buffers (next_in/out) as
     well as information about how many bytes have been processed, how many are
     left to process, etc. */
    z_stream zlibStreamStruct;
    zlibStreamStruct.zalloc     = Z_NULL; // Set zalloc, zfree, and opaque to Z_NULL so
    zlibStreamStruct.zfree      = Z_NULL; // that when we call deflateInit2 they will be
    zlibStreamStruct.opaque     = Z_NULL; // updated to use default allocation functions.
    zlibStreamStruct.total_out = 0; // Total number of output bytes produced so far
    zlibStreamStruct.next_in    = (Bytef*)[pUncompressedData bytes]; // Pointer to input bytes
    zlibStreamStruct.avail_in   = [pUncompressedData length]; // Number of input bytes left to process
    
    /* Initialize the zlib deflation (i.e. compression) internals with deflateInit2().
     The parameters are as follows:
     z_streamp strm - Pointer to a zstream struct
     int level       - Compression level. Must be Z_DEFAULT_COMPRESSION, or between
     0 and 9: 1 gives best speed, 9 gives best compression, 0 gives
     no compression.
     int method      - Compression method. Only method supported is "Z_DEFLATED".
     int windowBits - Base two logarithm of the maximum window size (the size of
     the history buffer). It should be in the range 8..15. Add
     16 to windowBits to write a simple gzip header and trailer
     around the compressed data instead of a zlib wrapper. The
     gzip header will have no file name, no extra data, no comment,
     no modification time (set to zero), no header crc, and the
     operating system will be set to 255 (unknown).
     int memLevel    - Amount of memory allocated for internal compression state.
     1 uses minimum memory but is slow and reduces compression
     ratio; 9 uses maximum memory for optimal speed. Default value
     is 8.
     int strategy    - Used to tune the compression algorithm. Use the value
     Z_DEFAULT_STRATEGY for normal data, Z_FILTERED for data
     produced by a filter (or predictor), or Z_HUFFMAN_ONLY to
     force Huffman encoding only (no string match) */
    
    //    int initError = deflateInit2(&zlibStreamStruct, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY);
    int initError = deflateInit2(&zlibStreamStruct, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY);
    if (initError != Z_OK)
    {
        NSString *errorMsg = nil;
        switch (initError)
        {
            case Z_STREAM_ERROR:
                errorMsg = @"Invalid parameter passed in to function.";
                break;
            case Z_MEM_ERROR:
                errorMsg = @"Insufficient memory.";
                break;
            case Z_VERSION_ERROR:
                errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
                break;
            default:
                errorMsg = @"Unknown error code.";
                break;
        }
        return nil;
    }
    
    // Create output memory buffer for compressed data. The zlib documentation states that
    // destination buffer size must be at least 0.1% larger than avail_in plus 12 bytes.
    NSMutableData *compressedData = [NSMutableData dataWithLength:[pUncompressedData length] * 1.01 + 12];
    
    int deflateStatus;
    do
    {
        // Store location where next byte should be put in next_out
        zlibStreamStruct.next_out = [compressedData mutableBytes] + zlibStreamStruct.total_out;
        
        // Calculate the amount of remaining free space in the output buffer
        // by subtracting the number of bytes that have been written so far
        // from the buffer's total capacity
        zlibStreamStruct.avail_out = [compressedData length] - zlibStreamStruct.total_out;
        
        /* deflate() compresses as much data as possible, and stops/returns when
         the input buffer becomes empty or the output buffer becomes full. If
         deflate() returns Z_OK, it means that there are more bytes left to
         compress in the input buffer but the output buffer is full; the output
         buffer should be expanded and deflate should be called again (i.e., the
         loop should continue to rune). If deflate() returns Z_STREAM_END, the
         end of the input stream was reached (i.e.g, all of the data has been
         compressed) and the loop should stop. */
        deflateStatus = deflate(&zlibStreamStruct, Z_FINISH);
        
    } while ( deflateStatus == Z_OK );
    
    // Check for zlib error and convert code to usable error message if appropriate
    if (deflateStatus != Z_STREAM_END)
    {
        NSString *errorMsg = nil;
        switch (deflateStatus)
        {
            case Z_ERRNO:
                errorMsg = @"Error occured while reading file.";
                break;
            case Z_STREAM_ERROR:
                errorMsg = @"The stream state was inconsistent (e.g., next_in or next_out was NULL).";
                break;
            case Z_DATA_ERROR:
                errorMsg = @"The deflate data was invalid or incomplete.";
                break;
            case Z_MEM_ERROR:
                errorMsg = @"Memory could not be allocated for processing.";
                break;
            case Z_BUF_ERROR:
                errorMsg = @"Ran out of output buffer for writing compressed bytes.";
                break;
            case Z_VERSION_ERROR:
                errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
                break;
            default:
                errorMsg = @"Unknown error code.";
                break;
        }
        
        // Free data structures that were dynamically created for the stream.
        deflateEnd(&zlibStreamStruct);
        
        return nil;
    }
    // Free data structures that were dynamically created for the stream.
    deflateEnd(&zlibStreamStruct);
    [compressedData setLength: zlibStreamStruct.total_out];
    
    return compressedData;
}

+ (NSData*)ungzipData:(NSData *)pCompressedData
{
    return [self ungzipData:pCompressedData deflated:true];
}

+ (NSData*)ungzipData: (NSData*)pCompressedData deflated:(BOOL)deflated
{
    /*
     Special thanks to Robbie Hanson of Deusty Designs for sharing sample code
     showing how deflateInit2() can be used to make zlib generate a compressed
     file with gzip headers:
     http://deusty.blogspot.com/2007/07/gzip-compressiondecompression.html
     */
    
    if (!pCompressedData || [pCompressedData length] == 0)
    {
        NSLog(@"%s: Error: Can't uncompress an empty or null NSData object.", __func__);
        return nil;
    }
    
    /* Before we can begin compressing (aka "deflating") data using the zlib
     functions, we must initialize zlib. Normally this is done by calling the
     deflateInit() function; in this case, however, we'll use deflateInit2() so
     that the compressed data will have gzip headers. This will make it easy to
     decompress the data later using a tool like gunzip, WinZip, etc.
     deflateInit2() accepts many parameters, the first of which is a C struct of
     type "z_stream" defined in zlib.h. The properties of this struct are used to
     control how the compression algorithms work. z_stream is also used to
     maintain pointers to the "input" and "output" byte buffers (next_in/out) as
     well as information about how many bytes have been processed, how many are
     left to process, etc. */
    z_stream zlibStreamStruct;
    zlibStreamStruct.zalloc     = Z_NULL; // Set zalloc, zfree, and opaque to Z_NULL so
    zlibStreamStruct.zfree      = Z_NULL; // that when we call deflateInit2 they will be
    zlibStreamStruct.opaque     = Z_NULL; // updated to use default allocation functions.
    zlibStreamStruct.total_out = 0; // Total number of output bytes produced so far
    zlibStreamStruct.next_in    = (Bytef*)[pCompressedData bytes]; // Pointer to input bytes
    zlibStreamStruct.avail_in   = [pCompressedData length]; // Number of input bytes left to process
    
    /* Initialize the zlib deflation (i.e. compression) internals with deflateInit2().
     The parameters are as follows:
     z_streamp strm - Pointer to a zstream struct
     int level       - Compression level. Must be Z_DEFAULT_COMPRESSION, or between
     0 and 9: 1 gives best speed, 9 gives best compression, 0 gives
     no compression.
     int method      - Compression method. Only method supported is "Z_DEFLATED".
     int windowBits - Base two logarithm of the maximum window size (the size of
     the history buffer). It should be in the range 8..15. Add
     16 to windowBits to write a simple gzip header and trailer
     around the compressed data instead of a zlib wrapper. The
     gzip header will have no file name, no extra data, no comment,
     no modification time (set to zero), no header crc, and the
     operating system will be set to 255 (unknown).
     int memLevel    - Amount of memory allocated for internal compression state.
     1 uses minimum memory but is slow and reduces compression
     ratio; 9 uses maximum memory for optimal speed. Default value
     is 8.
     int strategy    - Used to tune the compression algorithm. Use the value
     Z_DEFAULT_STRATEGY for normal data, Z_FILTERED for data
     produced by a filter (or predictor), or Z_HUFFMAN_ONLY to
     force Huffman encoding only (no string match) */
    NSInteger maxWBits = MAX_WBITS;
    if (deflated) {
        maxWBits = -maxWBits;
    } else {
        maxWBits += 32;
    }
    int initError = inflateInit2(&zlibStreamStruct, maxWBits);
    if (initError != Z_OK)
    {
        NSString *errorMsg = nil;
        switch (initError)
        {
            case Z_STREAM_ERROR:
                errorMsg = @"Invalid parameter passed in to function.";
                break;
            case Z_MEM_ERROR:
                errorMsg = @"Insufficient memory.";
                break;
            case Z_VERSION_ERROR:
                errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
                break;
            default:
                errorMsg = @"Unknown error code.";
                break;
        }
        return nil;
    }
    
    // Create output memory buffer for compressed data. The zlib documentation states that
    // destination buffer size must be at least 0.1% larger than avail_in plus 12 bytes.
    
    NSInteger full_length = pCompressedData.length;
    NSInteger half_length = full_length / 2;
    NSMutableData *unCompressedData = [NSMutableData dataWithLength:(full_length + half_length)];
    
    int inflateStatus;
    do
    {
        // Make sure we have enough room and reset the lengths.
        if (zlibStreamStruct.total_out >= unCompressedData.length) {
            [unCompressedData increaseLengthBy: half_length];
        }
        
        // Store location where next byte should be put in next_out
        zlibStreamStruct.next_out = [unCompressedData mutableBytes] + zlibStreamStruct.total_out;
        
        // Calculate the amount of remaining free space in the output buffer
        // by subtracting the number of bytes that have been written so far
        // from the buffer's total capacity
        zlibStreamStruct.avail_out = [unCompressedData length] - zlibStreamStruct.total_out;
        
        /* deflate() compresses as much data as possible, and stops/returns when
         the input buffer becomes empty or the output buffer becomes full. If
         deflate() returns Z_OK, it means that there are more bytes left to
         compress in the input buffer but the output buffer is full; the output
         buffer should be expanded and deflate should be called again (i.e., the
         loop should continue to rune). If deflate() returns Z_STREAM_END, the
         end of the input stream was reached (i.e.g, all of the data has been
         compressed) and the loop should stop. */
        inflateStatus = inflate(&zlibStreamStruct, Z_NO_FLUSH);
        
    } while ( inflateStatus == Z_OK );
    
    // Check for zlib error and convert code to usable error message if appropriate
    if (inflateStatus != Z_STREAM_END)
    {
        NSString *errorMsg = nil;
        switch (inflateStatus)
        {
            case Z_ERRNO:
                errorMsg = @"Error occured while reading file.";
                break;
            case Z_STREAM_ERROR:
                errorMsg = @"The stream state was inconsistent (e.g., next_in or next_out was NULL).";
                break;
            case Z_DATA_ERROR:
                errorMsg = @"The deflate data was invalid or incomplete.";
                break;
            case Z_MEM_ERROR:
                errorMsg = @"Memory could not be allocated for processing.";
                break;
            case Z_BUF_ERROR:
                errorMsg = @"Ran out of output buffer for writing compressed bytes.";
                break;
            case Z_VERSION_ERROR:
                errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
                break;
            default:
                errorMsg = @"Unknown error code.";
                break;
        }
        
        // Free data structures that were dynamically created for the stream.
        inflateEnd(&zlibStreamStruct);
        
        return nil;
    }
    // Free data structures that were dynamically created for the stream.
    inflateEnd(&zlibStreamStruct);
    [unCompressedData setLength: zlibStreamStruct.total_out];
    
    return unCompressedData;
}

// AES Encrypt
- (NSData *)AES256EncryptWithKey:(NSData *)key encryptData:(NSData *)encryptStr encryptIV:(NSData *)iv
{
    NSUInteger dataLength = encryptStr.length;
    
    void *data = malloc(dataLength);
    memset(data, 0, dataLength);
    memcpy(data, [encryptStr bytes], encryptStr.length);
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize           = dataLength + kAESEncryptionBlockSize;
    void* buffer                = malloc(bufferSize);
    
    size_t numBytesEncrypted    = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          [key bytes], kAESEncryptionKeySize,
                                          [iv bytes] /* initialization vector (optional) */,
                                          data, dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted);
    
    if (cryptStatus == kCCSuccess)
    {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        NSData *dataEncrypt = [NSMutableData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
        free(data); // free the data;
        //        free(buffer); //free the buffer;
        
        return dataEncrypt;
    }
    
    free(data); // free the data;
    free(buffer); //free the buffer;
    return nil;
}

// AES Decrypt
- (NSData *)AES256DecryptWithKey:(NSData*)key decryptData:(NSData *)decryptData decryptIV:(NSData *)iv
{
    NSUInteger dataLength = decryptData.length;
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize           = dataLength + kAESEncryptionBlockSize;
    void* buffer                = malloc(bufferSize);
    
    size_t numBytesDecrypted    = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          [key bytes], kAESEncryptionKeySize,
                                          [iv bytes] /* initialization vector (optional) */,
                                          [decryptData bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess)
    {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        NSData *dataDecrypt = [NSMutableData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
        //        free(buffer); //free the buffer;
        
        return dataDecrypt;
    }
    
    free(buffer); //free the buffer;
    return nil;
}

- (NSData*)AES256EncryptWithKey:(NSString*)key {
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256 + 1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize           = dataLength + kCCBlockSizeAES128;
    void* buffer                = malloc(bufferSize);
    
    size_t numBytesEncrypted    = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted);
    
    if (cryptStatus == kCCSuccess)
    {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer); //free the buffer;
    return nil;
}

@end
