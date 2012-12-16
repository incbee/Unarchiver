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
		cachedurls=[NSMutableArray new];
		cachedbookmarks=[NSMutableArray new];

		id bookmarksobject=[NSUserDefaults.standardUserDefaults objectForKey:@"cachedBookmarks"];

		NSArray *bookmarks=nil;
		if([bookmarksobject isKindOfClass:[NSArray class]]) bookmarks=bookmarksobject;
		else if([bookmarksobject isKindOfClass:[NSDictionary class]]) bookmarks=[bookmarksobject allValues];

		for(NSData *bookmark in bookmarks)
		{
			BOOL isstale;
			NSURL *url=[NSURL URLByResolvingBookmarkData:bookmark
			options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil
			bookmarkDataIsStale:&isstale error:NULL];

			if(url && !isstale)
			{
				[cachedurls addObject:url];
				[cachedbookmarks addObject:bookmark];
			}
		}
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

	if([cachedurls containsObject:url]) return;

	NSString *path=url.path;
	NSMutableIndexSet *uselessindexes=[NSMutableIndexSet indexSet];

	NSUInteger count=cachedurls.count;
	for(NSUInteger i=0;i<count;i++)
	{
		NSURL *cachedurl=[cachedurls objectAtIndex:i];
		if(HasPathPrefix(cachedurl.path,path)) [uselessindexes addIndex:i];
	}

	[cachedurls removeObjectsAtIndexes:uselessindexes];
	[cachedbookmarks removeObjectsAtIndexes:uselessindexes];

	NSData *bookmark=[url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
	includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];

	if(!bookmark)
	{
		NSLog(@"Failed to create security-scoped bookmark of URL \"%@\"!",url);
		return;
	}

	[cachedurls addObject:url];
	[cachedbookmarks addObject:bookmark];

	[NSUserDefaults.standardUserDefaults setObject:cachedbookmarks forKey:@"cachedBookmarks"];
}

-(NSURL *)securityScopedURLAllowingAccessToURL:(NSURL *)url
{
	return [self securityScopedURLAllowingAccessToPath:url.path];
}

-(NSURL *)securityScopedURLAllowingAccessToPath:(NSString *)path
{
	path=[path stringByResolvingSymlinksInPath];

	NSURL *url=[self securityScopedURLAllowingAccessToPath:path fromURLs:cachedurls];
	if(url) return url;

	for(id <CSURLCacheProvider> provider in providers)
	{
		NSURL *url=[self securityScopedURLAllowingAccessToPath:path fromURLs:provider.securityScopedURLs];
		if(url) return url;
	}

	return nil;
}

-(NSURL *)securityScopedURLAllowingAccessToPath:(NSString *)path fromURLs:(NSArray *)urls
{
	for(NSURL *url in urls)
	{
		if(HasPathPrefix(path,url.path)) return url;
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

