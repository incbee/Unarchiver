#import "TUController.h"
#import "TUArchiveController.h"
#import "TUTaskListView.h"
#import "TUEncodingPopUp.h"

#import <unistd.h>
#import <sys/stat.h>
#import <Carbon/Carbon.h>


#define CurrentFolderDestination 1
#define DesktopDestination 2
#define SelectedDestination 3

static BOOL IsPathWritable(NSString *path);



@implementation TUController

-(id)init
{
	if(self=[super init])
	{
		setuptasks=[TUTaskQueue new];
		extracttasks=[TUTaskQueue new];
		queuedfiles=[NSMutableSet new];
		selecteddestination=nil;
		opened=NO;

		[setuptasks setFinishAction:@selector(setupQueueEmpty:) target:self];
		[extracttasks setFinishAction:@selector(extractQueueEmpty:) target:self];
	}
	return self;
}

-(void)dealloc
{
	[setuptasks release];
	[extracttasks release];
	[queuedfiles release];
	[selecteddestination release];
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
	[NSApp setServicesProvider:self];
	[self performSelector:@selector(delayedAfterLaunch) withObject:nil afterDelay:0.3];
}

-(void)delayedAfterLaunch
{
	// This is an ugly kludge because we can't tell if we're launched
	// because of a service call.
	if(!opened)
	{
		ProcessSerialNumber psn={0,kCurrentProcess};
		OSStatus res=TransformProcessType(&psn,kProcessTransformToForegroundApplication);
		if(res!=0)
		{
			[NSApp activateIgnoringOtherApps:YES];
		}
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

	int desttype;
	if(GetCurrentKeyModifiers()&(optionKey|shiftKey)) desttype=SelectedDestination;
	else desttype=[[NSUserDefaults standardUserDefaults] integerForKey:@"extractionDestination"];

	[self newArchiveForFile:filename destination:desttype];
	return YES;
}



-(void)newArchivesForFiles:(NSArray *)filenames destination:(int)desttype
{
	NSEnumerator *enumerator=[filenames objectEnumerator];
	NSString *filename;
	while(filename=[enumerator nextObject]) [self newArchiveForFile:filename destination:desttype];
}

-(void)newArchiveForFile:(NSString *)filename destination:(int)desttype
{
	if([queuedfiles containsObject:filename]) return;

	NSString *destination;
	switch(desttype)
	{
		default:
		case CurrentFolderDestination:
			destination=[filename stringByDeletingLastPathComponent];
		break;

		case DesktopDestination:
			destination=[[NSUserDefaults standardUserDefaults] stringForKey:@"extractionDestinationPath"];
		break;

		case SelectedDestination:
			destination=nil;
		break;
	}

	TUArchiveTaskView *taskview=[[TUArchiveTaskView alloc] initWithFilename:filename];
	[taskview setupWaitView];
	[taskview setCancelAction:@selector(archiveTaskViewCancelledBeforeSetup:) target:self];
	[mainlist addTaskView:taskview];
	[taskview release];

	[queuedfiles addObject:filename];

	[NSApp activateIgnoringOtherApps:YES];
	[mainwindow makeKeyAndOrderFront:nil];

	[[setuptasks taskWithTarget:self] setupExtractionOfFile:filename to:destination taskView:taskview];
}



-(void)archiveTaskViewCancelledBeforeSetup:(TUArchiveTaskView *)taskview
{
	[mainlist removeTaskView:taskview];
}

-(void)setupExtractionOfFile:(NSString *)filename to:(NSString *)destination taskView:(TUArchiveTaskView *)taskview
{
	if(![mainlist containsTaskView:taskview]) // This archive has been cancelled
	{
		[queuedfiles removeObject:filename];
		[setuptasks finishCurrentTask];
		return;
	}

	currfilename=[filename retain];
	currtaskview=taskview;

	[taskview setCancelAction:NULL target:nil];

	if(!destination) destination=selecteddestination;
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

		[[extracttasks taskWithTarget:self] startExtractionOfFile:currfilename
		to:destination taskView:currtaskview];
		[currfilename release];
		currfilename=nil;

		[setuptasks finishCurrentTask];
	}
}

-(void)archiveDestinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)info
{
	if(res==NSOKButton)
	{
		[selecteddestination release];
		selecteddestination=[[panel directory] retain];
		[self tryDestination:selecteddestination];
	}
	else // cancel
	{
		[mainlist removeTaskView:currtaskview];
		[queuedfiles removeObject:currfilename];
		[setuptasks finishCurrentTask];
		[currfilename release];
		currfilename=nil;
	}
}

