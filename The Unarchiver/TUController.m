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
	if((self=[super init]))
	{
		setuptasks=[TUTaskQueue new];
		extracttasks=[TUTaskQueue new];
		archivecontrollers=[NSMutableArray new];
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
	[archivecontrollers release];
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
	while((tmpdir=[enumerator nextObject]))
	{
		#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050
		[fm removeItemAtPath:tmpdir error:nil];
		#else
		[fm removeFileAtPath:tmpdir handler:nil];
		#endif
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
	while((filename=[enumerator nextObject])) [self newArchiveForFile:filename destination:desttype];
}

-(void)newArchiveForFile:(NSString *)filename destination:(int)desttype
{
	// Check if this file is already included in any of the currently queued archives.
	NSEnumerator *enumerator=[archivecontrollers objectEnumerator];
	TUArchiveController *currarchive;
	while((currarchive=[enumerator nextObject]))
	{
		if([currarchive isCancelled]) continue;
		NSArray *filenames=[currarchive allFilenames];
		if([filenames containsObject:filename]) return;
	}

	// Pick a destination.
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

	// Create status view and archive controller.
	TUArchiveTaskView *taskview=[[[TUArchiveTaskView alloc] init] autorelease];

	TUArchiveController *archive=[[[TUArchiveController alloc]
	initWithFilename:filename taskView:taskview] autorelease];
	[archivecontrollers addObject:archive];

	[taskview setCancelAction:@selector(archiveTaskViewCancelledBeforeSetup:) target:self];
	[taskview setArchiveController:archive];
	[taskview setupWaitView];
	[mainlist addTaskView:taskview];

	[NSApp activateIgnoringOtherApps:YES];
	[mainwindow makeKeyAndOrderFront:nil];

	[[setuptasks taskWithTarget:self] setupExtractionForArchiveController:archive
	to:destination];
}

-(void)archiveTaskViewCancelledBeforeSetup:(TUArchiveTaskView *)taskview
{
	[mainlist removeTaskView:taskview];
	[[taskview archiveController] setIsCancelled:YES];
}




-(void)setupExtractionForArchiveController:(TUArchiveController *)archive to:(NSString *)destination
{
	if([archive isCancelled])
	{
 		[archivecontrollers removeObjectIdenticalTo:archive];
		[setuptasks finishCurrentTask];
		return;
	}

	[[archive taskView] setCancelAction:NULL target:nil];

	if(!destination) destination=selecteddestination;
	[self tryDestination:destination forArchiveController:archive];
}

-(void)tryDestination:(NSString *)destination forArchiveController:(TUArchiveController *)archive
{
	if(!destination)
	{
		// No destination supplied. This means we need to ask the user.
		NSOpenPanel *panel=[NSOpenPanel openPanel];
		[panel setCanCreateDirectories:YES];
		[panel setCanChooseDirectories:YES];
		[panel setCanChooseFiles:NO];
		//[panel setTitle:NSLocalizedString(@"Extract Archive",@"Panel title when choosing an unarchiving destination for an archive")];
		[panel setPrompt:NSLocalizedString(@"Extract",@"Panel OK button title when choosing an unarchiving destination for an archive")];

		[panel beginSheetForDirectory:nil file:nil modalForWindow:mainwindow
		modalDelegate:self didEndSelector:@selector(archiveDestinationPanelDidEnd:returnCode:contextInfo:)
		contextInfo:archive];
	}
	else if(!IsPathWritable(destination))
	{
		// Can not write to the given destination. Show an error.
		[[archive taskView] displayNotWritableErrorWithResponseAction:@selector(archiveTaskView:notWritableResponse:) target:self];
	}
	else
	{
		// Go ahead and start an extraction task.
		[[archive taskView] setCancelAction:@selector(archiveTaskViewCancelledBeforeExtract:) target:self];

		[archive setDestination:destination];

		[[extracttasks taskWithTarget:self] startExtractionForArchiveController:archive];

		[setuptasks finishCurrentTask];
	}
}

-(void)archiveDestinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)info
{
	TUArchiveController *archive=(id)info;

	if(res==NSOKButton)
	{
		[selecteddestination release];
		selecteddestination=[[panel directory] retain];
		[self tryDestination:selecteddestination forArchiveController:archive];
	}
	else
	{
		[mainlist removeTaskView:[archive taskView]];
		[archivecontrollers removeObjectIdenticalTo:archive];
		[setuptasks finishCurrentTask];
	}
}

-(void)archiveTaskView:(TUArchiveTaskView *)taskview notWritableResponse:(int)response
{
	TUArchiveController *archive=[taskview archiveController];

	switch(response)
	{
		case 0: // Cancel.
			[mainlist removeTaskView:taskview];
			[archivecontrollers removeObjectIdenticalTo:archive];
			[setuptasks finishCurrentTask];
		break;

		case 1: // To desktop.
		{
			NSString *desktop=[NSSearchPathForDirectoriesInDomains(
			NSDesktopDirectory,NSUserDomainMask,YES) objectAtIndex:0];
			[self tryDestination:desktop forArchiveController:archive];
		}
		break;

		case 2: // Elsewhere.
			[self tryDestination:nil forArchiveController:archive];
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
	[[taskview archiveController] setIsCancelled:YES];
}




-(void)startExtractionForArchiveController:(TUArchiveController *)archive
{
	if([archive isCancelled])
	{
		[archivecontrollers removeObjectIdenticalTo:archive];
		[extracttasks finishCurrentTask];
		return;
	}

	[[archive taskView] setupProgressViewInPreparingMode];

	[archive runWithFinishAction:@selector(archiveControllerFinished:) target:self];
}

-(void)archiveControllerFinished:(TUArchiveController *)archive
{
	[mainlist removeTaskView:[archive taskView]];
	[archivecontrollers removeObjectIdenticalTo:archive];
	[extracttasks finishCurrentTask];
}

-(void)extractQueueEmpty:(TUTaskQueue *)queue
{
	if([setuptasks isEmpty]) [mainwindow orderOut:nil];

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

	[mainwindow setMinSize:NSMakeSize(316,newframe.size.height)];
	[mainwindow setMaxSize:NSMakeSize(100000,newframe.size.height)];
	[mainwindow setFrame:newframe display:YES animate:NO];
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




-(IBAction)openSupportBoard:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://wakaba.c3.cx/sup/"]];
}

-(IBAction)openBugReport:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://code.google.com/p/theunarchiver/issues/list"]];
}

-(IBAction)openHomePage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://wakaba.c3.cx/s/apps/unarchiver"]];
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
