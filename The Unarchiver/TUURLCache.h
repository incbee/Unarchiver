#import <Cocoa/Cocoa.h>

@interface TUURLCache:NSObject
{
	NSMutableDictionary *bookmarks;
	NSMutableDictionary *openpaths;
}

-(id)init;
-(void)dealloc;

-(void)cacheURL:(NSURL *)url;

-(BOOL)obtainAccessToPath:(NSString *)path;
-(void)relinquishAccessToPath:(NSString *)path;

@end

