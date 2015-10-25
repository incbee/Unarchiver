#import "CSFileTypeList.h"

static BOOL IsLeopardOrAbove()
{
	return NSAppKitVersionNumber>=949;
}

static BOOL IsYosemiteOrAbove()
{
	return NSAppKitVersionNumber>=1343;
}


@implementation CSFileTypeList

static BOOL DisabledInSandbox=YES;

+(void)setDisabledInSandbox:(BOOL)disabled
{
	DisabledInSandbox=disabled;
}

-(id)initWithCoder:(NSCoder *)coder
{
	if((self=[super initWithCoder:coder]))
	{
		datasource=[CSFileTypeListSource new];
		[self setDataSource:datasource];
		blockerview=nil;

		[self disableOnAppStore];
	}
	return self;
}

-(id)initWithFrame:(NSRect)frame
{
	if((self=[super initWithFrame:frame]))
	{
		NSLog(@"Custom view mode in IB not supported yet");

		datasource=[CSFileTypeListSource new];
		[self setDataSource:datasource];
		blockerview=nil;

		[self disableOnAppStore];
	}
	return self;
}

-(void)dealloc
{
	[datasource release];
	[blockerview release];
	[super dealloc];
}

-(IBAction)selectAll:(id)sender
{
	[datasource claimAllTypesExceptAlternate];
	[self reloadData];
}

-(IBAction)deselectAll:(id)sender
{
	[datasource surrenderAllTypes];
	[self reloadData];
}

-(void)disableOnAppStore
{
	if(!DisabledInSandbox) return;
	if(!getenv("APP_SANDBOX_CONTAINER_ID")) return;
	if(!IsYosemiteOrAbove()) return;

	NSTextField *label=[[[NSTextField alloc] initWithFrame:[self bounds]] autorelease];
	[label setTextColor:[NSColor whiteColor]];
	[label setBackgroundColor:[NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:0.75]];
	[label setFont:[NSFont systemFontOfSize:17]];
	[label setAlignment:NSCenterTextAlignment];
	[label setBezeled:NO];
	[label setEditable:NO];
	[label setSelectable:NO];
	[label setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

	NSString *appname=[[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
	if(!appname || ![appname length]) appname=[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
	if(!appname || ![appname length]) appname=[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];

	NSString *title=[NSString stringWithFormat:NSLocalizedString(
	@"\nSetting %@ as the default app",@"App store file format limitation title"),
	appname];
	NSString *message=[NSString stringWithFormat:NSLocalizedString(
	@"\n\nTo set %1$@ to be the default application for a file type:\n\n"
	@"1. Use the \"File -> Get Info\" menu in the Finder on a file of that type.\n"
	@"2. Use \"Open with...\" to select %1$@.\n"
	@"3. Click \"Change All...\"",
	@"App store file format limitation message format"),appname];

	NSMutableParagraphStyle *centeredstyle=[[NSMutableParagraphStyle new] autorelease];
	[centeredstyle setFirstLineHeadIndent:32];
	[centeredstyle setHeadIndent:32];
	[centeredstyle setTailIndent:-32];
	[centeredstyle setAlignment:NSCenterTextAlignment];

	NSMutableParagraphStyle *leftstyle=[[NSMutableParagraphStyle new] autorelease];
	[leftstyle setFirstLineHeadIndent:32];
	[leftstyle setHeadIndent:32];
	[leftstyle setTailIndent:-32];
	[leftstyle setAlignment:NSLeftTextAlignment];

	NSMutableAttributedString *string=[[NSMutableAttributedString new] autorelease];

	[string appendAttributedString:[[[NSAttributedString alloc]
	initWithString:title
	attributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont boldSystemFontOfSize:16],NSFontAttributeName,
		[NSColor whiteColor],NSForegroundColorAttributeName,
		centeredstyle,NSParagraphStyleAttributeName,
	nil]] autorelease]];

	[string appendAttributedString:[[[NSAttributedString alloc]
	initWithString:message
	attributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont boldSystemFontOfSize:12],NSFontAttributeName,
		[NSColor whiteColor],NSForegroundColorAttributeName,
		leftstyle,NSParagraphStyleAttributeName,
	nil]] autorelease]];

	[label setAttributedStringValue:string];

	blockerview=[label retain];
	[[self superview] addSubview:blockerview];
}

