#import "TUArchiveController.h"
#import "TUController.h"
#import "TUListView.h"
#import "TUEncodingPopUp.h"
#import <XADMaster/XADRegex.h>



static BOOL IsPathWritable(NSString *path);
static BOOL GetCatalogInfoForFilename(NSString *filename,FSCatalogInfoBitmap bitmap,FSCatalogInfo *info);
static BOOL SetCatalogInfoForFilename(NSString *filename,FSCatalogInfoBitmap bitmap,FSCatalogInfo *info);



@implementation TUArchiveController

-(id)initWithFilename:(NSString *)filename controller:(TUController *)controller alwaysAsk:(BOOL)ask
{
	if(self=[super init])
	{
		view=nil;
		cancelled=NO;
		ignoreall=NO;
		selected_encoding=0;

		waitview=nil;
		progressview=nil;
		errorview=nil;
		openerrorview=nil;
		passwordview=nil;
		encodingview=nil;

		archivename=[filename retain];
		maincontroller=controller;

		int desttype;
		if(ask) desttype=3;
		else desttype=[[NSUserDefaults standardUserDefaults] integerForKey:@"extractionDestination"];

		switch(desttype)
		{
			default:
			case 1:
				destination=[filename stringByDeletingLastPathComponent];
			break;
			case 2:
				destination=[[NSUserDefaults standardUserDefaults] stringForKey:@"extractionDestinationPath"];
			break;
			case 3:
				destination=nil;
			break;
		}
		[destination retain];
		tmpdest=nil;

		if([filename matchedByPattern:@"\\.part[0-9]+\\.rar$" options:REG_ICASE])
		defaultname=[[[[filename lastPathComponent] stringByDeletingPathExtension] stringByDeletingPathExtension] retain];
		else
		defaultname=[[[filename lastPathComponent] stringByDeletingPathExtension] retain];

		pauselock=[[NSConditionLock alloc] initWithCondition:0];
	}
	return self;
}

-(void)dealloc
{
	[archive release];
	[archivename release];
	[destination release];
	[tmpdest release];
	[defaultname release];

	[view release];
	[pauselock release];

	[waitview release];
	[progressview release];
	[errorview release];
	[openerrorview release];
	[passwordview release];
	[encodingview release];

	[super dealloc];
}



-(NSString *)destination { return destination; }

-(void)setDestination:(NSString *)path
{
	[destination autorelease];
	destination=[path retain];
}


-(void)wait
{
	[self setupWaitView];
}

-(void)go
{
	if(cancelled) [maincontroller archiveCancelled:self];
	else
	{
		[self setupProgressView];
		[NSThread detachNewThreadSelector:@selector(extract) toTarget:self withObject:nil];
	}
}

-(void)stop
{
	[[maincontroller listView] removeSubview:view];
}

-(void)cancel
{
	cancelled=YES;
}


-(void)extract
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	@try
	{
		if(!destination)
		{
			[maincontroller runDestinationPanelForAllArchives];
			if(cancelled) @throw @"User cancelled destination panel";
		}

		while(!IsPathWritable(destination))
		{
			switch([self displayNotWritableError])
			{
				case 0: // cancel
					@throw @"User cancelled destination dialog";
				break;

				case 1: // to desktop
					[self setDestination:[NSSearchPathForDirectoriesInDomains(
					NSDesktopDirectory,NSUserDomainMask,YES) objectAtIndex:0]];
				break;

				case 2: // elsewhere
					[maincontroller runDestinationPanelForArchive:self];
					if(cancelled) @throw @"User cancelled destination panel";
				break;
			}
		}

		// TODO: fix tmppath handling on crash.
		NSString *tmpdir=[NSString stringWithFormat:@".tmp%04x%04x%04x",rand()&0xffff,rand()&0xffff,rand()&0xffff];
		tmpdest=[[destination stringByAppendingPathComponent:tmpdir] retain];

		archive=[archive=[XADArchive alloc] initWithFile:archivename delegate:self error:NULL];

		if(!archive)
		{
			[self displayOpenError:[NSString stringWithFormat:
			NSLocalizedString(@"The contents of the file \"%@\" can not be extracted with this program.",@"Error message for files not extractable by The Unarchiver"),
			[archivename lastPathComponent]]];
			@throw @"Failed to open archive";
		}

		[archivename release];
		archivename=[[archive filename] retain];

		//[archive setDelegate:self];

		firstprogress=YES;
		BOOL res=[archive extractTo:tmpdest subArchives:YES];

		if(!res) @throw @"Archive extraction failed or was cancelled";

		[self performSelectorOnMainThread:@selector(extractFinished) withObject:nil waitUntilDone:NO];
	}
	@catch(id e)
	{
		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
	}

	[pool release];
}

