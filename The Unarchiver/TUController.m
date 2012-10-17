#import "TUController.h"
#import "TUArchiveController.h"
#import "TUTaskListView.h"
#import "TUEncodingPopUp.h"
#import "XADMaster/XADPlatform.h"

#import <unistd.h>
#import <sys/stat.h>
#import <Carbon/Carbon.h>


#define CurrentFolderDestination 1
#define DesktopDestination 2
#define SelectedDestination 3
#define UnintializedDestination 4

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

		#ifndef IsLegacyVersion
		urlcache=[TUURLCache new];
		#endif

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

	#ifndef IsLegacyVersion
	[urlcache release];
	#endif

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
		#ifdef IsLegacyVersion
		[fm removeFileAtPath:tmpdir handler:nil];
		#else
		[urlcache obtainAccessToPath:tmpdir];
		[fm removeItemAtPath:tmpdir error:nil];
		[urlcache relinquishAccessToPath:tmpdir];
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

	#ifndef IsLegacyVersion
	if([[NSUserDefaults standardUserDefaults] integerForKey:@"extractionDestination"]==UnintializedDestination)
	{
		NSArray *array=[[NSBundle mainBundle] preferredLocalizations];
		if(array && [array count] && [[array objectAtIndex:0] isEqual:@"en"])
		{
			NSAlert *panel=[NSAlert alertWithMessageText:
			NSLocalizedString(@"Where should The Unarchiver extract archives?",@"Title for nagging alert on first startup")
			defaultButton:NSLocalizedString(@"Extract to the same folder",@"Button to extract to the same folder in nagging alert on first startup")
			alternateButton:NSLocalizedString(@"Ask every time",@"Button to ask every time in nagging alert on first startup")
			otherButton:nil
			informativeTextWithFormat:NSLocalizedString(
			@"Would you like The Unarchiver to extract archives to the same folder as the "
			@"archive file, or would you prefer to be asked for a destination folder for "
			@"every individual archive?",
			@"Content of nagging alert on first startup")];

			NSInteger res=[panel runModal];
			if(res==NSOKButton) [[NSUserDefaults standardUserDefaults]
			setInteger:CurrentFolderDestination forKey:@"extractionDestination"];
			else [[NSUserDefaults standardUserDefaults]
			setInteger:SelectedDestination forKey:@"extractionDestination"];
		}
		else
		{
			[[NSUserDefaults standardUserDefaults]
			setInteger:CurrentFolderDestination forKey:@"extractionDestination"];
		}
	}
	#endif
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

	#ifndef IsLegacyVersion
	// Get rid of sandbox junk.
	filename=[filename stringByResolvingSymlinksInPath];
	#endif

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

-(void)newArchivesForURLs:(NSArray *)urls destination:(int)desttype
{
	NSEnumerator *enumerator=[urls objectEnumerator];
	NSURL *url;
	while((url=[enumerator nextObject])) [self newArchiveForFile:[url path] destination:desttype];
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
	TUArchiveTaskView *taskview=[[TUArchiveTaskView new] autorelease];

	TUArchiveController *archive=[[[TUArchiveController alloc]
	initWithFilename:filename taskView:taskview] autorelease];
	[archive setDestination:destination];

	[archivecontrollers addObject:archive];

	[taskview setCancelAction:@selector(archiveTaskViewCancelledBeforeSetup:) target:self];
	[taskview setArchiveController:archive];
	[taskview setupWaitView];
	[mainlist addTaskView:taskview];

	[NSApp activateIgnoringOtherApps:YES];
	[mainwindow makeKeyAndOrderFront:nil];

	[[setuptasks taskWithTarget:self] setupExtractionForArchiveController:archive];
}

-(void)archiveTaskViewCancelledBeforeSetup:(TUArchiveTaskView *)taskview
{
	[mainlist removeTaskView:taskview];
	[[taskview archiveController] setIsCancelled:YES];
}




-(void)setupExtractionForArchiveController:(TUArchiveController *)archive
{
	if([archive isCancelled])
	{
 		[archivecontrollers removeObjectIdenticalTo:archive];
		[setuptasks finishCurrentTask];
		return;
	}

	[[archive taskView] setCancelAction:NULL target:nil];

	if(![archive destination]) [archive setDestination:selecteddestination];

	[self checkDestinationForArchiveController:archive];
}

-(void)checkDestinationForArchiveController:(TUArchiveController *)archive
{
	[self checkDestinationForArchiveController:archive secondAttempt:NO];
}

-(void)checkDestinationForArchiveControllerAgain:(TUArchiveController *)archive
{
	[self checkDestinationForArchiveController:archive secondAttempt:YES];
}