-(void)viewDidMoveToSuperview
{
	[blockerview removeFromSuperview];
	[[self superview] addSubview:blockerview];
}

@end



@implementation CSFileTypeListSource:NSObject

-(id)init
{
	if((self=[super init]))
	{
		filetypes=[[self readFileTypes] retain];
	}
	return self;
}

-(void)dealloc
{
	[filetypes release];
	[super dealloc];
}

-(NSArray *)readFileTypes
{
	NSMutableArray *array=[NSMutableArray array];
	NSArray *types=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"];
	NSArray *hidden=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CSHiddenDocumentTypes"];
	NSEnumerator *enumerator=[types objectEnumerator];
	NSDictionary *dict;

	while((dict=[enumerator nextObject]))
	{
		NSArray *types=[dict objectForKey:@"LSItemContentTypes"];
		if(types && [types count])
		{
			NSString *description=[dict objectForKey:@"CFBundleTypeName"];
			NSString *extensions=[[dict objectForKey:@"CFBundleTypeExtensions"] componentsJoinedByString:@", "];
			NSString *type=[types objectAtIndex:0];

			NSString *rank=[dict objectForKey:@"LSHandlerRank"];
			NSNumber *alternate=[NSNumber numberWithBool:rank && [rank isEqual:@"Alternate"]];

			// Zip UTI kludge
			if(IsLeopardOrAbove() && [type isEqual:@"com.pkware.zip-archive"]&&[types count]>1)
			type=[types objectAtIndex:1];

			if(!hidden||![hidden containsObject:type])
			[array addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				type,@"type",
				description,@"description",
				extensions,@"extensions",
				alternate,@"alternate",
			nil]];
		}
	}

	return [NSArray arrayWithArray:array];
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)table
{
	return [filetypes count];
}

-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row
{
	NSString *ident=[column identifier];

	if([ident isEqual:@"enabled"])
	{
		NSString *self_id=[[NSBundle mainBundle] bundleIdentifier];
		NSString *type=[[filetypes objectAtIndex:row] objectForKey:@"type"];
		NSString *handler=[(id)LSCopyDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer) autorelease];

		return [NSNumber numberWithBool:[self_id caseInsensitiveCompare:handler]==0];
	}
	else if([ident isEqual:@"browse"])
	{
		NSString *type=[[filetypes objectAtIndex:row] objectForKey:@"type"];
		NSString *key=[NSString stringWithFormat:@"disableBrowsing.%@",type];
		BOOL disabled=[[NSUserDefaults standardUserDefaults] boolForKey:key];

		return [NSNumber numberWithBool:!disabled];
	}
	else
	{
		return [[filetypes objectAtIndex:row] objectForKey:ident];
	}
}

-(void)tableView:(NSTableView *)table setObjectValue:(id)object forTableColumn:(NSTableColumn *)column row:(int)row
{
	NSString *ident=[column identifier];

	if([ident isEqual:@"enabled"])
	{
		NSString *type=[[filetypes objectAtIndex:row] objectForKey:@"type"];

		if([object boolValue]) [self claimType:type];
		else [self surrenderType:type];
	}
	else if([ident isEqual:@"browse"])
	{
		NSString *type=[[filetypes objectAtIndex:row] objectForKey:@"type"];
		NSString *key=[NSString stringWithFormat:@"disableBrowsing.%@",type];
		[[NSUserDefaults standardUserDefaults] setBool:![object boolValue] forKey:key];
	}
}

