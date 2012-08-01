#import <Cocoa/Cocoa.h>

@interface TUURLCache:NSObject
{
}

-(id)init;
-(void)dealloc;

-(void)cacheURL:(NSURL *)url;

-(BOOL)obtainAccessToPath:(NSString *)path;
-(void)releaseAccessToPath:(NSString *)path;

@end

