//
// Created by Fabrice Aneche on 06/01/14.
// Copyright (c) 2014 Dailymotion. All rights reserved.
//

#import "NSData+ImageContentType.h"


@implementation NSData (ImageContentType)

/**
 
 当文件都使用二进制流作为传输时，需要制定一套规范，用来区分该文件到底是什么类型的。 文件头有很多个
 JPEG (jpg)，文件头：FFD8FFE1
 PNG (png)，文件头：89504E47
 GIF (gif)，文件头：47494638
 TIFF tif;tiff 0x49492A00
 TIFF tif;tiff 0x4D4D002A
 RAR Archive (rar)，文件头：52617221
 WebP : 524946462A73010057454250
 可以看出来我们通过每个文件头的第一个字节就能判断出是什么类型。但是值得注意的是52开头的。这个要做特别的判断。
 其中jpeg/png/gif/tiff 是最好判断的。当第一个字节为52时，如果长度<12 我们就认定为不是图片。因此返回nil。
 WebP这种格式很特别。是由12个字节组成的文件头，我们如果把这些字节通过ASCII编码后获得testString,如果testString头部包含RIFF且尾部也包含WEBP，那么就认定该图片格式为webp。
 **/
+ (NSString *)sd_contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
        case 0x52:
            // R as RIFF for WEBP
            if ([data length] < 12) {
                return nil;
            }

            NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
            if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                return @"image/webp";
            }

            return nil;
    }
    return nil;
}

@end

//被废弃的方法类后加上 ImageContentTypeDeprecated
@implementation NSData (ImageContentTypeDeprecated)

+ (NSString *)contentTypeForImageData:(NSData *)data {
    return [self sd_contentTypeForImageData:data];
}

@end