-(void)claimAllTypesExceptAlternate
{
	NSEnumerator *enumerator=[filetypes objectEnumerator];
	NSDictionary *type;
	while((type=[enumerator nextObject]))
	{
		if([[type objectForKey:@"alternate"] boolValue]) [self surrenderType:[type objectForKey:@"type"]];
		else [self claimType:[type objectForKey:@"type"]];
	}
}

-(void)surrenderAllTypes
{
	NSEnumerator *enumerator=[filetypes objectEnumerator];
	NSDictionary *type;
	while((type=[enumerator nextObject])) [self surrenderType:[type objectForKey:@"type"]];
}

-(void)claimType:(NSString *)type
{
	NSString *self_id=[[NSBundle mainBundle] bundleIdentifier];
	NSString *oldhandler=[(id)LSCopyDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer) autorelease];

	if(oldhandler && [oldhandler caseInsensitiveCompare:self_id]!=0 && ![oldhandler isEqual:@"__dummy__"])
	{
		NSString *key=[@"oldHandler." stringByAppendingString:type];
		[[NSUserDefaults standardUserDefaults] setObject:oldhandler forKey:key];
	}

	[self setHandler:self_id forType:type];
}

-(void)surrenderType:(NSString *)type
{
	NSString *self_id=[[NSBundle mainBundle] bundleIdentifier];
	NSString *key=[@"oldHandler." stringByAppendingString:type];
	NSString *oldhandler=[[NSUserDefaults standardUserDefaults] stringForKey:key];

	if(oldhandler && [oldhandler caseInsensitiveCompare:self_id]!=0) [self setHandler:oldhandler forType:type];
	else [self removeHandlerForType:type];
}

-(void)setHandler:(NSString *)handler forType:(NSString *)type
{
	LSSetDefaultRoleHandlerForContentType((CFStringRef)type,kLSRolesViewer,(CFStringRef)handler);
}

-(void)removeHandlerForType:(NSString *)type
{
	NSMutableArray *handlers=[NSMutableArray array];
	NSString *self_id=[[NSBundle mainBundle] bundleIdentifier];

	[handlers addObjectsFromArray:[(id)LSCopyAllRoleHandlersForContentType((CFStringRef)type,kLSRolesViewer) autorelease]];
	[handlers addObjectsFromArray:[(id)LSCopyAllRoleHandlersForContentType((CFStringRef)type,kLSRolesEditor) autorelease]];

	NSString *ext=[(id)UTTypeCopyPreferredTagWithClass((CFStringRef)type,kUTTagClassFilenameExtension) autorelease];
	NSString *filename=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"CSFileTypeList%04x.%@",rand()&0xffff,ext]];

	[[NSFileManager defaultManager] createFileAtPath:filename contents:nil attributes:nil];
	NSArray *apps=[(NSArray *)LSCopyApplicationURLsForURL((CFURLRef)[NSURL fileURLWithPath:filename],kLSRolesAll) autorelease];

	#ifdef IsLegacyVersion
	[[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];
	#else
	[[NSFileManager defaultManager] removeItemAtPath:filename error:NULL];
	#endif

	NSEnumerator *enumerator=[apps objectEnumerator];
	NSURL *url;
	while((url=[enumerator nextObject]))
	{
		NSString *app=[url path];
		NSBundle *bundle=[NSBundle bundleWithPath:app];
		if(!bundle) continue;
		[handlers addObject:[bundle bundleIdentifier]];
	}

	for(;;)
	{
		NSUInteger index=[handlers indexOfObject:self_id];
		if(index==NSNotFound) index=[handlers indexOfObject:[self_id lowercaseString]];
		if(index==NSNotFound) break;
		[handlers removeObjectAtIndex:index];
	}

	if([handlers count]) [self setHandler:[handlers objectAtIndex:0] forType:type];
	else [self setHandler:@"__dummy__" forType:type];
}

@end
