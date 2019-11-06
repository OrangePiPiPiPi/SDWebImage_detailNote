/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageDownloader.h"
#import "SDWebImageDownloaderOperation.h"
#import <ImageIO/ImageIO.h>

static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kCompletedCallbackKey = @"completed";

@interface SDWebImageDownloader ()

@property (strong, nonatomic) NSOperationQueue *downloadQueue;
@property (weak, nonatomic) NSOperation *lastAddedOperation;
@property (assign, nonatomic) Class operationClass;
@property (strong, nonatomic) NSMutableDictionary *URLCallbacks;
@property (strong, nonatomic) NSMutableDictionary *HTTPHeaders;
// This queue is used to serialize the handling of the network responses of all the download operation in a single queue
@property (SDDispatchQueueSetterSementics, nonatomic) dispatch_queue_t barrierQueue;

@end

@implementation SDWebImageDownloader

+ (void)initialize {
    // Bind SDNetworkActivityIndicator if available (download it here: http://github.com/rs/SDNetworkActivityIndicator )
    // To use it, just add #import "SDNetworkActivityIndicator.h" in addition to the SDWebImage import
    if (NSClassFromString(@"SDNetworkActivityIndicator")) {

        //同样如果我们希望一个警告在编译的时候，不被识别为警告，我们就可以对警告进行忽略
#pragma clang diagnostic push
         // 忽略undeclared selector的警告
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id activityIndicator = [NSClassFromString(@"SDNetworkActivityIndicator") performSelector:NSSelectorFromString(@"sharedActivityIndicator")];
#pragma clang diagnostic pop
        
        // Remove observer in case it was previously added.
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator name:SDWebImageDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator name:SDWebImageDownloadStopNotification object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator
                                                 selector:NSSelectorFromString(@"startActivity")
                                                     name:SDWebImageDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator
                                                 selector:NSSelectorFromString(@"stopActivity")
                                                     name:SDWebImageDownloadStopNotification object:nil];
    }
}

+ (SDWebImageDownloader *)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (id)init {
    if ((self = [super init])) {
        _operationClass = [SDWebImageDownloaderOperation class];
        _shouldDecompressImages = YES;
        _executionOrder = SDWebImageDownloaderFIFOExecutionOrder;
        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = 6;//默认最大并发数是6
        _URLCallbacks = [NSMutableDictionary new];
        _HTTPHeaders = [NSMutableDictionary dictionaryWithObject:@"image/webp,image/*;q=0.8" forKey:@"Accept"];
        _barrierQueue = dispatch_queue_create("com.hackemist.SDWebImageDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        _downloadTimeout = 15.0;//默认下载超时时长15秒
    }
    return self;
}

- (void)dealloc {
    [self.downloadQueue cancelAllOperations];
    SDDispatchQueueRelease(_barrierQueue);
}

//设置请求头
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (value) {
        self.HTTPHeaders[field] = value;
    }
    else {
        [self.HTTPHeaders removeObjectForKey:field];
    }
}

//获取请求头
- (NSString *)valueForHTTPHeaderField:(NSString *)field {
    return self.HTTPHeaders[field];
}

//设置最大并发数
- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads {
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}

//获取当前并发数
- (NSUInteger)currentDownloadCount {
    return _downloadQueue.operationCount;
}

//获取最大并发数
- (NSInteger)maxConcurrentDownloads {
    return _downloadQueue.maxConcurrentOperationCount;
}

- (void)setOperationClass:(Class)operationClass {
    _operationClass = operationClass ?: [SDWebImageDownloaderOperation class];
}

- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url options:(SDWebImageDownloaderOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageDownloaderCompletedBlock)completedBlock {
    __block SDWebImageDownloaderOperation *operation;
    __weak __typeof(self)wself = self;

    [self addProgressCallback:progressBlock andCompletedBlock:completedBlock forURL:url createCallback:^{
        NSTimeInterval timeoutInterval = wself.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }

        // In order to prevent from potential duplicate caching (NSURLCache + SDImageCache) we disable the cache for image requests if told otherwise
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:(options & SDWebImageDownloaderUseNSURLCache ? NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringLocalCacheData) timeoutInterval:timeoutInterval];
        request.HTTPShouldHandleCookies = (options & SDWebImageDownloaderHandleCookies);
        /**
         如果将HTTPShouldUsePipelining设置为YES, 则允许不必等到response, 就可以再次请求. 这个会很大的提高网络请求的效率,但是也可能会出问题.
         因为客户端无法正确的匹配请求与响应, 所以这依赖于服务器必须保证,响应的顺序与客户端请求的顺序一致.如果服务器不能保证这一点, 那可能导致响应和请求混乱.
         ————————————————
         版权声明：本文为CSDN博主「CC-SunIsland」的原创文章，遵循 CC 4.0 BY-SA 版权协议，转载请附上原文出处链接及本声明。
         原文链接：https://blog.csdn.net/qq_39508154/article/details/75507033
         **/
        request.HTTPShouldUsePipelining = YES;
        if (wself.headersFilter) {
            request.allHTTPHeaderFields = wself.headersFilter(url, [wself.HTTPHeaders copy]);
        }
        else {
            request.allHTTPHeaderFields = wself.HTTPHeaders;
        }
        operation = [[wself.operationClass alloc] initWithRequest:request
                                                          options:options
                                                         progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                                                             SDWebImageDownloader *sself = wself;
                                                             if (!sself) return;
                                                             __block NSArray *callbacksForURL;
                                                             dispatch_sync(sself.barrierQueue, ^{
                                                                 callbacksForURL = [sself.URLCallbacks[url] copy];
                                                             });
                                                             // self.URLCallbacks 是一个字典，key是每个url，value是一个数组，数组里是一个NSMutableDictionary，里面有
                                                            // 两个值，两个值是两个Block,即progressBlock，completedBlock
                                                             for (NSDictionary *callbacks in callbacksForURL) {
                                                                 SDWebImageDownloaderProgressBlock callback = callbacks[kProgressCallbackKey];
                                                                 if (callback) callback(receivedSize, expectedSize);
                                                             }
                                                         }
                                                        completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                                                            SDWebImageDownloader *sself = wself;
                                                            if (!sself) return;
                                                            __block NSArray *callbacksForURL;
                                                            dispatch_barrier_sync(sself.barrierQueue, ^{
                                                                callbacksForURL = [sself.URLCallbacks[url] copy];
                                                                if (finished) {
                                                                    //移除已经完成的url
                                                                    [sself.URLCallbacks removeObjectForKey:url];
                                                                }
                                                            });
                                                            for (NSDictionary *callbacks in callbacksForURL) {
                                                                SDWebImageDownloaderCompletedBlock callback = callbacks[kCompletedCallbackKey];
                                                                if (callback) callback(image, data, error, finished);
                                                            }
                                                        }
                                                        cancelled:^{
                                                            SDWebImageDownloader *sself = wself;
                                                            if (!sself) return;
                                                            dispatch_barrier_async(sself.barrierQueue, ^{
                                                                 //移除已经取消的url
                                                                [sself.URLCallbacks removeObjectForKey:url];
                                                            });
                                                        }];
        operation.shouldDecompressImages = wself.shouldDecompressImages;
        
        if (wself.username && wself.password) {
            operation.credential = [NSURLCredential credentialWithUser:wself.username password:wself.password persistence:NSURLCredentialPersistenceForSession];
            /**
             NSURLCredentialPersistence    explain
             NSURLCredentialPersistenceNone    证书不应该被存储
             NSURLCredentialPersistenceForSession    证书只存在指定的session中
             NSURLCredentialPersistencePermanent    证书存储在keychain中
             NSURLCredentialPersistenceSynchronizable    证书应该永久存储在钥匙串中，另外应该根据拥有的AppleID分发给其他设备。
             **/
        }
        
        //任务优先级关系成正比，优先级越高，越先执行
        //NSOperation使用addDependency添加依赖，控制任务是否进入就绪状态，从而控制任务执行顺序，而优先级(queuePriority)则是控制进入就绪状态任务的执行顺序。
        /**
         任务、队列的取消并不代表可以将当前的操作立即取消，而是当前的操作执行完毕之后不再执行新的操作
         暂停和取消的区别就在于：暂停操作之后还可以恢复操作，继续向下执行；而取消操作之后，所有的操作就清空了，无法再接着执行剩下的操作。
         **/
        if (options & SDWebImageDownloaderHighPriority) {
            operation.queuePriority = NSOperationQueuePriorityHigh;
        } else if (options & SDWebImageDownloaderLowPriority) {
            operation.queuePriority = NSOperationQueuePriorityLow;
        }

        //将操作添加到队列开始下载
        [wself.downloadQueue addOperation:operation];
        if (wself.executionOrder == SDWebImageDownloaderLIFOExecutionOrder) {
            // Emulate LIFO execution order by systematically adding new operations as last operation's dependency
            //如果设置了SDWebImageDownloaderLIFOExecutionOrder，即先进先出，则添加依赖
            [wself.lastAddedOperation addDependency:operation];
            wself.lastAddedOperation = operation;
        }
    }];

    return operation;
}

