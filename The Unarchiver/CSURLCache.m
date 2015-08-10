#import "CSURLCache.h"

static BOOL HasPathPrefix(NSString *path,NSString *prefix);

@interface CSURLCache () <CSURLCacheProvider>
@end

@implementation CSURLCache

+(CSURLCache *)defaultCache
{
	if(!getenv("APP_SANDBOX_CONTAINER_ID")) return nil; // Don't bother doing anything unless sandboxed.

	static CSURLCache *defaultcache=nil;
	if(!defaultcache) defaultcache=[CSURLCache new];
	return defaultcache;
}

-(id)init
{
	if((self=[super init]))
	{
		providers=(NSMutableArray *)CFArrayCreateMutable(NULL,0,&(const CFArrayCallBacks){0,NULL,NULL,NULL,NULL});
		cachedurls=[NSMutableDictionary new];
		cachedbookmarks=[NSMutableDictionary new];

		NSDictionary *storedbookmarks=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"cachedBookmarks"];
		if(storedbookmarks) [cachedbookmarks addEntriesFromDictionary:storedbookmarks];

		[self addURLProvider:self];
	}
	return self;
}

-(void)dealloc
{
	[providers release];
	[cachedurls release];
	[cachedbookmarks release];
	[super dealloc];
}

-(void)addURLProvider:(NSObject <CSURLCacheProvider> *)provider
{
	[providers addObject:provider];
}

-(void)removeURLProvider:(NSObject <CSURLCacheProvider> *)provider
{
	[providers removeObjectIdenticalTo:provider];
}

-(void)cacheSecurityScopedURL:(NSURL *)url
{
	if(!url)
	{
		NSLog(@"Attempted to cache a nil URL!");
		return;
	}

	NSString *path=url.path;
	if([cachedbookmarks objectForKey:path]) return;

	NSData *bookmark=[url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
	includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];

	if(!bookmark)
	{
		NSLog(@"Failed to create security-scoped bookmark of URL \"%@\"!",url);
		return;
	}

	for(NSString *bookmarkpath in cachedbookmarks.allKeys)
	{
		if(HasPathPrefix(bookmarkpath,path))
		{
			[cachedbookmarks removeObjectForKey:bookmarkpath];
			[cachedurls removeObjectForKey:bookmarkpath];
		}
	}

	[cachedbookmarks setObject:bookmark forKey:path];

	BOOL isstale;
	[cachedurls setObject:url forKey:[NSURL URLByResolvingBookmarkData:bookmark
	options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil
	bookmarkDataIsStale:&isstale error:NULL]];

	[NSUserDefaults.standardUserDefaults setObject:cachedbookmarks forKey:@"cachedBookmarks"];
	[NSUserDefaults.standardUserDefaults synchronize];
}

-(NSURL *)securityScopedURLAllowingAccessToURL:(NSURL *)url
{
	return [self securityScopedURLAllowingAccessToPath:url.path];
}

-(NSURL *)securityScopedURLAllowingAccessToPath:(NSString *)path
{
	path=[path stringByResolvingSymlinksInPath];

	for(NSObject <CSURLCacheProvider> *provider in providers)
	{
		for(NSString *urlpath in provider.availablePaths)
		{
			if(HasPathPrefix(path,urlpath))
			{
				NSURL *url=[provider securityScopedURLForPath:urlpath];
				if(url) return url;
			}
		}
	}

	return nil;
}

-(NSArray *)availablePaths
{
	return cachedbookmarks.allKeys;
}

-(NSURL *)securityScopedURLForPath:(NSString *)path
{
	NSURL *cachedurl=[cachedurls objectForKey:path];
	if(cachedurl) return cachedurl;

	NSData *bookmark=[cachedbookmarks objectForKey:path];

	BOOL isstale;
	NSURL *url=[NSURL URLByResolvingBookmarkData:bookmark
	options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil
	bookmarkDataIsStale:&isstale error:NULL];

	if(url && !isstale)
	{
		[cachedurls setObject:url forKey:path];
		return url;
	}

	return nil;
}

@end

static BOOL HasPathPrefix(NSString *path,NSString *prefix)
{
	if([path hasPrefix:prefix])
	{
		if(path.length==prefix.length) return YES;
		if([prefix isEqual:@"/"]) return YES;
		unichar c=[path characterAtIndex:prefix.length];
		if(c=='/') return YES;
	}

	return NO;
}

