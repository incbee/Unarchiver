#import <Cocoa/Cocoa.h>
#import <XADMaster/XADArchive.h>

#import "TUTaskQueue.h"
#import "TUArchiveController.h"
#import "TUArchiveTaskView.h"
#import "TUTaskListView.h"
#import "TUEncodingPopUp.h"

@interface TUController:NSObject
{
	TUTaskQueue *setuptasks,*extracttasks;
	NSMutableDictionary *queuedfileviews;

	NSString *currfilename;
	TUArchiveTaskView *currtaskview;

	NSString *selecteddestination;

	BOOL opened;

	IBOutlet NSWindow *mainwindow;
	IBOutlet TUTaskListView *mainlist;
	IBOutlet TUEncodingPopUp *encodingpopup;

	IBOutlet NSWindow *prefswindow;
	IBOutlet NSTabView *prefstabs;
	IBOutlet NSTabViewItem *formattab;
	IBOutlet NSPopUpButton *destinationpopup;
	IBOutlet NSMenuItem *diritem;

	IBOutlet NSButton *singlefilecheckbox;

//	NSMutableDictionary *filesyslocks;
//	NSLock *metalock;
}

-(id)init;
-(void)dealloc;
-(void)awakeFromNib;

-(void)cleanupOrphanedTempDirectories;

-(NSWindow *)window;

-(void)applicationDidFinishLaunching:(NSNotification *)notification;
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app;
-(BOOL)application:(NSApplication *)app openFile:(NSString *)filename;

-(void)newArchivesForFiles:(NSArray *)filenames destination:(int)desttype;
-(void)newArchiveForFile:(NSString *)filename destination:(int)desttype;
-(void)archiveTaskViewCancelledBeforeSetup:(TUArchiveTaskView *)taskview;

-(void)setupExtractionOfFile:(NSString *)filename to:(NSString *)destination taskView:(TUArchiveTaskView *)taskview;
-(void)tryDestination:(NSString *)destination;
-(void)archiveDestinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)info;
-(void)archiveTaskView:(TUArchiveTaskView *)taskview notWritableResponse:(int)response;
-(void)archiveTaskViewCancelledBeforeExtract:(TUArchiveTaskView *)taskview;

-(void)startExtractionOfFile:(NSString *)filename to:(NSString *)destination taskView:(TUArchiveTaskView *)taskview;
-(void)archiveControllerFinished:(TUArchiveController *)archive;

-(void)listResized:(id)sender;

-(void)updateDestinationPopup;
-(IBAction)changeDestination:(id)sender;
-(void)destinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)context;

-(void)unarchiveToCurrentFolderWithPasteboard:(NSPasteboard *)pboard
userData:(NSString *)data error:(NSString **)error;
-(void)unarchiveToDesktopWithPasteboard:(NSPasteboard *)pboard
userData:(NSString *)data error:(NSString **)error;
-(void)unarchiveToWithPasteboard:(NSPasteboard *)pboard
userData:(NSString *)data error:(NSString **)error;

-(IBAction)unarchiveToCurrentFolder:(id)sender;
-(IBAction)unarchiveToDesktop:(id)sender;
-(IBAction)unarchiveTo:(id)sender;
-(void)selectAndUnarchiveFilesWithDestination:(int)desttype;

-(IBAction)changeCreateFolder:(id)sender;


/*-(void)lockFileSystem:(NSString *)filename;
-(BOOL)tryFileSystemLock:(NSString *)filename;
-(void)unlockFileSystem:(NSString *)filename;
-(NSNumber *)_fileSystemNumber:(NSString *)filename;*/


@end
