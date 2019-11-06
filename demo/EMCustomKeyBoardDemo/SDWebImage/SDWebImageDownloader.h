/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
#import "SDWebImageOperation.h"

typedef NS_OPTIONS(NSUInteger, SDWebImageDownloaderOptions) {
    SDWebImageDownloaderLowPriority = 1 << 0,
    SDWebImageDownloaderProgressiveDownload = 1 << 1,

    /**
     * By default, request prevent the of NSURLCache. With this flag, NSURLCache
     * is used with default policies.
     //默认提供NSURLCache缓存
     */
    SDWebImageDownloaderUseNSURLCache = 1 << 2,

    /**
     * Call completion block with nil image/imageData if the image was read from NSURLCache
     * (to be combined with `SDWebImageDownloaderUseNSURLCache`).
     */

    SDWebImageDownloaderIgnoreCachedResponse = 1 << 3,
    /**
     * In iOS 4+, continue the download of the image if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */

    SDWebImageDownloaderContinueInBackground = 1 << 4,

    /**
     * Handles cookies stored in NSHTTPCookieStore by setting 
     * NSMutableURLRequest.HTTPShouldHandleCookies = YES;
     */
    SDWebImageDownloaderHandleCookies = 1 << 5,

    /**
     * Enable to allow untrusted SSL ceriticates.
     * Useful for testing purposes. Use with caution in production.
     */
    SDWebImageDownloaderAllowInvalidSSLCertificates = 1 << 6,

    /**
     * Put the image in the high priority queue.
     */
    SDWebImageDownloaderHighPriority = 1 << 7,
};

typedef NS_ENUM(NSInteger, SDWebImageDownloaderExecutionOrder) {
    /**
     * Default value. All download operations will execute in queue style (first-in-first-out).
    默认的， 下载操作以队列的形式进行，先进先出
     */
    SDWebImageDownloaderFIFOExecutionOrder,

    /**
     * All download operations will execute in stack style (last-in-first-out).
     下载以栈模式进行，后进先出
     */
    SDWebImageDownloaderLIFOExecutionOrder
};

/**
 注意到，在使用NSNotificationCenter的时候，会需要声明字符串常量，作为NSNotificationCenter的name。这时，const的位置就比较重要，很容易让不了解的人犯错误：
 
 错误的写法（常量指针）：
 
 extern const NSString * RNFooDidCompleteNotification;
 
 正确的写法（指针常量）：
 
 extern NSString * const RNFooDidCompleteNotification;
 
 这里涉及到常量指针和指针常量的概念，简单的来说：
 
 常量指针：就是指向常量的指针，关键字 const 出现在 * 左边，表示指针所指向的地址的内容是不可修改的，但指针自身可变。
 指针常量：指针自身是一个常量，关键字 const 出现在 * 右边，表示指针自身不可变，但其指向的地址的内容是可以被修改的。
 在此例中：我们知道，NSString永远是immutable的，也是一个指针常量，所以NSString * const 是有效的，而const NSString * 则是无效的。而使用错误的写法，则无法阻止修改该指针指向的地址，使得本应该是常量的值能被修改，造成了隐患。这是需要注意的一个常见错误。
 
一、 const的作用和宏是很类似的，其实，苹果是不推荐我们使用宏的，它更喜欢我们使用const，于是乎，在swift中宏就被抛弃了，我们只能使用const。
 const有两个作用：
 1.修饰右边的基本变量和指针变量;
 2.被const修饰的变量只读,也就是只能获取，不能修改。
 
 二、static
 static有两个作用：
 
 1.修饰局部变量:被static修饰的局部变量，可以延长生命周期，生命周期跟整个应用程序一致；被static修饰的局部变量，只会分配一次内存。
 2.修饰全局变量:被static修饰的全局变量，作用域会修改，生命周期不会改,只能在当前文件下使用。
 
 三、extern
 
 extern作用:声明外部全局变量。
 
 extern工作原理:先会去当前文件下查找有没有对应全局变量,如果没有,才会去其他文件查找。
 
 
 使用场景:在多个文件中经常使用的同一个字符串常量，可以使用extern与const组合。
 下面这种就是该场景
 **/
//如果使用了第三放SDNetworkActivityIndicator，SDWebImageDownloadStartNotification和SDWebImageDownloadStopNotification用于控制indicator的显示和隐藏
extern NSString *const SDWebImageDownloadStartNotification;
extern NSString *const SDWebImageDownloadStopNotification;