- (void)addProgressCallback:(SDWebImageDownloaderProgressBlock)progressBlock andCompletedBlock:(SDWebImageDownloaderCompletedBlock)completedBlock forURL:(NSURL *)url createCallback:(SDWebImageNoParamsBlock)createCallback {
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no image or data.
    if (url == nil) {
        if (completedBlock != nil) {
            completedBlock(nil, nil, nil, NO);
        }
        return;
    }
    // 栅栏函数
    /**
     在使用栅栏函数时.使用自定义队列才有意义,如果用的是串行队列或者系统提供的全局并发队列,这个栅栏函数的作用等同于一个同步函数的作用
     1、dispatch_barrier_sync将自己的任务插入到队列的时候，需要等待自己的任务结束之后才会继续插入被写在它后面的任务，然后执行它们
     2、dispatch_barrier_async将自己的任务插入到队列之后，不会等待自己的任务结束，它会继续把后面的任务插入到队列，然后等待自己的任务结束后才执行后面任务。
     
     eg:见文最后
     **/
    dispatch_barrier_sync(self.barrierQueue, ^{
        BOOL first = NO;
        if (!self.URLCallbacks[url]) {
            //第一次请求该url时
            self.URLCallbacks[url] = [NSMutableArray new];
            first = YES;
        }

        // Handle single download of simultaneous download request for the same URL
        NSMutableArray *callbacksForURL = self.URLCallbacks[url];
        NSMutableDictionary *callbacks = [NSMutableDictionary new];
        if (progressBlock) callbacks[kProgressCallbackKey] = [progressBlock copy];
        if (completedBlock) callbacks[kCompletedCallbackKey] = [completedBlock copy];
        [callbacksForURL addObject:callbacks];
        self.URLCallbacks[url] = callbacksForURL;
        /**
         self.URLCallbacks 是一个字典，key是每个url，value是一个数组，数组里是一个NSMutableDictionary，里面有
         两个值，两个值是两个Block,即progressBlock，completedBlock
         **/

        if (first) {
            createCallback();
        }
    });
}

////暂停下载
- (void)setSuspended:(BOOL)suspended {
    [self.downloadQueue setSuspended:suspended];
}

@end


