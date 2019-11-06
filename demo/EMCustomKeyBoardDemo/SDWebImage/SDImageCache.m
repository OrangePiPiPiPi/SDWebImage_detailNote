/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageCache.h"
#import "SDWebImageDecoder.h"
#import "UIImage+MultiFormat.h"
#import <CommonCrypto/CommonDigest.h>

//默认最大缓存时间是一周
static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7; // 1 week
// PNG signature bytes and data (below)

static unsigned char kPNGSignatureBytes[8] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
static NSData *kPNGSignatureData = nil;

BOOL ImageDataHasPNGPreffix(NSData *data);

// ImageDataHasPNGPreffix就是为了判断imageData前8个字节是不是符合PNG标志
//用来判断图片是否是PNG格式图片的。其原理是：PNG图片很容易检测，因为它拥有一个独特的签名，PNG文件的前八字节经常包含如下（十进制）的数值137 80 78 71 13 10 26 10。（八进制：0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A）我们正可据此鉴别PNG文件。
BOOL ImageDataHasPNGPreffix(NSData *data) {
    NSUInteger pngSignatureLength = [kPNGSignatureData length];
    if ([data length] >= pngSignatureLength) {
        //subdataWithRange：截取data指定位置的子data
        //Returns a new data object containing the data object's bytes that fall within the limits specified by a given range.
        if ([[data subdataWithRange:NSMakeRange(0, pngSignatureLength)] isEqualToData:kPNGSignatureData]) {
            return YES;
        }
    }

    return NO;
}

/**
 SDCacheCostForImage指向一个静态内联函数,其中FOUNDATION_STATIC_INLINE作为宏指向static inline
 FOUNDATION_STATIC_INLINE NSUInteger SDCacheCostForImage(UIImage *image)也等价于
 static __inline__ NSUInteger SDCacheCostForImage(UIImage *image)
 1.内联函数中尽量不要使用诸如循环语句等大量代码、可能会导致编译器放弃内联动作。
 2.内联函数的定义须在调用之前。
 ps:内联函数
 对于一些函数
 体代码不是很大，但又频繁地被调用的函数来讲，解决其效率问题更为重要。引入内联函数实际上就是为了解决这一问题。
 static是静态修饰符, 由他修饰的变量会保存在全局数据区，普通的局部变量或者全局变量, 都是有系统自动分配内存的, 并且当变量离开作用域的时候释放掉，而使用static修饰的变量, 则会在程序运行期都不会释放, 只有当程序结束的时候才会释放， 因此对于那些需要反复使用的变量, 我们通常使用static来修饰, 避免重复创建导致不必要的内存开销
 
 static inline
 inline函数, 即内联函数, 他可以向编译器申请, 将使用inline修饰的函数内容, 内联到函数调用的位置，内联函数的作用类似于#define, 但是他比#define有一些优点，相对于函数直接调用: inline修饰的函数, 不会再调用这个函数的时候, 调用call方法, 就不会将函数压栈, 产生内存消耗，相对于宏:1.宏需要预编译, 而内联函数是一个函数, 不需要预编译
 2.编译器调用内联函数的时候, 会检查函数的传参是否正确, 但是宏就不会提醒参数。3.内联函数只能对一些小型的函数起作用, 如果函数中消耗的内存很大, 比如for循环, 则内联函数就会默认失效。
 对于一些经常用的做判断的小方法, 可以使用内联函数, 避免使用#define的过于臃肿
 
 **/
FOUNDATION_STATIC_INLINE NSUInteger SDCacheCostForImage(UIImage *image) {
    return image.size.height * image.size.width * image.scale * image.scale;
}

@interface SDImageCache ()

@property (strong, nonatomic) NSCache *memCache;
@property (strong, nonatomic) NSString *diskCachePath;
@property (strong, nonatomic) NSMutableArray *customPaths;
//一个队列属性
@property (SDDispatchQueueSetterSementics, nonatomic) dispatch_queue_t ioQueue;

@end


@implementation SDImageCache {
    NSFileManager *_fileManager;
}

//生成一个单例
+ (SDImageCache *)sharedImageCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (id)init {
    return [self initWithNamespace:@"default"];
}