-(void)extractFinished
{
	NSFileManager *fm=[NSFileManager defaultManager];
	NSArray *files=[fm directoryContentsAtPath:tmpdest];

	if(files)
	{
		BOOL alwayscreatepref=[[NSUserDefaults standardUserDefaults] integerForKey:@"createFolder"]==2;
		BOOL copydatepref=[[NSUserDefaults standardUserDefaults] integerForKey:@"folderModifiedDate"]==2;
		BOOL changefilespref=[[NSUserDefaults standardUserDefaults] boolForKey:@"changeDateOfFiles"];
		BOOL deletearchivepref=[[NSUserDefaults standardUserDefaults] boolForKey:@"deleteExtractedArchive"];
		BOOL openfolderpref=[[NSUserDefaults standardUserDefaults] boolForKey:@"openExtractedFolder"];

		BOOL singlefile=[files count]==1;

		BOOL makefolder=!singlefile || alwayscreatepref;
		BOOL copydate=(makefolder&&copydatepref)||(!makefolder&&changefilespref&&copydatepref);
		BOOL resetdate=!makefolder&&changefilespref&&!copydatepref;

		NSString *finaldest;

		if(makefolder)
		{
			finaldest=[self findUniqueDestinationWithDirectory:destination andFilename:defaultname];
			[fm movePath:tmpdest toPath:finaldest handler:nil];
		}
		else
		{
			NSString *filename=[files objectAtIndex:0];
			NSString *src=[tmpdest stringByAppendingPathComponent:filename];
			finaldest=[self findUniqueDestinationWithDirectory:destination andFilename:filename];
			[fm movePath:src toPath:finaldest handler:nil];
			[fm removeFileAtPath:tmpdest handler:nil];
		}

		if(copydate)
		{
			FSCatalogInfo archiveinfo,newinfo;

			GetCatalogInfoForFilename(archivename,kFSCatInfoContentMod,&archiveinfo);
			newinfo.contentModDate=archiveinfo.contentModDate;
			SetCatalogInfoForFilename(finaldest,kFSCatInfoContentMod,&newinfo);
		}
		else if(resetdate)
		{
			FSCatalogInfo newinfo;

			UCConvertCFAbsoluteTimeToUTCDateTime(CFAbsoluteTimeGetCurrent(),&newinfo.contentModDate);
			SetCatalogInfoForFilename(finaldest,kFSCatInfoContentMod,&newinfo);
		}

		if(deletearchivepref)
		{
			NSString *directory=[archivename stringByDeletingLastPathComponent];
			NSArray *allpaths=[archive allFilenames];
			NSMutableArray *allfiles=[NSMutableArray arrayWithCapacity:[allpaths count]];
			NSEnumerator *enumerator=[allpaths objectEnumerator];
			NSString *path;
			while(path=[enumerator nextObject])
			{
				if([[path stringByDeletingLastPathComponent] isEqual:directory])
				[allfiles addObject:[path lastPathComponent]];
			}

			[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
			source:directory destination:nil files:allfiles tag:nil];
			//[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/dock/drag to trash.aif"];
		}

		if(openfolderpref)
		{
			BOOL isdir;
			[[NSFileManager defaultManager] fileExistsAtPath:finaldest isDirectory:&isdir];
			if(isdir&&![[NSWorkspace sharedWorkspace] isFilePackageAtPath:finaldest])
			{
				[[NSWorkspace sharedWorkspace] openFile:finaldest];
			}
			else [[NSWorkspace sharedWorkspace] selectFile:finaldest inFileViewerRootedAtPath:@""];
		}
	}

	[maincontroller archiveFinished:self];
}

-(void)extractFailed
{
	NSFileManager *fm=[NSFileManager defaultManager];
	[fm removeFileAtPath:tmpdest handler:nil];

	[maincontroller archiveFinished:self];
}

-(NSString *)findUniqueDestinationWithDirectory:(NSString *)directory andFilename:(NSString *)filename
{
	NSString *basename=[filename stringByDeletingPathExtension];
	NSString *extension=[filename pathExtension];
	if([extension length]) extension=[@"." stringByAppendingString:extension];

	NSString *dest=[directory stringByAppendingPathComponent:filename];
	int n=1;

	while([[NSFileManager defaultManager] fileExistsAtPath:dest])
	{
		dest=[directory stringByAppendingPathComponent:
		[NSString stringWithFormat:@"%@-%d%@",basename,n++,extension]];
	}

	return dest;
}




