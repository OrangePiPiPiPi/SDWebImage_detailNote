//
// Created by Fabrice Aneche on 06/01/14.
// Copyright (c) 2014 Dailymotion. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (ImageContentType)

/**
 *  Compute the content type for an image data
 *
 *  @param data the input data
 *
 *  @return the content type as string (i.e. image/jpeg, image/gif)
 根据二进制的数据获取图片的contentType
 */
+ (NSString *)sd_contentTypeForImageData:(NSData *)data;

@end


@interface NSData (ImageContentTypeDeprecated)

+ (NSString *)contentTypeForImageData:(NSData *)data __deprecated_msg("Use `sd_contentTypeForImageData:`");


//__deprecated_msg可以告诉开发者该方法不建议使用。这就有使用场景了。当我们在写框架或者类的时候，如果功能相同，但是想使用心得方法名的时候，使用__deprecated_msg给予其他开发者一个提示。这远远比我们直接删除旧的更专业。

@end
