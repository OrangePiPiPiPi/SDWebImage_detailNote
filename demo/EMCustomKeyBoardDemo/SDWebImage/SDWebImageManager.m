/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageManager.h"
#import <objc/message.h>

@interface SDWebImageCombinedOperation : NSObject <SDWebImageOperation>

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (copy, nonatomic) SDWebImageNoParamsBlock cancelBlock;//取消下载operation的block
@property (strong, nonatomic) NSOperation *cacheOperation;//cacheOperation用来下载图片并且缓存的operation

@end

@interface SDWebImageManager ()

@property (strong, nonatomic, readwrite) SDImageCache *imageCache;
@property (strong, nonatomic, readwrite) SDWebImageDownloader *imageDownloader;
@property (strong, nonatomic) NSMutableSet *failedURLs;
@property (strong, nonatomic) NSMutableArray *runningOperations;

@end

@implementation SDWebImageManager

+ (id)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (id)init {
    if ((self = [super init])) {
        _imageCache = [self createCache];
        _imageDownloader = [SDWebImageDownloader sharedDownloader];
        _failedURLs = [NSMutableSet new];
        _runningOperations = [NSMutableArray new];
    }
    return self;
}

- (SDImageCache *)createCache {
    return [SDImageCache sharedImageCache];
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (self.cacheKeyFilter) {
        return self.cacheKeyFilter(url);
    }
    else {
        //[url absoluteString]完整的url字符串
        /**
         NSURL *url = [NSURL URLWithString:@“ http://www.baidu.com/search?id=1 ”];
         分别打印以下属性可以很好的理解它们的区别(NSLog后面的注释就是 %@ 的打印结果)：
         NSLog(@"scheme:%@", [url scheme]); //协议 http
         
         NSLog(@"host:%@", [url host]);    //域名 www.baidu.com
         
         NSLog(@"absoluteString:%@", [url absoluteString]); //完整的url字符串 http://www.baidu.com:8080/search?id=1
         
         NSLog(@"relativePath: %@", [url relativePath]); //相对路径 search
         
         NSLog(@"port :%@", [url port]);  // 端口 8080
         
         NSLog(@"path: %@", [url path]);  // 路径 search
         
         NSLog(@"pathComponents:%@", [url pathComponents]); // search
         
         NSLog(@"Query:%@", [url query]);  //参数 id=1
         **/
        return [url absoluteString];
    }
}

- (BOOL)cachedImageExistsForURL:(NSURL *)url {
    //生成key
    NSString *key = [self cacheKeyForURL:url];
    //先去内存中找是否有缓存
    if ([self.imageCache imageFromMemoryCacheForKey:key] != nil) return YES;
    //再去磁盘中找是否有缓存
    return [self.imageCache diskImageExistsWithKey:key];
}

- (BOOL)diskImageExistsForURL:(NSURL *)url {
     //去磁盘中找是否有缓存
    NSString *key = [self cacheKeyForURL:url];
    return [self.imageCache diskImageExistsWithKey:key];
}

- (void)cachedImageExistsForURL:(NSURL *)url
                     completion:(SDWebImageCheckCacheCompletionBlock)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    
    BOOL isInMemoryCache = ([self.imageCache imageFromMemoryCacheForKey:key] != nil);
    
    if (isInMemoryCache) {
        // making sure we call the completion block on the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(YES);
            }
        });
        return;
    }
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        // the completion block of checkDiskCacheForImageWithKey:completion: is always called on the main queue, no need to further dispatch
        //因为completion这个block已经在主线程回调了，故执行下面的block就是在主线程
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

