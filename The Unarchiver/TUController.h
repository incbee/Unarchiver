#import <Cocoa/Cocoa.h>
#import <XADMaster/XADArchive.h>

#import "TUTaskQueue.h"
#import "TUArchiveController.h"
#import "TUArchiveTaskView.h"
#import "TUTaskListView.h"
#import "TUEncodingPopUp.h"

#ifndef IsLegacyVersion
#import "TUURLCache.h"
#endif

@interface TUController:NSObject
{
	TUTaskQueue *setuptasks,*extracttasks;
	NSMutableArray *archivecontrollers;

	NSString *selecteddestination;

	BOOL opened;

	#ifndef IsLegacyVersion
	TUURLCache *urlcache;
	#endif

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
-(void)newArchivesForURLs:(NSArray *)urls destination:(int)desttype;
-(void)newArchiveForFile:(NSString *)filename destination:(int)desttype;
-(void)archiveTaskViewCancelledBeforeSetup:(TUArchiveTaskView *)taskview;

-(void)setupExtractionForArchiveController:(TUArchiveController *)archive;
-(void)checkDestinationForArchiveController:(TUArchiveController *)archive;
-(void)checkDestinationForArchiveControllerAgain:(TUArchiveController *)archive;
-(void)checkDestinationForArchiveController:(TUArchiveController *)archive secondAttempt:(BOOL)secondattempt;
-(void)archiveDestinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)info;
-(void)archiveTaskView:(TUArchiveTaskView *)taskview notWritableResponse:(int)response;
-(void)prepareArchiveController:(TUArchiveController *)archive;
-(void)finishSetupForArchiveController:(TUArchiveController *)archive;
-(void)cancelSetupForArchiveController:(TUArchiveController *)archive;
-(void)setupQueueEmpty:(TUTaskQueue *)queue;
-(void)archiveTaskViewCancelledBeforeExtract:(TUArchiveTaskView *)taskview;

-(void)startExtractionForArchiveController:(TUArchiveController *)archive;
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

-(IBAction)openSupportBoard:(id)sender;
-(IBAction)openBugReport:(id)sender;
-(IBAction)openHomePage:(id)sender;

-(TUTaskQueue *)extractTasks;
-(TUTaskQueue *)setupTasks;
-(NSMutableArray *)archivecontrollers;

/*-(void)lockFileSystem:(NSString *)filename;
-(BOOL)tryFileSystemLock:(NSString *)filename;
-(void)unlockFileSystem:(NSString *)filename;
-(NSNumber *)_fileSystemNumber:(NSString *)filename;*/


@end