//下载过程的回调block
typedef void(^SDWebImageDownloaderProgressBlock)(NSInteger receivedSize, NSInteger expectedSize);

//下载完成的回调block
typedef void(^SDWebImageDownloaderCompletedBlock)(UIImage *image, NSData *data, NSError *error, BOOL finished);

typedef NSDictionary *(^SDWebImageDownloaderHeadersFilterBlock)(NSURL *url, NSDictionary *headers);

/**
 * Asynchronous downloader dedicated and optimized for image loading.
 */
@interface SDWebImageDownloader : NSObject

/**
 * Decompressing images that are downloaded and cached can improve peformance but can consume lot of memory.
 * Defaults to YES. Set this to NO if you are experiencing a crash due to excessive memory consumption.
 是否需要解码，默认是yes
 */
@property (assign, nonatomic) BOOL shouldDecompressImages;

//设置最大并发数
@property (assign, nonatomic) NSInteger maxConcurrentDownloads;

/**
 * Shows the current amount of downloads that still need to be downloaded
 */
@property (readonly, nonatomic) NSUInteger currentDownloadCount;


/**
 *  The timeout value (in seconds) for the download operation. Default: 15.0.
 下载操作的超时时间，默认是15秒
 */
@property (assign, nonatomic) NSTimeInterval downloadTimeout;


/**
 * Changes download operations execution order. Default value is `SDWebImageDownloaderFIFOExecutionOrder`.
 下载超的执行顺序，默认是SDWebImageDownloaderFIFOExecutionOrder（队列形式，先进先出）
 */
@property (assign, nonatomic) SDWebImageDownloaderExecutionOrder executionOrder;

/**
 *  Singleton method, returns the shared instance
 *
 *  @return global shared instance of downloader class
 单例
 */
+ (SDWebImageDownloader *)sharedDownloader;

/**
 * Set username
 */
@property (strong, nonatomic) NSString *username;

/**
 * Set password
 */
@property (strong, nonatomic) NSString *password;

/**
 * Set filter to pick headers for downloading image HTTP request.
 *
 * This block will be invoked for each downloading image request, returned
 * NSDictionary will be used as headers in corresponding HTTP request.
 */
@property (nonatomic, copy) SDWebImageDownloaderHeadersFilterBlock headersFilter;

/**
 * Set a value for a HTTP header to be appended to each download HTTP request.
 *
 * @param value The value for the header field. Use `nil` value to remove the header.
 * @param field The name of the header field to set.
 */
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

/**
 * Returns the value of the specified HTTP header field.
 *
 * @return The value associated with the header field field, or `nil` if there is no corresponding header field.
 */
- (NSString *)valueForHTTPHeaderField:(NSString *)field;

/**
 * Sets a subclass of `SDWebImageDownloaderOperation` as the default
 * `NSOperation` to be used each time SDWebImage constructs a request
 * operation to download an image.
 *
 * @param operationClass The subclass of `SDWebImageDownloaderOperation` to set 
 *        as default. Passing `nil` will revert to `SDWebImageDownloaderOperation`.
 */
- (void)setOperationClass:(Class)operationClass;

/**
 * Creates a SDWebImageDownloader async downloader instance with a given URL
 *
 * The delegate will be informed when the image is finish downloaded or an error has happen.
 *
 * @see SDWebImageDownloaderDelegate
 *
 * @param url            The URL to the image to download
 * @param options        The options to be used for this download
 * @param progressBlock  A block called repeatedly while the image is downloading
 * @param completedBlock A block called once the download is completed.
 *                       If the download succeeded, the image parameter is set, in case of error,
 *                       error parameter is set with the error. The last parameter is always YES
 *                       if SDWebImageDownloaderProgressiveDownload isn't use. With the
 *                       SDWebImageDownloaderProgressiveDownload option, this block is called
 *                       repeatedly with the partial image object and the finished argument set to NO
 *                       before to be called a last time with the full image and finished argument
 *                       set to YES. In case of error, the finished argument is always YES.
 *
 * @return A cancellable SDWebImageOperation
 */
- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageDownloaderOptions)options
                                        progress:(SDWebImageDownloaderProgressBlock)progressBlock
                                       completed:(SDWebImageDownloaderCompletedBlock)completedBlock;

/**
 * Sets the download queue suspension state
 */
- (void)setSuspended:(BOOL)suspended;

@end