-(void)archiveTaskView:(TUArchiveTaskView *)taskview notWritableResponse:(int)response
{
	if(taskview!=currtaskview) NSLog(@"Sanity check failure");

	switch(response)
	{
		case 0: // cancel
			[mainlist removeTaskView:taskview];
			[queuedfiles removeObject:currfilename];
			[setuptasks finishCurrentTask];
			[currfilename release];
			currfilename=nil;
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

-(void)setupQueueEmpty:(TUTaskQueue *)queue
{
	if([extracttasks isEmpty]) [mainwindow orderOut:nil];

	[selecteddestination release];
	selecteddestination=nil;
}




-(void)archiveTaskViewCancelledBeforeExtract:(TUArchiveTaskView *)taskview
{
	[mainlist removeTaskView:taskview];
}

-(void)startExtractionOfFile:(NSString *)filename to:(NSString *)destination taskView:(TUArchiveTaskView *)taskview
{
	if(![mainlist containsTaskView:taskview]) // This archive has been cancelled
	{
		[queuedfiles removeObject:filename];
		[extracttasks finishCurrentTask];
		return;
	}

	[taskview setupProgressViewInPreparingMode];

	TUArchiveController *archive=[[[TUArchiveController alloc]
	initWithFilename:filename destination:destination taskView:taskview] autorelease];

	[archive runWithFinishAction:@selector(archiveControllerFinished:) target:self];
}

-(void)archiveControllerFinished:(TUArchiveController *)archive
{
	[mainlist removeTaskView:[archive taskView]];
	[queuedfiles removeObject:[archive filename]];
	[extracttasks finishCurrentTask];
}

-(void)extractQueueEmpty:(TUTaskQueue *)queue
{
	[mainwindow orderOut:nil];
	[TUArchiveController clearGlobalPassword];
}



-(void)listResized:(id)sender
{
	NSSize size=[mainlist preferredSize];
	if(size.height==0) return;

	NSRect frame=[mainwindow contentRectForFrameRect:[mainwindow frame]];
	NSRect newframe=[mainwindow frameRectForContentRect:
		NSMakeRect(frame.origin.x,frame.origin.y+frame.size.height-size.height,
		size.width,size.height)];

	[mainwindow setFrame:newframe display:YES animate:NO];
	[mainwindow setMinSize:NSMakeSize(250,newframe.size.height)];
	[mainwindow setMaxSize:NSMakeSize(100000,newframe.size.height)];
}



-(void)updateDestinationPopup
{
	NSString *path=[[NSUserDefaults standardUserDefaults] stringForKey:@"extractionDestinationPath"];
	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:path];

	[icon setSize:NSMakeSize(16,16)];

	[diritem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
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



-(void)unarchiveToCurrentFolderWithPasteboard:(NSPasteboard *)pboard
userData:(NSString *)data error:(NSString **)error
{
	opened=YES;
	if([[pboard types] containsObject:NSFilenamesPboardType])
	{
		NSArray *filenames=[pboard propertyListForType:NSFilenamesPboardType];
		[self newArchivesForFiles:filenames destination:CurrentFolderDestination];
	}
}

-(void)unarchiveToDesktopWithPasteboard:(NSPasteboard *)pboard
userData:(NSString *)data error:(NSString **)error
{
	opened=YES;
	if([[pboard types] containsObject:NSFilenamesPboardType])
	{
		NSArray *filenames=[pboard propertyListForType:NSFilenamesPboardType];
		[self newArchivesForFiles:filenames destination:DesktopDestination];
	}
}

-(void)unarchiveToWithPasteboard:(NSPasteboard *)pboard
userData:(NSString *)data error:(NSString **)error
{
	opened=YES;
	if([[pboard types] containsObject:NSFilenamesPboardType])
	{
		NSArray *filenames=[pboard propertyListForType:NSFilenamesPboardType];
		[self newArchivesForFiles:filenames destination:SelectedDestination];
	}
}



-(IBAction)unarchiveToCurrentFolder:(id)sender
{
	[self selectAndUnarchiveFilesWithDestination:CurrentFolderDestination];
}

-(IBAction)unarchiveToDesktop:(id)sender
{
	[self selectAndUnarchiveFilesWithDestination:DesktopDestination];
}

-(IBAction)unarchiveTo:(id)sender
{
	[self selectAndUnarchiveFilesWithDestination:SelectedDestination];
}

-(void)selectAndUnarchiveFilesWithDestination:(int)desttype
{
	NSOpenPanel *panel=[NSOpenPanel openPanel];

	[panel setCanChooseFiles:YES];
	[panel setAllowsMultipleSelection:YES];
	[panel setTitle:NSLocalizedString(@"Select files to unarchive",@"Panel title when choosing archives to extract")];
	[panel setPrompt:NSLocalizedString(@"Unarchive",@"Panel OK button title when choosing archives to extract")];

	int res=[panel runModal];

	if(res==NSOKButton) [self newArchivesForFiles:[panel filenames] destination:desttype];
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