-(BOOL)archiveExtractionShouldStop:(XADArchive *)sender { return cancelled; }

-(NSStringEncoding)archive:(XADArchive *)archive encodingForData:(NSData *)data guess:(NSStringEncoding)guess confidence:(float)confidence
{
	NSStringEncoding encoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
	int threshold=[[NSUserDefaults standardUserDefaults] integerForKey:@"autoDetectionThreshold"];

	if(encoding) return encoding;
	else if(selected_encoding) return selected_encoding;
	else if(confidence*100<threshold)
	{
		XADAction action=[self displayEncodingSelectorForData:data encoding:guess];
		if(action==XADAbort) cancelled=YES;
		return selected_encoding;
	}
	else return guess;
}

-(void)archiveNeedsPassword:(XADArchive *)sender
{
	[self performSelectorOnMainThread:@selector(setupPasswordView) withObject:nil waitUntilDone:NO];

	if([self waitForResponseFromUI])
	{
		[archive setPassword:[passwordfield stringValue]];
	}
	else
	{
		cancelled=YES;
	}

//	if(cancelled) @throw @"User cancelled after password request";

	[self performSelectorOnMainThread:@selector(setupProgressView) withObject:nil waitUntilDone:NO];
}

-(void)archive:(XADArchive *)sender extractionOfEntryWillStart:(int)n
{
	NSString *name=[sender nameOfEntry:n];
	if(name) [namefield performSelectorOnMainThread:@selector(setStringValue:) withObject:name waitUntilDone:NO];
}

-(void)archive:(XADArchive *)sender extractionProgressBytes:(xadSize)bytes of:(xadSize)total
{
	if(firstprogress)
	{
		[self performSelectorOnMainThread:@selector(progressStart:)
		withObject:[NSNumber numberWithUnsignedLongLong:total] waitUntilDone:NO];
		firstprogress=NO;
	}
	else
	{
		[self performSelectorOnMainThread:@selector(progressUpdate:)
		withObject:[NSNumber numberWithUnsignedLongLong:bytes] waitUntilDone:NO];
	}
}

-(void)progressStart:(NSNumber *)total
{
	[actionfield setStringValue:[NSString stringWithFormat:
	NSLocalizedString(@"Extracting \"%@\"",@"Status text while extracting an archive"),
	[archivename lastPathComponent]]];

	[progress setIndeterminate:NO];
	[progress setDoubleValue:0];
	[progress setMaxValue:[total unsignedLongLongValue]];
}

-(void)progressUpdate:(NSNumber *)bytes
{
	[progress setDoubleValue:[bytes unsignedLongLongValue]];
}



-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n data:(NSData *)data
{
	return [self displayEncodingSelectorForData:data encoding:0];
}

-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n
{
	[self displayOpenError:[NSString stringWithFormat:
		NSLocalizedString(@"Could not write to the destination directory.",@"Error message string when writing is impossible.")]
	];
	return XADAbort;
}

-(XADAction)archive:(XADArchive *)sender extractionOfEntryDidFail:(int)n error:(XADError)error
{
	NSString *errstr=[archive describeError:error];
	return [self displayError:
		[NSString stringWithFormat:
		NSLocalizedString(@"Could not extract the file \"%@\": %@",@"Error message string. The first %@ is the file name, the second the error message"),
		[sender nameOfEntry:n],[[NSBundle mainBundle] localizedStringForKey:errstr value:errstr table:nil]]
	];
}

-(XADAction)archive:(XADArchive *)sender extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error
{
	NSString *errstr=[archive describeError:error];
	return [self displayError:
		[NSString stringWithFormat:
		NSLocalizedString(@"Could not extract the resource fork for the file \"%@\":\n%@",@"Error message for resource forks. The first %@ is the file name, the second the error message"),
		[sender nameOfEntry:n],[[NSBundle mainBundle] localizedStringForKey:errstr value:errstr table:nil]]
	];
}



-(int)displayNotWritableError
{
	[self performSelectorOnMainThread:@selector(setupNotWritableView) withObject:nil waitUntilDone:NO];
	int action=[self waitForResponseFromUI];

	[self performSelectorOnMainThread:@selector(setDisplayedView:) withObject:progressview waitUntilDone:NO];

	return action;
}

