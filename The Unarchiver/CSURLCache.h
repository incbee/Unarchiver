#import <Cocoa/Cocoa.h>

@protocol CSURLCacheProvider;

@interface CSURLCache:NSObject

+(CSURLCache *)defaultCache;

-(void)addURLProvider:(id <CSURLCacheProvider>)provider;
-(void)cacheSecurityScopedURL:(NSURL *)url;

-(NSURL *)securityScopedURLAllowingAccessToURL:(NSURL *)url;
-(NSURL *)securityScopedURLAllowingAccessToPath:(NSString *)path;

@end

@protocol CSURLCacheProvider

-(NSArray *)securityScopedURLs;

@end