- (void)diskImageExistsForURL:(NSURL *)url
                   completion:(SDWebImageCheckCacheCompletionBlock)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        // the completion block of checkDiskCacheForImageWithKey:completion: is always called on the main queue, no need to further dispatch
        // //因为completion这个block已经在主线程回调了，故执行下面的block就是在主线程
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageOptions)options
                                        progress:(SDWebImageDownloaderProgressBlock)progressBlock
                                       completed:(SDWebImageCompletionWithFinishedBlock)completedBlock {
    // 断言
    /**
     NSAssert）是一个宏，在开发过程中使用NSAssert可以及时发现程序中的问题
     使用方法:
     NSAssert(x != nil, @"错误提示");当你的程序在运行到这个宏时, 如果变量x的值为nil, 此时程序就会崩溃, 并且抛出一个异常, 异常提示就是你后面写的提示
     
     发布版本:
     NSAssert也是一个预处理指令, 如果使用过多, 也会影响你的程序运行, 这时我们要像在发布版本时处理NSLog一样处理这个预处理指令, 只不过他的处理方式有些不同
     1.首先进入项目工程文件
     2.选择Build Settings
     3.搜索Perprocessor Macros
     4.在Release中添加一个规则: NS_BLOCK_ASSERTIONS
     5.这时当你的APP处于发布版本时, 这个预处理指令就会失效了
     **/
    NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[SDWebImagePrefetcher prefetchURLs] instead");

    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, XCode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }

    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }

    /*
     首先我们先来看看__block和__weak的区别
     __block用于指明当前声明的变量在被block捕获之后,可以在block中改变变量的值.因为在block声明的同时会截获该block所使用的全部自动变量的值,这些值只在block中只有"使用权"而不具有"修改权".而__block说明符就为block提供了变量的修改权,__block不能避免循环引用，这就需要我们在 block 内部将要退出的时候手动释放掉 blockObj,blockObj = nil
     
     __weak是所有权修饰符,__weak本身是可以避免循环引用的问题的,但是其会导致外部对象释放之后,block内部也访问不到对象的问题,我们可以通过在block内部声明一个__strong的变量来指向weakObj,使外部既能在block内部保持住又能避免循环引用
     */
    //SDWebImageCombinedOperation是一个类，该类遵守SDWebImageOperation协议
    __block SDWebImageCombinedOperation *operation = [SDWebImageCombinedOperation new];
    __weak SDWebImageCombinedOperation *weakOperation = operation;

    /**
     @synchronized是OC中一种方便地创建互斥锁的方式--它可以防止不同线程在同一时间执行区块的代码
     self.failedURLs是一个NSSet类型的集合,里面存放的都是下载失败的图片的url,failedURLs不是NSArray类型的原因是:
      在搜索一个个元素的时候NSSet比NSArray效率高,主要是它用到了一个算法hash(散列,哈希) ,比如你要存储A,一个hash算法直接就能找到A应该存储的位置;同样当你要访问A的时候,一个hash过程就能找到A存储的位置,对于NSArray,若想知道A到底在不在数组中,则需要遍历整个数据,显然效率较低了
     并且NSSet里面不含有重复的元素,同一个下载失败的url只会存在一个
     注：1.NSArray是有序的集合，NSSet是无序的集合。
        2.NSSet存储的所有对象只能有唯一一个，不能重复。
        3.NSSet集合是一种哈希表，运用散列算法，查找集合中的元素比数组速度更快，但是它没有顺序。
     **/
    BOOL isFailedUrl = NO;//是否是下载失败过的url
    @synchronized (self.failedURLs) {
        //self.failedURLs里面存放的都是下载失败的图片的url
        isFailedUrl = [self.failedURLs containsObject:url];
    }

    //如果url不存在那么直接返回一个block,如果url存在那么继续
    //SDWebImageRetryFailed:失败url会重新尝试下载
    //如果url为空，或者该url是一个之前下载失败过的url,但是又没有设置SDWebImageRetryFailed，则
    //执行completedBlock，返回错误，并且return该operation
    if (!url || (!(options & SDWebImageRetryFailed) && isFailedUrl)) {
        dispatch_main_sync_safe(^{
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil];
            completedBlock(nil, error, SDImageCacheTypeNone, YES, url);
        });
        return operation;
    }

    //创建一个互斥线程锁来保护把operation加入到self.runningOperations的数组里面
    
    /**
      NSLock *_lock;
     NSMutableArray *_elements;
     _elements = [NSMutableArray array];
     _lock = [[NSLock alloc] init];
     (1):
     [_lock lock];
     [_elements addObject:element];
     [_lock unlock];
     
     (2):
     @synchronized (self) {
     [_elements addObject:element];
     }
     或者
     @synchronized (_elements) {
     [_elements addObject:element];
     }
     你也可以在任何Objective-C的对象上使用@synchronized。因此，同样的我们也可以像下面的例子里一样，使用@synchronized(_elements)来代替@synchronized(self)，这两者的效果是一致的。
   @synchronized的代码块和前面例子中的[ _lock unlock]、[ _lock unlock]的作用相同作用效果。你可以把它理解成把self当作一个NSLock来对self进行加锁。在运行{后的代码前获取锁，并在运行}后的其他代码前释放这个锁。这非常的方便，因为这意味着你永远不会忘了调用unlock
     **/
    @synchronized (self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    //获取image的url对应的key,[self cacheKeyForURL:url]是获取一个完整的url
    NSString *key = [self cacheKeyForURL:url];

    //self.imageCache对象已经在当前类的init方法中实例化了
    operation.cacheOperation = [self.imageCache queryDiskCacheForKey:key done:^(UIImage *image, SDImageCacheType cacheType) {
        if (operation.isCancelled) {
            @synchronized (self.runningOperations) {
                [self.runningOperations removeObject:operation];
            }

            return;
        }

        if ((!image || options & SDWebImageRefreshCached) && (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url])) {
            /**
             !image || options & SDWebImageRefreshCached ：没有找到缓存图片或者设置了SDWebImageRefreshCached
             imageManager:shouldDownloadImageForURL:该方法主要作用是当缓存里没有发现某张图片的缓存时,是否选择下载这张图片(默认是yes),可以选择no,那么sdwebimage在缓存中没有找到这张图片的时候不会选择下载
             (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url])：即代理没有实现该方法（该方法默认是YES）或者返回的是YES,都表明需求下载图片
             **/
            
            if (image && options & SDWebImageRefreshCached) {
                //有图片，但是设置了SDWebImageRefreshCached,回调image（completedBlock(image, nil, cacheType, YES, url);），但是继续往下执行下载更新该图片的操作
                dispatch_main_sync_safe(^{
                    // If image was found in the cache bug SDWebImageRefreshCached is provided, notify about the cached image
                    // AND try to re-download it in order to let a chance to NSURLCache to refresh it from server.
                    completedBlock(image, nil, cacheType, YES, url);
                });
            }

            // download if no image or requested to refresh anyway, and download allowed by delegate
            SDWebImageDownloaderOptions downloaderOptions = 0;
            if (options & SDWebImageLowPriority) downloaderOptions |= SDWebImageDownloaderLowPriority;
            if (options & SDWebImageProgressiveDownload) downloaderOptions |= SDWebImageDownloaderProgressiveDownload;
            if (options & SDWebImageRefreshCached) downloaderOptions |= SDWebImageDownloaderUseNSURLCache;
            if (options & SDWebImageContinueInBackground) downloaderOptions |= SDWebImageDownloaderContinueInBackground;
            if (options & SDWebImageHandleCookies) downloaderOptions |= SDWebImageDownloaderHandleCookies;
            if (options & SDWebImageAllowInvalidSSLCertificates) downloaderOptions |= SDWebImageDownloaderAllowInvalidSSLCertificates;
            if (options & SDWebImageHighPriority) downloaderOptions |= SDWebImageDownloaderHighPriority;
            if (image && options & SDWebImageRefreshCached) {
                // force progressive off if image already cached but forced refreshing
                downloaderOptions &= ~SDWebImageDownloaderProgressiveDownload;
                // ignore image read from NSURLCache if image if cached but force refreshing
                downloaderOptions |= SDWebImageDownloaderIgnoreCachedResponse;
            }
            id <SDWebImageOperation> subOperation = [self.imageDownloader downloadImageWithURL:url options:downloaderOptions progress:progressBlock completed:^(UIImage *downloadedImage, NSData *data, NSError *error, BOOL finished) {
                if (weakOperation.isCancelled) {
                    // Do nothing if the operation was cancelled
                    // See #699 for more details
                    // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data
                }else if (error) {
                    dispatch_main_sync_safe(^{
                        if (!weakOperation.isCancelled) {
                            //不是操作取消了
                            completedBlock(nil, error, SDImageCacheTypeNone, finished, url);
                        }
                    });
                    //判断是否需要将该url加入黑名单
                    if (error.code != NSURLErrorNotConnectedToInternet && error.code != NSURLErrorCancelled && error.code != NSURLErrorTimedOut) {
                        //如果错误不是1.未连接到网络或者2.当异步加载取消或者3.超时这三种时则属于失败的url,会被加入failedURLs数组黑名单，下次不会再下载
                        @synchronized (self.failedURLs) {
                            [self.failedURLs addObject:url];
                        }
                    }
                }else {
                    //到此，已经下载没有出错
                    
                    //判断是否需要缓存到磁盘
                    BOOL cacheOnDisk = !(options & SDWebImageCacheMemoryOnly);

                    if (options & SDWebImageRefreshCached && image && !downloadedImage) {
                        //如果有缓存图片，切设置了SDWebImageRefreshCached，且有新下载的图片
                        //表示刷新了NSURLCache
                        // Image refresh hit the NSURLCache cache, do not call the completion block
                    }else if (downloadedImage && (!downloadedImage.images || (options & SDWebImageTransformAnimatedImage)) && [self.delegate respondsToSelector:@selector(imageManager:transformDownloadedImage:withURL:)]) {
                        //  允许在对下载的图片进行缓存之前进行调整图片，返回一个UIImage
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            //获得调整后的图片
                            UIImage *transformedImage = [self.delegate imageManager:self transformDownloadedImage:downloadedImage withURL:url];

                            if (transformedImage && finished) {
                                //将调整后的图片进行缓存
                                BOOL imageWasTransformed = ![transformedImage isEqual:downloadedImage];
                                [self.imageCache storeImage:transformedImage recalculateFromImage:imageWasTransformed imageData:data forKey:key toDisk:cacheOnDisk];
                            }

                            dispatch_main_sync_safe(^{
                                if (!weakOperation.isCancelled) {
                                    //回调调整后的图片
                                    completedBlock(transformedImage, nil, SDImageCacheTypeNone, finished, url);
                                }
                            });
                        });
                        
                    }else {
                        if (downloadedImage && finished) {
                            //将下载的图片downloadedImage进行缓存
                            [self.imageCache storeImage:downloadedImage recalculateFromImage:NO imageData:data forKey:key toDisk:cacheOnDisk];
                        }

                        dispatch_main_sync_safe(^{
                            if (!weakOperation.isCancelled) {
                                //完成回调
                                completedBlock(downloadedImage, nil, SDImageCacheTypeNone, finished, url);
                            }
                        });
                    }
                }

                if (finished) {
                    //下载完成了，将operation操作移除
                    @synchronized (self.runningOperations) {
                        [self.runningOperations removeObject:operation];
                    }
                }
            }];
            operation.cancelBlock = ^{
                //取消下载
                [subOperation cancel];
                
                @synchronized (self.runningOperations) {
                     //下载取消，将operation操作移除
                    [self.runningOperations removeObject:weakOperation];
                }
            };
        }else if (image) {
            //有缓存图片
            dispatch_main_sync_safe(^{
                if (!weakOperation.isCancelled) {
                    completedBlock(image, nil, cacheType, YES, url);
                }
            });
            @synchronized (self.runningOperations) {
                [self.runningOperations removeObject:operation];
            }
        }else {
            // Image not in cache and download disallowed by delegate
            //没有缓存图片，且不允许下载该图片，回调nil
            dispatch_main_sync_safe(^{
                if (!weakOperation.isCancelled) {
                    completedBlock(nil, nil, SDImageCacheTypeNone, YES, url);
                }
            });
            @synchronized (self.runningOperations) {
                [self.runningOperations removeObject:operation];
            }
        }
    }];

    return operation;
}

