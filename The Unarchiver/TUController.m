#import <UniversalDetector/UniversalDetector.h>
#import "TUController.h"
#import "TUArchiveController.h"
#import "TUTaskListView.h"
#import "TUEncodingPopUp.h"

#import <unistd.h>
#import <sys/stat.h>
#import <Carbon/Carbon.h>



static BOOL IsPathWritable(NSString *path);



@implementation TUController

-(id)init
{
	if(self=[super init])
	{
		setuptasks=[TUTaskQueue new];
		extracttasks=[TUTaskQueue new];
		resizeblocked=NO;
		opened=NO;
	}
	return self;
}

-(void)dealloc
{
	[setuptasks release];
	[extracttasks release];
	[super dealloc];
}

-(void)awakeFromNib
{
	[self updateDestinationPopup];

	[mainlist setResizeAction:@selector(listResized:) target:self];

	if(floor(NSAppKitVersionNumber)<=NSAppKitVersionNumber10_3)
	[prefstabs removeTabViewItem:formattab];

	[encodingpopup buildEncodingListWithAutoDetect];
	NSStringEncoding encoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
//	if(encoding) [encodingpopup selectItemWithTag:encoding];
	if(encoding) [encodingpopup selectItemAtIndex:[encodingpopup indexOfItemWithTag:encoding]];
	else [encodingpopup selectItemAtIndex:[encodingpopup numberOfItems]-1];

	[self changeCreateFolder:nil];

	[self cleanupOrphanedTempDirectories];
}

-(void)cleanupOrphanedTempDirectories
{
	NSUserDefaults *defs=[NSUserDefaults standardUserDefaults];
	NSFileManager *fm=[NSFileManager defaultManager];

	NSArray *tmpdirs=[defs arrayForKey:@"orphanedTempDirectories"];
	NSEnumerator *enumerator=[tmpdirs objectEnumerator];
	NSString *tmpdir;
	while(tmpdir=[enumerator nextObject])
	{
		[fm removeFileAtPath:tmpdir handler:nil];
	}

	[defs setObject:[NSArray array] forKey:@"orphanedTempDirectories"];
	[defs synchronize];
}




-(NSWindow *)window { return mainwindow; }



-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
	if(!opened)
	{
		[NSApp activateIgnoringOtherApps:YES];
		[prefswindow makeKeyAndOrderFront:nil];
	}
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app 
{
	return YES;
}

-(BOOL)application:(NSApplication *)app openFile:(NSString *)filename
{
	opened=YES;
	[self newArchiveForFile:filename];
	return YES;
}



-(void)newArchiveForFile:(NSString *)filename
{
	int desttype;
	if(GetCurrentKeyModifiers()&(optionKey|shiftKey)) desttype=3;
	else desttype=[[NSUserDefaults standardUserDefaults] integerForKey:@"extractionDestination"];

	NSString *destination;
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

	TUArchiveTaskView *taskview=[[TUArchiveTaskView alloc] initWithFilename:filename];
	[taskview setupWaitView];
	[taskview setCancelAction:@selector(archiveTaskViewCancelledBeforeSetup:) target:self];
	[mainlist addTaskView:taskview];
	[taskview release];

	[NSApp activateIgnoringOtherApps:YES];
	[mainwindow makeKeyAndOrderFront:nil];

	[[setuptasks newTaskWithTarget:self] setupExtractionOfFile:filename to:destination taskView:taskview];
}

-(void)archiveTaskViewCancelledBeforeSetup:(TUArchiveTaskView *)taskview
{
	[mainlist removeTaskView:taskview];
}



-(void)setupExtractionOfFile:(NSString *)filename to:(NSString *)destination taskView:(TUArchiveTaskView *)taskview
{
	if(![mainlist containsTaskView:taskview]) // This archive has been cancelled
	{
		[extracttasks finishCurrentTask];
		return;
	}

	currfilename=[filename retain];
	currtaskview=taskview;

	[taskview setCancelAction:NULL target:nil];

	[self tryDestination:destination];
}

-(void)tryDestination:(NSString *)destination
{
	if(!destination)
	{
		NSOpenPanel *panel=[NSOpenPanel openPanel];
		[panel setCanCreateDirectories:YES];
		[panel setCanChooseDirectories:YES];
		[panel setCanChooseFiles:NO];
		//[panel setTitle:NSLocalizedString(@"Extract Archive",@"Panel title when choosing an unarchiving destination for an archive")];
		[panel setPrompt:NSLocalizedString(@"Extract",@"Panel OK button title when choosing an unarchiving destination for an archive")];

		[panel beginSheetForDirectory:nil file:nil modalForWindow:mainwindow
		modalDelegate:self didEndSelector:@selector(archiveDestinationPanelDidEnd:returnCode:contextInfo:)
		contextInfo:NULL];
	}
	else if(!IsPathWritable(destination))
	{
		[currtaskview displayNotWritableErrorWithResponseAction:@selector(archiveTaskView:notWritableResponse:) target:self];
	}
	else // go ahead and start an extraction task
	{
		[currtaskview setCancelAction:@selector(archiveTaskViewCancelledBeforeExtract:) target:self];

		[[extracttasks newTaskWithTarget:self] startExtractionOfFile:currfilename
		to:destination taskView:currtaskview];
		[currfilename release];

		[setuptasks finishCurrentTask];
	}
}

-(void)archiveDestinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)info
{
	if(res==NSOKButton)
	{
		[self tryDestination:[panel directory]];
	}
	else // cancel
	{
		[mainlist removeTaskView:currtaskview];
		[setuptasks finishCurrentTask];
		[currfilename release];
	}
}

