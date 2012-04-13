#import <Cocoa/Cocoa.h>

int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	NSString *desktop;

	#if MAC_OS_X_VERSION_MIN_REQUIRED>=MAC_OS_X_VERSION_10_4
	NSArray *paths=NSSearchPathForDirectoriesInDomains(NSDesktopDirectory,NSUserDomainMask,YES);
	if([paths count]) desktop=[paths objectAtIndex:0];
	else desktop=[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	#else
	desktop=[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	#endif

	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		@"80",@"autoDetectionThreshold",
		@"0",@"filenameEncoding",
		@"0",@"deleteExtractedArchive",
		@"0",@"openExtractedFolder",
		@"1",@"extractionDestination",
		@"1",@"createFolder",
		@"1",@"folderModifiedDate",
		@"0",@"changeDateOfFiles",
		desktop,@"extractionDestinationPath",
		@"0",@"warnedAboutQuarantine",
	nil]];

	[pool release];

	// Try to increase number of available file descriptors for huge multi-part archives.
	struct rlimit rl;
	int err=getrlimit(RLIMIT_NOFILE,&rl);
	if(err==0)
	{
		//rl.rlim_cur=RLIM_INFINITY;
		rl.rlim_cur=rl.rlim_max;
		setrlimit(RLIMIT_NOFILE,&rl);
	}

	return NSApplicationMain(argc,argv);
}