/**
 1.dispatch_barrier_sync:
 
 - (void)initSyncBarrier
 {
 //1 创建并发队列
 dispatch_queue_t concurrentQueue = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT);
 
 //2 向队列中添加任务
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 1,%@",[NSThread currentThread]);
 });
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 2,%@",[NSThread currentThread]);
 });
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 3,%@",[NSThread currentThread]);
 });
 dispatch_barrier_sync(concurrentQueue, ^{
 [NSThread sleepForTimeInterval:1.0];
 NSLog(@"barrier");
 });
 NSLog(@"aa, %@", [NSThread currentThread]);
 
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 4,%@",[NSThread currentThread]);
 });
 NSLog(@"bb, %@", [NSThread currentThread]);
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 5,%@",[NSThread currentThread]);
 });
 }
 2018-02-23 23:16:46.987147+0800 JJWebImage[1399:39117] Task 2,<NSThread: 0x6040002653c0>{number = 4, name = (null)}
 2018-02-23 23:16:46.987145+0800 JJWebImage[1399:39125] Task 3,<NSThread: 0x604000265200>{number = 5, name = (null)}
 2018-02-23 23:16:46.987154+0800 JJWebImage[1399:39116] Task 1,<NSThread: 0x60000027cc40>{number = 3, name = (null)}
 2018-02-23 23:16:47.987597+0800 JJWebImage[1399:39014] barrier
 2018-02-23 23:16:47.987860+0800 JJWebImage[1399:39014] aa, <NSThread: 0x60000006c900>{number = 1, name = main}
 2018-02-23 23:16:47.988025+0800 JJWebImage[1399:39014] bb, <NSThread: 0x60000006c900>{number = 1, name = main}
 2018-02-23 23:16:47.988055+0800 JJWebImage[1399:39116] Task 4,<NSThread: 0x60000027cc40>{number = 3, name = (null)}
 2018-02-23 23:16:47.988263+0800 JJWebImage[1399:39118] Task 5,<NSThread: 0x6040002652c0>{number = 6, name = (null)}
 
 我们可以看到：
 
 Task1,2,3不是顺序执行的因为是异步，但是都在barrier的前面，Task4,5在barrier的后面执行。
 aa和bb都在主线程进行输出。
 执行完barrier，才会将后面的任务4，5插入到队列执行。
 
 
 2.dispatch_barrier_async:
 
 - (void)initAsyncBarrier
 {
 //1 创建并发队列
 dispatch_queue_t concurrentQueue = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT);
 
 //2 向队列中添加任务
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 1,%@",[NSThread currentThread]);
 });
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 2,%@",[NSThread currentThread]);
 });
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 3,%@",[NSThread currentThread]);
 });
 dispatch_barrier_async(concurrentQueue, ^{
 [NSThread sleepForTimeInterval:1.0];
 NSLog(@"barrier");
 });
 NSLog(@"aa, %@", [NSThread currentThread]);
 
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 4,%@",[NSThread currentThread]);
 });
 NSLog(@"bb, %@", [NSThread currentThread]);
 dispatch_async(concurrentQueue, ^{
 NSLog(@"Task 5,%@",[NSThread currentThread]);
 });
 }
 
 2018-02-23 23:10:43.338610+0800 JJWebImage[1362:36007] aa, <NSThread: 0x604000062480>{number = 1, name = main}
 2018-02-23 23:10:43.338665+0800 JJWebImage[1362:36154] Task 1,<NSThread: 0x604000275100>{number = 3, name = (null)}
 2018-02-23 23:10:43.338664+0800 JJWebImage[1362:36153] Task 3,<NSThread: 0x60000007e640>{number = 4, name = (null)}
 2018-02-23 23:10:43.339671+0800 JJWebImage[1362:36007] bb, <NSThread: 0x604000062480>{number = 1, name = main}
 2018-02-23 23:10:43.338731+0800 JJWebImage[1362:36152] Task 2,<NSThread: 0x604000275040>{number = 5, name = (null)}
 2018-02-23 23:10:44.341556+0800 JJWebImage[1362:36153] barrier
 2018-02-23 23:10:44.341849+0800 JJWebImage[1362:36152] Task 5,<NSThread: 0x604000275040>{number = 5, name = (null)}
 2018-02-23 23:10:44.341855+0800 JJWebImage[1362:36153] Task 4,<NSThread: 0x60000007e640>{number = 4, name = (null)}
 
 大家可以看到：
 
 Task1,2,3不是顺序执行的因为是异步，但是都在barrier的前面，Task4,5在barrier的后面执行。
 aa和bb都在主线程进行输出。
 不用执行完barrier，就可以将任务4，5插入到队列中，但是仍然需要执行完barrier，才会执行任务4和5。
 
 总结
 你也可以这么理解，它们二者的差别在于插入barrier后面任务的时机不同。后面任务执行顺序都要在barrier之后，这一点是相同的。
 
 1. 相同点
 
 等待在它前面插入队列的任务先执行完
 
 等待他们自己的任务执行完再执行后面的任务
 
 2. 不同点
 
 dispatch_barrier_sync将自己的任务插入到队列的时候，需要等待自己的任务结束之后才会继续插入被写在它后面的任务，然后执行它们。
 
 dispatch_barrier_async将自己的任务插入到队列之后，不会等待自己的任务结束，它会继续把后面的任务插入到队列，然后等待自己的任务结束后才执行后面任务。
 
 作者：刀客传奇
 链接：<a href='https://www.jianshu.com/p/a0ce5e51286d'>https://www.jianshu.com/p/a0ce5e51286d</a>
 来源：简书
 著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。
 
 ***/