- (id)initWithNamespace:(NSString *)ns {
    if ((self = [super init])) {
        NSString *fullNamespace = [@"com.hackemist.SDWebImageCache." stringByAppendingString:ns];

        // initialise PNG signature data
        //初始化PNG图片签名
        kPNGSignatureData = [NSData dataWithBytes:kPNGSignatureBytes length:8];

        // Create IO serial queue
        //初始化队列，创建串行队列：
        _ioQueue = dispatch_queue_create("com.hackemist.SDWebImageCache", DISPATCH_QUEUE_SERIAL);

        // Init default values
        //初始化最大缓存时长
        _maxCacheAge = kDefaultCacheMaxCacheAge;

        // Init the memory cache
        /**
         关于NSCache
         NSCache是Foundation框架提供的缓存类的实现，使用方式类似于可变字典，由于NSMutableDictionary的存在，很多人在实现缓存时都会使用可变字典，但NSCache在实现缓存功能时比可变字典更方便，最重要的是它是线程安全的，而NSMutableDictionary不是线程安全的，在多线程环境下使用NSCache是更好的选择
         
         1.线程安全
         2.在内存不足时NSCache会自动释放存储的对象，不需要手动干预
         3.NSCache的键key不会被复制，所以key不需要实现NSCopying协议
         实现缓存功能时，使用NSCache就是我们的不二之选。
         
         **/
        _memCache = [[NSCache alloc] init];
        // _memCache.name 缓存的名称
        _memCache.name = fullNamespace;

        // Init the disk cache
        //初始化磁盘缓存的路径（即保存在）~Library/Caches下创建了一个文件夹（com.hackemist.SDWebImageCache.default）
        /**
        iOS 沙盒目录
         1.Documents :保存持久化数据，会备份到iCloud。一般用来存储需要持久化的数据
         2.Library:
         -> 包含
             a.Caches: 缓存数据应该保存在/Library/Caches目录下.缓存数据在设备低存储空间时可能会被删除，iTunes或iCloud不会对其进行备份,当访问网络时系统自动会把访问的url,以数据库的方式存放在此目录下面.
             b.Preferences:NSUserDefaults就是默认存放在此文件夹下面,iTunes或iCloud会备份该目录
             c.Application Support
             d.Cookies
             e.WebKit
         3.SystemData:新加入的一个文件夹, 存放系统的一些东西,
         4.tmp:临时文件夹,系统可能会清空该目录下的数据，iTunes或iCloud也不会对其进行备份。
         **/
        _diskCachePath = [self makeDiskCachePath:fullNamespace];

        // Set decompression to YES
        //默认压缩图片
        _shouldDecompressImages = YES;

        dispatch_sync(_ioQueue, ^{
            _fileManager = [NSFileManager new];
        });

#if TARGET_OS_IPHONE
        // Subscribe to app events
        //注册通知，app接收到内存警告是触发，清理内存
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];

        //注册通知，触发时机：程序被杀死时调用。清理磁盘
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanDisk)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        //注册通知，触发时机：程序进入后台时调用。
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundCleanDisk)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SDDispatchQueueRelease(_ioQueue);
}

//添加只读缓存路径，如果你的应用想绑定预加载图片，通过SDImageCache方便的搜索图片预存储添加一个只读缓存路径。
//该路径存放在customPaths可变数组里
- (void)addReadOnlyCachePath:(NSString *)path {
    if (!self.customPaths) {
        self.customPaths = [NSMutableArray new];
    }

    if (![self.customPaths containsObject:path]) {
        [self.customPaths addObject:path];
    }
}


- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path {
    NSString *filename = [self cachedFileNameForKey:key];
    return [path stringByAppendingPathComponent:filename];
}

//获取默认额缓存路径，默认路径是~Library/Caches下创建的一个文件夹（com.hackemist.SDWebImageCache.default）
- (NSString *)defaultCachePathForKey:(NSString *)key {
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

#pragma mark SDImageCache (private)
//写入磁盘时、用url的MD5编码作为key。可以防止文件名过长
- (NSString *)cachedFileNameForKey:(NSString *)key {
    const char *str = [key UTF8String];
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                                                    r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];

    return filename;
}

#pragma mark ImageCache

// 初始化磁盘缓存路径
-(NSString *)makeDiskCachePath:(NSString*)fullNamespace{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:fullNamespace];
}

