#import <UniversalDetector/UniversalDetector.h>
#import "TUController.h"
#import "TUArchiveController.h"
#import "TUListView.h"
#import "TUEncodingPopUp.h"

#import <sys/stat.h>
#import <Carbon/Carbon.h>



@implementation TUController

-(id)init
{
	if(self=[super init])
	{
		archives=[[NSMutableArray array] retain];
		guilock=[[NSConditionLock alloc] initWithCondition:0];

		resizeblocked=NO;
		opened=NO;
	}
	return self;
}

-(void)dealloc
{
	[archives release];
	[guilock release];
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
}

-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
	if(!opened)
	{
		[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
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
	BOOL ask=NO;
	if(GetCurrentKeyModifiers()&(optionKey|shiftKey)) ask=YES;

	TUArchiveController *archive=[[TUArchiveController alloc] initWithFilename:filename controller:self alwaysAsk:ask];
	if(!archive) return; // big trouble

	[archives addObject:archive];
	[archive release];

	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	[mainwindow makeKeyAndOrderFront:nil];

	if([archives count]==1) [archive go];
	else [archive wait];
}

-(void)archiveFinished:(TUArchiveController *)archive
{
	resizeblocked=YES;
	[archive stop];
	resizeblocked=NO;
	[archives removeObject:archive];

	if([archives count])
	{
		TUArchiveController *nextarchive=[archives objectAtIndex:0];
		[nextarchive go];
	}
}

-(void)archiveCancelled:(TUArchiveController *)archive
{
	[archive stop];
	[archives removeObject:archive];
}



-(TUListView *)listView { return mainlist; }

-(NSWindow *)window { return mainwindow; }



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



-(void)runDestinationPanelForAllArchives
{
	[self performSelectorOnMainThread:@selector(_mainThreadRunDestinationPanel) withObject:nil waitUntilDone:NO];

	[guilock lockWhenCondition:1];
	[guilock unlockWithCondition:0];

	NSEnumerator *enumerator=[archives objectEnumerator];
	TUArchiveController *archive;
	while(archive=[enumerator nextObject])
	{
		if(![archive destination])
		{
			if(newdestination) [archive setDestination:newdestination];
			else [archive cancel];
		}
	}
}

-(void)runDestinationPanelForArchive:(TUArchiveController *)archive
{
	[self performSelectorOnMainThread:@selector(_mainThreadRunDestinationPanel) withObject:nil waitUntilDone:NO];

	[guilock lockWhenCondition:1];
	[guilock unlockWithCondition:0];

	if(newdestination) [archive setDestination:newdestination];
	else [archive cancel];
}

-(void)_mainThreadRunDestinationPanel
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

-(void)archiveDestinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)info
{
	if(res==NSOKButton) newdestination=[[panel directory] retain];
	else newdestination=nil;

	[guilock lockWhenCondition:0];
	[guilock unlockWithCondition:1];
}

@end


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