- (void)saveImageToCache:(UIImage *)image forURL:(NSURL *)url {
    if (image && url) {
        NSString *key = [self cacheKeyForURL:url];
        [self.imageCache storeImage:image forKey:key toDisk:YES];
    }
}

//取消下载操作
- (void)cancelAll {
    @synchronized (self.runningOperations) {
        NSArray *copiedOperations = [self.runningOperations copy];
        [copiedOperations makeObjectsPerformSelector:@selector(cancel)];
        [self.runningOperations removeObjectsInArray:copiedOperations];
    }
}

- (BOOL)isRunning {
    return self.runningOperations.count > 0;
}

@end

//SDWebImageCombinedOperation它什么也不做,保存了两个东西(一个block,可以取消下载operation,一个operation,cacheOperation用来下载图片并且缓存的operation)

@implementation SDWebImageCombinedOperation

- (void)setCancelBlock:(SDWebImageNoParamsBlock)cancelBlock {
    // check if the operation is already cancelled, then we just call the cancelBlock
    if (self.isCancelled) {
        if (cancelBlock) {
            cancelBlock();
        }
        _cancelBlock = nil; // don't forget to nil the cancelBlock, otherwise we will get crashes
    } else {
        _cancelBlock = [cancelBlock copy];
    }
}

- (void)cancel {
    self.cancelled = YES;
    if (self.cacheOperation) {
        //取消operation的操作
        [self.cacheOperation cancel];
        self.cacheOperation = nil;
    }
    if (self.cancelBlock) {
        self.cancelBlock();
        
        // TODO: this is a temporary fix to #809.
        // Until we can figure the exact cause of the crash, going with the ivar instead of the setter
//        self.cancelBlock = nil;
        _cancelBlock = nil;
    }
}

@end


@implementation SDWebImageManager (Deprecated)

// deprecated method, uses the non deprecated method
// adapter for the completion block
- (id <SDWebImageOperation>)downloadWithURL:(NSURL *)url options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletedWithFinishedBlock)completedBlock {
    return [self downloadImageWithURL:url
                              options:options
                             progress:progressBlock
                            completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                if (completedBlock) {
                                    completedBlock(image, error, cacheType, finished);
                                }
                            }];
}

@end