-(void)checkDestinationForArchiveController:(TUArchiveController *)archive secondAttempt:(BOOL)secondattempt
{
	NSString *destination=[archive destination];

	if(!destination)
	{
		// No destination supplied. This means we need to ask the user.
		NSOpenPanel *panel=[NSOpenPanel openPanel];
		[panel setCanCreateDirectories:YES];
		[panel setCanChooseDirectories:YES];
		[panel setCanChooseFiles:NO];
		//[panel setTitle:NSLocalizedString(@"Extract Archive",@"Panel title when choosing an unarchiving destination for an archive")];
		[panel setPrompt:NSLocalizedString(@"Extract",@"Panel OK button title when choosing an unarchiving destination for an archive")];

		#ifdef IsLegacyVersion
		[panel beginSheetForDirectory:nil file:nil modalForWindow:mainwindow
		modalDelegate:self didEndSelector:@selector(archiveDestinationPanelDidEnd:returnCode:contextInfo:)
		contextInfo:archive];
		#else
		[panel beginSheetModalForWindow:mainwindow completionHandler:^(NSInteger result) {
			[self archiveDestinationPanelDidEnd:panel returnCode:result contextInfo:archive];
		}];
		#endif

		return;
	}

	if(!IsPathWritable(destination))
	{
		#ifdef IsLegacyVersion

		// Can not write to the given destination. Show an error.
		[[archive taskView] displayNotWritableErrorWithResponseAction:@selector(archiveTaskView:notWritableResponse:) target:self];
		return;

		#else

		// Can not write to the given destination. See if we have cached
		// a sandboxed URL for this directory, otherwise either open a file
		// panel to get sandbox access to the directory, or show an error
		// if a file panel was already shown.
		[urlcache obtainAccessToPath:destination];
		if(!IsPathWritable(destination))
		{
			if(secondattempt)
			{
				[[archive taskView] displayNotWritableErrorWithResponseAction:@selector(archiveTaskView:notWritableResponse:) target:self];
			}
			else
			{
				NSOpenPanel *panel=[NSOpenPanel openPanel];

				NSTextField *text=[[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,100,100)] autorelease];

				[text setStringValue:NSLocalizedString(
				@"The Unarchiver can not write to this folder. The Mac OS X "
				@"sandbox may be blocking access to it. To ask the sandbox to "
				@"allow The Unarchiver to write to this folder, simply click "
				@"\"Extract\". This permission will be remembered and "
				@"The Unarchiver will not need to ask for it again.",
				@"Informative text in the file panel shown when trying to gain sandbox access")];
				[text setBezeled:NO];
				[text setDrawsBackground:NO];
				[text setEditable:NO];
				[text setSelectable:NO];
				[text setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:[[text cell] controlSize]]]];

				NSSize size=[[text cell] cellSizeForBounds:NSMakeRect(0,0,460,100000)];
				[text setFrame:NSMakeRect(0,0,size.width,size.height)];

				[panel setAccessoryView:text];

				[panel setCanCreateDirectories:YES];
				[panel setCanChooseDirectories:YES];
				[panel setCanChooseFiles:NO];
				[panel setPrompt:NSLocalizedString(@"Extract",@"Panel OK button title when choosing an unarchiving destination for an archive")];
				[panel setDirectoryURL:[NSURL fileURLWithPath:destination]];

				[panel beginSheetModalForWindow:mainwindow completionHandler:^(NSInteger result) {
					[self archiveDestinationPanelDidEnd:panel returnCode:result contextInfo:archive];
				}];
			}
			return;
		}

		#endif
	}

	// Continue the setup process by trying to initialize the unarchiver,
	// and handle getting access from the sandbox to scan for volume files.
	[self prepareArchiveController:archive];
}

-(void)archiveDestinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)info
{
	TUArchiveController *archive=(id)info;

	if(res==NSOKButton)
	{
		[selecteddestination release];

		#ifdef IsLegacyVersion
		selecteddestination=[[panel directory] retain];
		#else
		NSURL *url=[panel URL];
		[urlcache cacheURL:url];
		selecteddestination=[[url path] retain];
		#endif

		[archive setDestination:selecteddestination];
		[self performSelector:@selector(checkDestinationForArchiveControllerAgain:) withObject:archive afterDelay:0];
	}
	else
	{
		[self performSelector:@selector(cancelSetupForArchiveController:) withObject:archive afterDelay:0];
	}
}

-(void)archiveTaskView:(TUArchiveTaskView *)taskview notWritableResponse:(int)response
{
	TUArchiveController *archive=[taskview archiveController];

	switch(response)
	{
		case 0: // Cancel.
			[self cancelSetupForArchiveController:archive];
		break;

		case 1: // To desktop.
		{
			NSString *desktop=[NSSearchPathForDirectoriesInDomains(
			NSDesktopDirectory,NSUserDomainMask,YES) objectAtIndex:0];
			[archive setDestination:desktop];
			[self checkDestinationForArchiveController:archive];
		}
		break;

		case 2: // Elsewhere.
			[archive setDestination:nil];
			[self checkDestinationForArchiveController:archive];
		break;
	}
}

