/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

//关于缓存的所有枚举值，
typedef NS_ENUM(NSInteger, SDImageCacheType) {
    /**
     * The image wasn't available the SDWebImage caches, but was downloaded from the web.
     表示图片不是缓存的图片，是从网络请求回来的图片
     */
    SDImageCacheTypeNone,
    /**
     * The image was obtained from the disk cache.
     磁盘缓存
     */
    SDImageCacheTypeDisk,
    /**
     * The image was obtained from the memory cache.
     内存缓存
     */
    SDImageCacheTypeMemory
};

//通过key先去缓存如果没有去磁盘中获取缓存完成后的回调，缓存在磁盘即缓存到沙盒里，默认路径是~Library/Caches下
typedef void(^SDWebImageQueryCompletedBlock)(UIImage *image, SDImageCacheType cacheType);

//查询缓存中是否有该图片后要回调查询结果的block
typedef void(^SDWebImageCheckCacheCompletionBlock)(BOOL isInCache);

//异步的计算磁盘中缓存的大小结果回调的block
typedef void(^SDWebImageCalculateSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);

/**
 * SDImageCache maintains a memory cache and an optional disk cache. Disk cache write operations are performed
 * asynchronous so it doesn’t add unnecessary latency to the UI.
 */
@interface SDImageCache : NSObject

/**
 * Decompressing images that are downloaded and cached can improve peformance but can consume lot of memory.
 * Defaults to YES. Set this to NO if you are experiencing a crash due to excessive memory consumption.
 是否需要解码，默认是yes
 */

@property (assign, nonatomic) BOOL shouldDecompressImages;

/**
 * The maximum "total cost" of the in-memory image cache. The cost function is the number of pixels held in memory.
 设置最大内存占用值
 */
@property (assign, nonatomic) NSUInteger maxMemoryCost;

/**
 * The maximum length of time to keep an image in the cache, in seconds
 设置最大缓存时间 默认是 1 周
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 * The maximum size of the cache, in bytes.
 设置缓存的最大值
 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

/**
 * Returns global shared cache instance
 *
 * @return SDImageCache global instance
 */
+ (SDImageCache *)sharedImageCache;

/**
 * Init a new cache store with a specific namespace
 *
 * @param ns The namespace to use for this cache store
 */
- (id)initWithNamespace:(NSString *)ns;

-(NSString *)makeDiskCachePath:(NSString*)fullNamespace;

/**
 * Add a read-only cache path to search for images pre-cached by SDImageCache
 * Useful if you want to bundle pre-loaded images with your app
 *
 * @param path The path to use for this read-only cache path
 添加只读缓存路径，如果你的应用想绑定预加载图片，通过SDImageCache方便的搜索图片预存储添加一个只读缓存路径。
 */
- (void)addReadOnlyCachePath:(NSString *)path;

/**
 * Store an image into memory and disk cache at the given key.
 *
 * @param image The image to store
 * @param key   The unique image cache key, usually it's image absolute URL
 通过传入的key(通常是图片的完整url),往磁盘和内存中存入该图片
 */
- (void)storeImage:(UIImage *)image forKey:(NSString *)key;

/**
 * Store an image into memory and optionally disk cache at the given key.
 *
 * @param image  The image to store
 * @param key    The unique image cache key, usually it's image absolute URL
 * @param toDisk Store the image to disk cache if YES
 通过传入的key(通常是图片的完整url),往内存中存入该图片，是否存入磁盘是可选项，根据toDisk判断是否往磁盘里存
 */
- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk;

/**
 * Store an image into memory and optionally disk cache at the given key.
 *
 * @param image       The image to store
 * @param recalculate BOOL indicates if imageData can be used or a new data should be constructed from the UIImage
 * @param imageData   The image data as returned by the server, this representation will be used for disk storage
 *                    instead of converting the given image object into a storable/compressed image format in order
 *                    to save quality and CPU
 * @param key         The unique image cache key, usually it's image absolute URL
 * @param toDisk      Store the image to disk cache if YES
 
 */