- (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk {
    if (!image || !key) {
        return;
    }

    /**
     写入缓存时、直接用图片url作为key
     写入缓存时、直接用图片url作为key
     写入磁盘时、用url的MD5编码作为key。可以防止文件名过长
     **/
    NSUInteger cost = SDCacheCostForImage(image);
    //写入内存缓存
    [self.memCache setObject:image forKey:key cost:cost];

    //如果需要进行磁盘缓存
    if (toDisk) {
        //dispatch_async:异步任务，self.ioQueue串行队列，结果：开启一个新的线程，同步执行磁盘缓存
        dispatch_async(self.ioQueue, ^{
            NSData *data = imageData;

            if (image && (recalculate || !data)) {
                //image存在，切imageData不存在或者recalculate为yes
#if TARGET_OS_IPHONE
                // We need to determine if the image is a PNG or a JPEG
                // PNGs are easier to detect because they have a unique signature (http://www.w3.org/TR/PNG-Structure.html)
                // The first eight bytes of a PNG file always contain the following (decimal) values:
                // 137 80 78 71 13 10 26 10

                // We assume the image is PNG, in case the imageData is nil (i.e. if trying to save a UIImage directly),
                // we will consider it PNG to avoid loosing the transparency
                BOOL imageIsPng = YES;

                // But if we have an image data, we will look at the preffix
                if (imageData && [imageData length] >= [kPNGSignatureData length]) {
                    imageIsPng = ImageDataHasPNGPreffix(imageData);
                }

                /**
                 UIImageJPEGRepresentation函数需要两个参数:图片的引用和压缩系数.而UIImagePNGRepresentation只需要图片引用作为参数.通过在实际使用过程中,比较发现:UIImagePNGRepresentation(UIImage* image) 要比UIImageJPEGRepresentation(UIImage* image, 1.0)返回的图片数据量大很多
                 **/
                if (imageIsPng) {
                    
                    data = UIImagePNGRepresentation(image);
                }
                else {
                    data = UIImageJPEGRepresentation(image, (CGFloat)1.0);
                }
#else
                data = [NSBitmapImageRep representationOfImageRepsInArray:image.representations usingType: NSJPEGFileType properties:nil];
#endif
            }

            if (data) {
                if (![_fileManager fileExistsAtPath:_diskCachePath]) {
                    //如果沙盒里没有缓存的文件夹，则创建一个文件夹
                    [_fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
                }
                
                //创建文件
                [_fileManager createFileAtPath:[self defaultCachePathForKey:key] contents:data attributes:nil];
            }
        });
    }
}
/**
 为什么会死锁？
 如果在主线程中运用主队列同步，也就是把任务放到了主线程的队列中。
 而同步对于任务是立刻执行的，那么当把第一个任务放进主队列时，它就会立马执行。
 可是主线程现在正在处理 syncMain 方法，任务需要等 syncMain 执行完才能执行。
 syncMain 执行到第一个任务的时候，又要等第一个任务执行完才能往下执行第二个和第三个任务。
 这样 syncMain 方法和第一个任务就开始了互相等待，形成了死锁。
- (void)syncMain {
    NSLog(@"\n\n**************主队列同步，放到主线程会死锁***************\n\n");
    
    // 主队列
    dispatch_queue_t queue = dispatch_get_main_queue();
    
    dispatch_sync(queue, ^{
        for (int i = 0; i < 3; i++) {
            NSLog(@"主队列同步1   %@",[NSThread currentThread]);
        }
    });
    dispatch_sync(queue, ^{
        for (int i = 0; i < 3; i++) {
            NSLog(@"主队列同步2   %@",[NSThread currentThread]);
        }
    });
 
 **/

/**
 缓存数据，此处image有值，recalculateFromImage传了yes,imageData传入nil,
 - (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk方法实现里，图片默认是当成png处理,如果imageData不为空，怎判断该图片是PNG 还是 JPEG，此处通过image转成NSData然后保存和磁盘中
 **/

- (void)storeImage:(UIImage *)image forKey:(NSString *)key {
    [self storeImage:image recalculateFromImage:YES imageData:nil forKey:key toDisk:YES];
}

//同上，但是通过toDisk判断是否缓存到磁盘
- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk {
    [self storeImage:image recalculateFromImage:YES imageData:nil forKey:key toDisk:toDisk];
}

//判断磁盘缓存文件夹里是否有key对应的文件（在当前线程查）
- (BOOL)diskImageExistsWithKey:(NSString *)key {
    BOOL exists = NO;
    
    // this is an exception to access the filemanager on another queue than ioQueue, but we are using the shared instance
    // from apple docs on NSFileManager: The methods of the shared NSFileManager object can be called from multiple threads safely.
    exists = [[NSFileManager defaultManager] fileExistsAtPath:[self defaultCachePathForKey:key]];
    
    return exists;
}

//判断磁盘缓存文件夹里是否有key对应的文件（新开了一个线程查）
- (void)diskImageExistsWithKey:(NSString *)key completion:(SDWebImageCheckCacheCompletionBlock)completionBlock {
    dispatch_async(_ioQueue, ^{
        BOOL exists = [_fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

//查内存中是否有key对应的缓存图片
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key {
    return [self.memCache objectForKey:key];
}

//查询磁盘中key对应的缓存图片，但是会先查询内存中是否有该图片，如果有就直接返回，没有再查询磁盘中
- (UIImage *)imageFromDiskCacheForKey:(NSString *)key {
    // First check the in-memory cache...
    //检查内存中是否有
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        return image;
    }

    // Second check the disk cache...
    //检查磁盘中是否有
    UIImage *diskImage = [self diskImageForKey:key];
    if (diskImage) {
        //如果在磁盘中查询到了缓存图片，则先将图片添加到内存缓存中
        NSUInteger cost = SDCacheCostForImage(diskImage);
        [self.memCache setObject:diskImage forKey:key cost:cost];
    }

    return diskImage;
}

//检查磁盘中是否有key对应的图片
- (UIImage *)diskImageForKey:(NSString *)key {
    NSData *data = [self diskImageDataBySearchingAllPathsForKey:key];
    if (data) {
        ////通过data，获取首字节判断是什么类型的图片，然后将data转换成UIImage返回
        UIImage *image = [UIImage sd_imageWithData:data];
        
        //防止url里面包含@"2x"、@"3x"等字符串，从而使图片size变大问题，处理图片
        image = [self scaledImageForKey:key image:image];
        
        //如果设置了解码图片就解码
        if (self.shouldDecompressImages) {
            //解码图片
            image = [UIImage decodedImageWithImage:image];
        }
        return image;
    }
    else {
        return nil;
    }
}

/**
根据传入的key拼接一个路径,先读取默认缓存路径下文件，如果有返回该数据，如果没有，则通过循环查找自定义路径数组self.customPaths下的文件，如果有key对应的文件，读取并返回该数据
 **/
- (NSData *)diskImageDataBySearchingAllPathsForKey:(NSString *)key {
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    if (data) {
        return data;
    }

    NSArray *customPaths = [self.customPaths copy];
    for (NSString *path in customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath];
        if (imageData) {
            return imageData;
        }
    }

    return nil;
}


 //防止url里面包含@"2x"、@"3x"等字符串，从而使图片size变大问题，处理图片
- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image {
    return SDScaledImageForKey(key, image);
}

//查询磁盘中key对应的缓存图片，但是会先查询内存中是否有该图片，如果有就直接返回，没有再查询磁盘中
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(SDWebImageQueryCompletedBlock)doneBlock {
    if (!doneBlock) {
        return nil;
    }

    if (!key) {
        doneBlock(nil, SDImageCacheTypeNone);
        return nil;
    }

    // First check the in-memory cache...
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        doneBlock(image, SDImageCacheTypeMemory);
        return nil;
    }

    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{
        if (operation.isCancelled) {
            return;
        }

        @autoreleasepool {
            //检查磁盘中是否有key对应的图片
            UIImage *diskImage = [self diskImageForKey:key];
            if (diskImage) {
                NSUInteger cost = SDCacheCostForImage(diskImage);
                [self.memCache setObject:diskImage forKey:key cost:cost];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                doneBlock(diskImage, SDImageCacheTypeDisk);
            });
        }
    });

    return operation;
}

//根据key清除内存和磁盘中的缓存
- (void)removeImageForKey:(NSString *)key {
    [self removeImageForKey:key withCompletion:nil];
}

////根据key清除内存和磁盘中的缓存
- (void)removeImageForKey:(NSString *)key withCompletion:(SDWebImageNoParamsBlock)completion {
    [self removeImageForKey:key fromDisk:YES withCompletion:completion];
}

////根据key清除内存的缓存,根据fromDisk判断是否需要清除磁盘中缓存
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk {
    [self removeImageForKey:key fromDisk:fromDisk withCompletion:nil];
}

//清除缓存
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(SDWebImageNoParamsBlock)completion {
    
    if (key == nil) {
        return;
    }
    
    [self.memCache removeObjectForKey:key];
    
    if (fromDisk) {
        dispatch_async(self.ioQueue, ^{
            [_fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
    } else if (completion){
        completion();
    }
    
}

//设置最大内存占用量
- (void)setMaxMemoryCost:(NSUInteger)maxMemoryCost {
    self.memCache.totalCostLimit = maxMemoryCost;
}

//获取最大内存占用量的值
- (NSUInteger)maxMemoryCost {
    return self.memCache.totalCostLimit;
}

//清除内存缓存
- (void)clearMemory {
    [self.memCache removeAllObjects];
}

//清除磁盘中的缓存
- (void)clearDisk {
    [self clearDiskOnCompletion:nil];
}

//清除磁盘中的缓存
- (void)clearDiskOnCompletion:(SDWebImageNoParamsBlock)completion
{
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:self.diskCachePath error:nil];
        [_fileManager createDirectoryAtPath:self.diskCachePath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

//收到程序被杀死的通知会执行该方法
- (void)cleanDisk {
    [self cleanDiskWithCompletionBlock:nil];
}

// 清理过期的缓存图片
- (void)cleanDiskWithCompletionBlock:(SDWebImageNoParamsBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        NSArray *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];

        // This enumerator prefetches useful properties for our cache files.
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];

        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
        NSMutableDictionary *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;

        // Enumerate all of the files in the cache directory.  This loop has two purposes:
        //
        //  1. Removing files that are older than the expiration date.
        //  2. Storing file attributes for the size-based cleanup pass.
        NSMutableArray *urlsToDelete = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];

            // Skip directories.是文件夹则跳过
            if ([resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }

            // Remove files that are older than the expiration date;
            //modificationDate获取当前文件上次修改时间
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                [urlsToDelete addObject:fileURL];
                continue;
            }

            // Store a reference to this file and account for its total size.
            //计算剩余未过期的文件大小，并添加到cacheFiles数组里
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            currentCacheSize += [totalAllocatedSize unsignedIntegerValue];
            [cacheFiles setObject:resourceValues forKey:fileURL];
        }
        
        //删除过期文件
        for (NSURL *fileURL in urlsToDelete) {
            [_fileManager removeItemAtURL:fileURL error:nil];
        }

        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        //如果当前剩余缓存文件大小大于设置的最大缓存数量，先删除日期早的文件
        if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.maxCacheSize / 2;

            // Sort the remaining cache files by their last modification time (oldest first).
            //将剩余缓存文件按时间排序的到一个数组sortedFiles，离当前时间越久的排在最前面，然后依次删除文件，直到剩余文件大小小于desiredCacheSize（即设置的最大缓存数的一半）
            NSArray *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                            usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                            }];

            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([_fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= [totalAllocatedSize unsignedIntegerValue];

                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

//程序进入后台时调用,清理过期的缓存图片
/**
 正常程序退出后，会在几秒内停止工作；
 要想申请更长的时间，需要用到
 beginBackgroundTaskWithExpirationHandler
 endBackgroundTask
 一定要成对出现
 **/
- (void)backgroundCleanDisk {
    UIApplication *application = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    [self cleanDiskWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

- (NSUInteger)getSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtPath:self.diskCachePath];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    return size;
}

//获取缓存数量
- (NSUInteger)getDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtPath:self.diskCachePath];
        count = [[fileEnumerator allObjects] count];
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(SDWebImageCalculateSizeBlock)completionBlock {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];

    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;

        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:@[NSFileSize]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];

        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += [fileSize unsignedIntegerValue];
            fileCount += 1;
        }

        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

@end