-(void)prepareArchiveController:(TUArchiveController *)archive
{
	#ifdef IsLegacyVersion

	// With no sandbox, this is easy.
	[archive prepare];
	[self finishSetupForArchiveController:archive];

	#else

	// With the sandbox, on the other hand...

	[archive prepare];

	if(![archive volumeScanningFailed])
	{
		// Miraculously, all went well. Finish.
		[self finishSetupForArchiveController:archive];
	}
	else
	{
		// We were denied access to the directory.
		// First attempt to get access using the URL cache.
		NSString *directory=[[archive filename] stringByDeletingLastPathComponent];
		if([urlcache obtainAccessToPath:directory])
		{
			[archive prepare];
			[self finishSetupForArchiveController:archive];
		}
		else
		{
			// No access available in the cache. Nag the user.
			NSOpenPanel *panel=[NSOpenPanel openPanel];

			NSTextField *text=[[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,100,100)] autorelease];

			[text setStringValue:NSLocalizedString(
			@"The Unarchiver needs to search for more parts of this archive, "
			@"but the Mac OS X sandbox is blocking access to the folder. "
			@"To ask the sandbox to allow The Unarchiver to search in "
			@"this folder, simply click \"Search\". This permission will be "
			@"remembered and The Unarchiver will not need to ask for it again.",
			@"Informative text in the file panel shown when trying to gain sandbox access for multi-part archives")];
			[text setBezeled:NO];
			[text setDrawsBackground:NO];
			[text setEditable:NO];
			[text setSelectable:NO];
			[text setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:[[text cell] controlSize]]]];

			NSSize size=[[text cell] cellSizeForBounds:NSMakeRect(0,0,460,100000)];
			[text setFrame:NSMakeRect(0,0,size.width,size.height)];

			[panel setAccessoryView:text];

			[panel setCanCreateDirectories:YES];
			[panel setCanChooseDirectories:YES];
			[panel setCanChooseFiles:NO];
			[panel setPrompt:NSLocalizedString(@"Search",@"Panel OK button title when searching for more archive parts")];
			[panel setDirectoryURL:[NSURL fileURLWithPath:directory]];

			[panel beginSheetModalForWindow:mainwindow completionHandler:^(NSInteger result) {
				if(result==NSFileHandlingPanelOKButton)
				{
					NSURL *url=[panel URL];
					[urlcache cacheURL:url];
					[archive prepare];
					[self performSelector:@selector(finishSetupForArchiveController:) withObject:archive afterDelay:0];
				}
				else
				{
					[self performSelector:@selector(cancelSetupForArchiveController:) withObject:archive afterDelay:0];
				}
			}];
		}
	}

	#endif
}

-(void)finishSetupForArchiveController:(TUArchiveController *)archive
{
	// All done. Go ahead and start an extraction task.
	[[archive taskView] updateWaitView];
	[[archive taskView] setCancelAction:@selector(archiveTaskViewCancelledBeforeExtract:) target:self];

	[[extracttasks taskWithTarget:self] startExtractionForArchiveController:archive];

	[setuptasks finishCurrentTask];
}

-(void)cancelSetupForArchiveController:(TUArchiveController *)archive
{
	[mainlist removeTaskView:[archive taskView]];
	[archivecontrollers removeObjectIdenticalTo:archive];
	[setuptasks finishCurrentTask];
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

	// Don't bother relinquishing access. Docs says to do it,
	// but this only causes problems.
//	#ifndef IsLegacyVersion
//	[urlcache relinquishAccessToPath:[archive destination]];
//	#endif
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

		#ifdef IsLegacyVersion
		[panel beginSheetForDirectory:oldpath file:@"" types:nil
		modalForWindow:prefswindow modalDelegate:self
		didEndSelector:@selector(destinationPanelDidEnd:returnCode:contextInfo:)
		contextInfo:nil];
		#else
		[panel setDirectoryURL:[NSURL fileURLWithPath:oldpath]];
		[panel setAllowedFileTypes:nil];
		[panel beginSheetModalForWindow:prefswindow completionHandler:^(NSInteger result) {
			[self destinationPanelDidEnd:panel returnCode:result contextInfo:nil];
		}];
		#endif
	}
}

-(void)destinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)context
{
	if(res==NSOKButton)
	{
		#ifdef IsLegacyVersion
		NSString *directory=[panel directory];
		#else
		NSURL *url=[panel URL];
		[urlcache cacheURL:url];
		NSString *directory=[url path];
		#endif

		[[NSUserDefaults standardUserDefaults] setObject:directory forKey:@"extractionDestinationPath"];
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

	if(res==NSOKButton)
	{
		#ifdef IsLegacyVersion
		[self newArchivesForFiles:[panel filenames] destination:desttype];
		#else
		[self newArchivesForURLs:[panel URLs] destination:desttype];
		#endif
	}
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
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://unarchiver.c3.cx/"]];
}

-(TUTaskQueue *)extractTasks
{
	return extracttasks;
}

-(TUTaskQueue *)setupTasks
{
	return setuptasks;
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