- (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk;

/**
 * Query the disk cache asynchronously.
 *
 * @param key The unique key used to store the wanted image
 通过key去磁盘中获取缓存，并返回一个NSOperation对象，获取缓存完成后执行SDWebImageQueryCompletedBlock回调
 */
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(SDWebImageQueryCompletedBlock)doneBlock;

/**
 * Query the memory cache synchronously.
 *
 * @param key The unique key used to store the wanted image
 通过key去内存中获取缓存
 */
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key;

/**
 * Query the disk cache synchronously after checking the memory cache.
 *
 * @param key The unique key used to store the wanted image
 在同步的完成内存获取缓存后，去磁盘中获取缓存
 */
- (UIImage *)imageFromDiskCacheForKey:(NSString *)key;

/**
 * Remove the image from memory and disk cache synchronously
 *
 * @param key The unique image cache key
 同步的删除内存和磁盘中的image
 */
- (void)removeImageForKey:(NSString *)key;


/**
 * Remove the image from memory and disk cache synchronously
 *
 * @param key             The unique image cache key
 * @param completion      An block that should be executed after the image has been removed (optional)
  同步的删除内存和磁盘中的image,带了一个SDWebImageNoParamsBlock，该block会在图片被移除后执行
 */
- (void)removeImageForKey:(NSString *)key withCompletion:(SDWebImageNoParamsBlock)completion;

/**
 * Remove the image from memory and optionally disk cache synchronously
 *
 * @param key      The unique image cache key
 * @param fromDisk Also remove cache entry from disk if YES
 删除内存中的图片，并且根据传入的fromDisk来决定是否删除磁盘中该图片
 */
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk;

/**
 * Remove the image from memory and optionally disk cache synchronously
 *
 * @param key             The unique image cache key
 * @param fromDisk        Also remove cache entry from disk if YES
 * @param completion      An block that should be executed after the image has been removed (optional)
 
 删除内存中的图片，并且根据传入的fromDisk来决定是否删除磁盘中该图片，带了一个SDWebImageNoParamsBlock ，该block会在图片被移除后执行
 */
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(SDWebImageNoParamsBlock)completion;

/**
 * Clear all memory cached images
 清除所有内存中的图片缓存
 */
- (void)clearMemory;

/**
 * Clear all disk cached images. Non-blocking method - returns immediately.
 * @param completion    An block that should be executed after cache expiration completes (optional)
 清除所有磁盘中的图片缓存，并且带了SDWebImageNoParamsBlock，该block会在图片被移除后执行
 */
- (void)clearDiskOnCompletion:(SDWebImageNoParamsBlock)completion;

/**
 * Clear all disk cached images
 * @see clearDiskOnCompletion:
 清除磁盘中所有的图片缓存
 */
- (void)clearDisk;

/**
 * Remove all expired cached image from disk. Non-blocking method - returns immediately.
 * @param completionBlock An block that should be executed after cache expiration completes (optional)
 移除磁盘中所有过期的缓存，并且带了SDWebImageNoParamsBlock，该block会在过期图片被移除后执行
 */
- (void)cleanDiskWithCompletionBlock:(SDWebImageNoParamsBlock)completionBlock;

/**
 * Remove all expired cached image from disk
 * @see cleanDiskWithCompletionBlock:
 清除磁盘中所有过期的图片缓存
 */
- (void)cleanDisk;

/**
 * Get the size used by the disk cache
 获取缓存占用磁盘的大小
 */
- (NSUInteger)getSize;

/**
 * Get the number of images in the disk cache
 获取缓存在磁盘中所有图片的总数
 */
- (NSUInteger)getDiskCount;

/**
 * Asynchronously calculate the disk cache's size.
 异步的计算磁盘中缓存的大小，并在计算完成后执行SDWebImageCalculateSizeBlock回调结果
 */
- (void)calculateSizeWithCompletionBlock:(SDWebImageCalculateSizeBlock)completionBlock;

/**
 *  Async check if image exists in disk cache already (does not load the image)
 *
 *  @param key             the key describing the url
 *  @param completionBlock the block to be executed when the check is done.
 *  @note the completion block will be always executed on the main queue
 异步的（开启一个线程）查询key对应的图片是否已经在磁盘缓存中，并传入SDWebImageCheckCacheCompletionBlock，该block会在查询完成后执行
 */
- (void)diskImageExistsWithKey:(NSString *)key completion:(SDWebImageCheckCacheCompletionBlock)completionBlock;

/**
 *  Check if image exists in disk cache already (does not load the image)
 *
 *  @param key the key describing the url
 *
 *  @return YES if an image exists for the given key
  同步（在当前线程） 查询key对应的图片是否已经在磁盘缓存中
 */
- (BOOL)diskImageExistsWithKey:(NSString *)key;

/**
 *  Get the cache path for a certain key (needs the cache path root folder)
 *
 *  @param key  the key (can be obtained from url using cacheKeyForURL)
 *  @param path the cach path root folder
 *
 *  @return the cache path
 */
- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path;

/**
 *  Get the default cache path for a certain key
 *
 *  @param key the key (can be obtained from url using cacheKeyForURL)
 *
 *  @return the default cache path
获取默认额缓存路径
 */
- (NSString *)defaultCachePathForKey:(NSString *)key;

@end
