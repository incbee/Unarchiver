#import "CSURLCache.h"

static BOOL HasPathPrefix(NSString *path,NSString *prefix);

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
		providers=[NSMutableArray new];
		cachedurls=[NSMutableDictionary new];
		cachedbookmarks=[NSMutableDictionary new];

		NSDictionary *storedbookmarks=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"cachedBookmarks"];
		if(storedbookmarks) [cachedbookmarks addEntriesFromDictionary:storedbookmarks];
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

-(void)addURLProvider:(id <CSURLCacheProvider>)provider
{
	[providers addObject:provider];
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
	[cachedurls setObject:url forKey:path];

	[NSUserDefaults.standardUserDefaults setObject:cachedbookmarks forKey:@"cachedBookmarks"];
}

-(NSURL *)securityScopedURLAllowingAccessToURL:(NSURL *)url
{
	return [self securityScopedURLAllowingAccessToPath:url.path];
}

-(NSURL *)securityScopedURLAllowingAccessToPath:(NSString *)path
{
	path=[path stringByResolvingSymlinksInPath];

	for(NSString *bookmarkpath in cachedbookmarks.allKeys)
	{
		if(HasPathPrefix(path,bookmarkpath))
		{
			NSURL *cachedurl=[cachedurls objectForKey:bookmarkpath];
			if(cachedurl) return cachedurl;

			NSData *bookmark=[cachedbookmarks objectForKey:bookmarkpath];

			BOOL isstale;
			NSURL *url=[NSURL URLByResolvingBookmarkData:bookmark
			options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil
			bookmarkDataIsStale:&isstale error:NULL];

			if(url)
			{
				[cachedurls setObject:url forKey:bookmarkpath];
				return url;
			}
		}
	}

	for(id <CSURLCacheProvider> provider in providers)
	{
		for(NSURL *url in provider.securityScopedURLs)
		{
			if(HasPathPrefix(path,url.path)) return url;
		}
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

