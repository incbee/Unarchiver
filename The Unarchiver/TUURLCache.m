#import "TUURLCache.h"

@implementation TUURLCache

-(id)init
{
	if((self=[super init]))
	{
		bookmarks=[NSMutableDictionary new];
		openpaths=[NSMutableDictionary new];

		NSDictionary *storedbookmarks=[NSUserDefaults.standardUserDefaults
		dictionaryForKey:@"cachedBookmarks"];

		[bookmarks addEntriesFromDictionary:storedbookmarks];
	}
	return self;
}

-(void)dealloc
{
	for(NSURL *url in openpaths.allValues) [url stopAccessingSecurityScopedResource];

	[bookmarks release];
	[openpaths release];
	[super dealloc];
}

-(void)cacheURL:(NSURL *)url
{
	NSString *path=[url.path stringByResolvingSymlinksInPath];

	if([bookmarks objectForKey:path]) return; // Unlikely but maybe possible?

	NSString *pathprefix;
	if([path isEqual:@"/"]) pathprefix=path;
	else pathprefix=[path stringByAppendingString:@"/"];

	NSMutableArray *uselesskeys=[NSMutableArray array];

	for(NSString *bookmarkpath in bookmarks.allKeys)
	{
		if([bookmarkpath hasPrefix:pathprefix]) [uselesskeys addObject:bookmarkpath];
	}

	[bookmarks removeObjectsForKeys:uselesskeys];

	NSData *bookmark=[url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
	includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];

	[bookmarks setObject:bookmark forKey:path];

	[NSUserDefaults.standardUserDefaults setObject:bookmarks
	forKey:@"cachedBookmarks"];
}

-(BOOL)obtainAccessToPath:(NSString *)path
{
	path=[path stringByResolvingSymlinksInPath];

	for(NSString *bookmarkpath in bookmarks.allKeys)
	{
		NSString *bookmarkpathprefix;
		if([bookmarkpath isEqual:@"/"]) bookmarkpathprefix=bookmarkpath;
		else bookmarkpathprefix=[bookmarkpath stringByAppendingString:@"/"];

		if([path isEqual:bookmarkpath]||[path hasPrefix:bookmarkpathprefix])
		{
			NSData *bookmark=[bookmarks objectForKey:bookmarkpath];

			BOOL isstale;
			NSURL *url=[NSURL URLByResolvingBookmarkData:bookmark
			options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil
			bookmarkDataIsStale:&isstale error:NULL];

			[url startAccessingSecurityScopedResource];
			[openpaths setObject:url forKey:path];

			return YES;
		}
	}

	return NO;
}

-(void)relinquishAccessToPath:(NSString *)path
{
	path=[path stringByResolvingSymlinksInPath];

	NSURL *url=[openpaths objectForKey:path];
	if(!url) return;

	[url stopAccessingSecurityScopedResource];

	[openpaths removeObjectForKey:path];
}

@end