-(XADAction)displayError:(NSString *)error
{
	if(ignoreall) return XADSkip;

	[self performSelectorOnMainThread:@selector(setupErrorView:) withObject:error waitUntilDone:NO];
	XADAction action=[self waitForResponseFromUI];

	if(action==XADSkip)
	{
		if([applyallcheck state]==NSOnState) ignoreall=YES;
		else ignoreall=NO;
	}

	[self performSelectorOnMainThread:@selector(setDisplayedView:) withObject:progressview waitUntilDone:NO];

	return action;
}

-(void)displayOpenError:(NSString *)error
{
	[self performSelectorOnMainThread:@selector(setupOpenErrorView:) withObject:error waitUntilDone:NO];
	[self waitForResponseFromUI];
}

-(XADAction)displayEncodingSelectorForData:(NSData *)data encoding:(NSStringEncoding)encoding
{
	selected_encoding=encoding;
	namedata=data;

	[self performSelectorOnMainThread:@selector(setupEncodingView) withObject:nil waitUntilDone:NO];
	XADAction action=[self waitForResponseFromUI];

	selected_encoding=[encodingpopup selectedTag];

	[self performSelectorOnMainThread:@selector(setDisplayedView:) withObject:progressview waitUntilDone:NO];

	return action;
}






-(IBAction)cancelWait:(id)sender
{
	[maincontroller archiveCancelled:self];
	[sender setEnabled:NO];
}

-(IBAction)cancelExtraction:(id)sender
{
	cancelled=YES;
	[sender setEnabled:NO];
}

-(IBAction)stopAfterNotWritable:(id)sender
{
	[self provideResponseFromUI:0];
}

-(IBAction)extractToDesktopAfterNotWritable:(id)sender
{
	[self provideResponseFromUI:1];
}

-(IBAction)extractElsewhereAfterNotWritable:(id)sender
{
	[self provideResponseFromUI:2];
}

-(IBAction)stopAfterError:(id)sender
{
	// KLUDGE: for some reason the button releases itself if sent an Esc keystroke.
	// This will drive up the retain count, but as the button should never be released
	// anyway this shouldn't be a problem.
	//[sender retain];
	[self provideResponseFromUI:XADAbort];
}

-(IBAction)continueAfterError:(id)sender
{
	[self provideResponseFromUI:XADSkip];
}

-(IBAction)okAfterOpenError:(id)sender
{
	[self provideResponseFromUI:0];
}

-(IBAction)stopAfterPassword:(id)sender
{
	// KLUDGE: for some reason the button releases itself if sent an Esc keystroke.
	// This will drive up the retain count, but as the button should never be released
	// anyway this shouldn't be a problem.
	//[sender retain];
	[self provideResponseFromUI:NO];
}

-(IBAction)continueAfterPassword:(id)sender
{
	[self provideResponseFromUI:YES];
}

-(IBAction)stopAfterEncoding:(id)sender
{
	// KLUDGE: for some reason the button releases itself if sent an Esc keystroke.
	// This will drive up the retain count, but as the button should never be released
	// anyway this shouldn't be a problem.
	//[sender retain];
	[self provideResponseFromUI:XADAbort];
}

-(IBAction)continueAfterEncoding:(id)sender
{
	[self provideResponseFromUI:XADRetry];
}

-(IBAction)selectEncoding:(id)sender
{
	NSStringEncoding encoding=[encodingpopup selectedTag];
	NSString *str=[[[NSString alloc] initWithData:namedata encoding:encoding] autorelease];
	[encodingfield setStringValue:str?str:@""];
}



-(void)setupWaitView
{
	if(!waitview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"WaitView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[waitfield setStringValue:[archivename lastPathComponent]];

	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:archivename];
	[icon setSize:[waiticon frame].size];
	[waiticon setImage:icon];

	[self setDisplayedView:waitview];
}

-(void)setupProgressView
{
	if(!progressview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"ProgressView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[actionfield setStringValue:[NSString stringWithFormat:
	NSLocalizedString(@"Preparing to extract \"%@\"",@"Status text when preparing to extract an archive"),
	[archivename lastPathComponent]]];

	[namefield setStringValue:@""];

	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:archivename];
	[icon setSize:[progressicon frame].size];
	[progressicon setImage:icon];

	[progress setIndeterminate:YES];
	[progress startAnimation:self];

	[self setDisplayedView:progressview];
}