-(void)archiveTaskView:(TUArchiveTaskView *)taskview notWritableResponse:(int)response
{
	if(taskview!=currtaskview) NSLog(@"Sanity check failure");

	switch(response)
	{
		case 0: // cancel
			[mainlist removeTaskView:taskview];
			[setuptasks finishCurrentTask];
			[currfilename release];
		break;

		case 1: // to desktop
			[self tryDestination:[NSSearchPathForDirectoriesInDomains(
			NSDesktopDirectory,NSUserDomainMask,YES) objectAtIndex:0]];
		break;

		case 2: // elsewhere
			[self tryDestination:nil];
		break;
	}
}

-(void)archiveTaskViewCancelledBeforeExtract:(TUArchiveTaskView *)taskview
{
	[mainlist removeTaskView:taskview];
}


-(void)startExtractionOfFile:(NSString *)filename to:(NSString *)destination taskView:(TUArchiveTaskView *)taskview
{
	if(![mainlist containsTaskView:taskview]) // This archive has been cancelled
	{
		[extracttasks finishCurrentTask];
		return;
	}

	[taskview setupProgressViewInPreparingMode];

	TUArchiveController *archive=[[TUArchiveController alloc]
	initWithFilename:filename destination:destination taskView:taskview];
	//if(!archive) return; // big trouble TODO: fix this

	[archive runWithFinishAction:@selector(archiveControllerFinished:) target:self];
}

-(void)archiveControllerFinished:(TUArchiveController *)archive
{
	//resizeblocked=YES;
	[mainlist removeTaskView:[archive taskView]];
	//resizeblocked=NO;

	[extracttasks finishCurrentTask];

	if(![extracttasks isRunning]) [TUArchiveController clearGlobalPassword];
}



-(void)listResized:(id)sender
{
	NSSize size=[mainlist preferredSize];

	if(size.height==0)
	{
		[mainwindow orderOut:nil];
	}
	else if(!resizeblocked)
	{
		NSRect frame=[mainwindow contentRectForFrameRect:[mainwindow frame]];
		NSRect newframe=[mainwindow frameRectForContentRect:
			NSMakeRect(frame.origin.x,frame.origin.y+frame.size.height-size.height,
			size.width,size.height)];

		[mainwindow setFrame:newframe display:YES animate:NO];
		[mainwindow setMinSize:NSMakeSize(200,newframe.size.height)];
		[mainwindow setMaxSize:NSMakeSize(100000,newframe.size.height)];

		/*if(![mainwindow isVisible])
		{
			[mainwindow makeKeyAndOrderFront:nil];
		}*/
	}
}



-(void)updateDestinationPopup
{
	NSString *path=[[NSUserDefaults standardUserDefaults] stringForKey:@"extractionDestinationPath"];
	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:path];

	[icon setSize:NSMakeSize(16,16)];

	[diritem setTitle:[path lastPathComponent]];
	[diritem setImage:icon];
}

-(IBAction)changeDestination:(id)sender
{
	if([destinationpopup selectedTag]==1000)
	{
		NSString *oldpath=[[NSUserDefaults standardUserDefaults] stringForKey:@"extractionDestinationPath"];
		NSOpenPanel *panel=[NSOpenPanel openPanel];

		[panel setCanChooseDirectories:YES];
		[panel setCanCreateDirectories:YES];
		[panel setCanChooseFiles:NO];
		[panel setPrompt:NSLocalizedString(@"Select",@"Panel OK button title when choosing a default unarchiving destination")];

		[panel beginSheetForDirectory:oldpath file:@"" types:nil
		modalForWindow:prefswindow modalDelegate:self
		didEndSelector:@selector(destinationPanelDidEnd:returnCode:contextInfo:)
		contextInfo:nil];
	}
}

-(void)destinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)context
{
	if(res==NSOKButton)
	{
		[[NSUserDefaults standardUserDefaults] setObject:[panel directory] forKey:@"extractionDestinationPath"];
		[self updateDestinationPopup];
	}
	[destinationpopup selectItem:diritem];
	[[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"extractionDestination"];
}

-(IBAction)changeCreateFolder:(id)sender
{
	int createfolder=[[NSUserDefaults standardUserDefaults] integerForKey:@"createFolder"];
	[singlefilecheckbox setEnabled:createfolder==1];
}

@end




static BOOL IsPathWritable(NSString *path)
{
	if(access([path fileSystemRepresentation],W_OK)==-1) return NO;

	return YES;
}


/*-(void)lockFileSystem:(NSString *)filename
{
	NSNumber *key=[self _fileSystemNumber:filename];

	[metalock lock];
	if(![filesyslocks objectForKey:key]) [filesyslocks setObject:[[[NSLock alloc] init] autorelease] forKey:key];
	NSLock *lock=[filesyslocks objectForKey:key];
	[metalock unlock];

	[lock lock];
}

-(BOOL)tryFileSystemLock:(NSString *)filename
{
	NSNumber *key=[self _fileSystemNumber:filename];

	[metalock lock];
	if(![filesyslocks objectForKey:key]) [filesyslocks setObject:[[[NSLock alloc] init] autorelease] forKey:key];
	NSLock *lock=[filesyslocks objectForKey:key];
	[metalock unlock];

	return [lock tryLock];
}

-(void)unlockFileSystem:(NSString *)filename
{
	NSNumber *key=[self _fileSystemNumber:filename];

	[metalock lock];
	NSLock *lock=[filesyslocks objectForKey:key];
	[metalock unlock];

	[lock unlock];
}

-(NSNumber *)_fileSystemNumber:(NSString *)filename
{
	struct stat st;
	lstat([filename fileSystemRepresentation],&st);
	return [NSNumber numberWithUnsignedLong:st.st_dev];
}*/