-(void)setupNotWritableView
{
	if(!notwritableview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"NotWritableView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[self setDisplayedView:notwritableview];
	[self getUserAttention];
}

-(void)setupErrorView:(NSString *)error
{
	if(!errorview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"ErrorView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[errorfield setStringValue:error];
	[self setDisplayedView:errorview];
	[self getUserAttention];
}

-(void)setupOpenErrorView:(NSString *)error
{
	if(!openerrorview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"OpenErrorView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[openerrorfield setStringValue:error];
	[self setDisplayedView:openerrorview];
	[self getUserAttention];
}

-(void)setupPasswordView
{
	if(!passwordview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"PasswordView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:archivename];
	[icon setSize:[passwordicon frame].size];
	[passwordicon setImage:icon];

	[self setDisplayedView:passwordview];
	[[passwordfield window] makeFirstResponder:passwordfield];
	[self getUserAttention];
}

-(void)setupEncodingView
{
	if(!encodingview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"EncodingView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:archivename];
	[icon setSize:[encodingicon frame].size];
	[encodingicon setImage:icon];

	[encodingpopup buildEncodingListMatchingData:namedata];
	if(selected_encoding)
	{
		int index=[encodingpopup indexOfItemWithTag:selected_encoding];
		if(index>=0) [encodingpopup selectItemAtIndex:index];
		else [encodingpopup selectItemAtIndex:[encodingpopup indexOfItemWithTag:NSISOLatin1StringEncoding]];
	}

	[self selectEncoding:self];

	[self setDisplayedView:encodingview];
	[[passwordfield window] makeFirstResponder:passwordfield];
	[self getUserAttention];
}



-(void)setDisplayedView:(NSView *)dispview
{
	NSRect frame=[dispview frame];
	[dispview setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin];

	if(view)
	{
		NSEnumerator *enumerator=[[view subviews] objectEnumerator];
		NSView *subview;
		while(subview=[enumerator nextObject]) [subview removeFromSuperview];

		NSSize viewsize=[view frame].size;
		NSRect newframe=NSMakeRect(0,viewsize.height-frame.size.height,viewsize.width,frame.size.height);
		[dispview setFrame:newframe];
		[view addSubview:dispview];
		[[maincontroller listView] setHeight:frame.size.height forView:view];
	}
	else
	{
		view=[[NSView alloc] init];
		[view setAutoresizesSubviews:YES];

		NSRect newframe=NSMakeRect(0,0,frame.size.width,frame.size.height);
		[view setFrame:newframe];
		[dispview setFrame:newframe];
		[view addSubview:dispview];

		[[maincontroller listView] addSubview:view];
	}

}

-(void)getUserAttention
{
	[[maincontroller window] makeKeyAndOrderFront:self];
	[NSApp activateIgnoringOtherApps:YES];
}

// Uiiiiii~ Aisuuuuu~
-(int)waitForResponseFromUI
{
	[pauselock lockWhenCondition:1];
	[pauselock unlockWithCondition:0];
	return uiresponse;
}

-(void)provideResponseFromUI:(int)response
{
	uiresponse=response;
	[pauselock lockWhenCondition:0];
	[pauselock unlockWithCondition:1];
}


@end



#include <unistd.h>

static BOOL IsPathWritable(NSString *path)
{
	if(access([path fileSystemRepresentation],W_OK)==-1) return NO;

	return YES;
}

static BOOL GetCatalogInfoForFilename(NSString *filename,FSCatalogInfoBitmap bitmap,FSCatalogInfo *info)
{
	FSRef ref;
	if(FSPathMakeRefWithOptions((const UInt8 *)[filename fileSystemRepresentation],
	kFSPathMakeRefDoNotFollowLeafSymlink,&ref,NULL)!=noErr) return NO;
	if(FSGetCatalogInfo(&ref,bitmap,info,NULL,NULL,NULL)!=noErr) return NO;
	return YES;
}

static BOOL SetCatalogInfoForFilename(NSString *filename,FSCatalogInfoBitmap bitmap,FSCatalogInfo *info)
{
	FSRef ref;
	if(FSPathMakeRefWithOptions((const UInt8 *)[filename fileSystemRepresentation],
	kFSPathMakeRefDoNotFollowLeafSymlink,&ref,NULL)!=noErr) return NO;
	if(FSSetCatalogInfo(&ref,bitmap,info)!=noErr) return NO;
	return YES;
}
