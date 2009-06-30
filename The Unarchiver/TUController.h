#import <Cocoa/Cocoa.h>
#import <XADMaster/XADArchive.h>

@class TUArchiveController,TUListView,TUEncodingPopUp;

@interface TUController:NSObject
{
//	NSMutableDictionary *filesyslocks;
//	NSLock *metalock;
	NSMutableArray *archives;
	BOOL resizeblocked,opened;

	NSConditionLock *guilock;
	NSString *newdestination;

	IBOutlet NSWindow *mainwindow;
	IBOutlet TUListView *mainlist;
	IBOutlet TUEncodingPopUp *encodingpopup;

	IBOutlet NSWindow *prefswindow;
	IBOutlet NSTabView *prefstabs;
	IBOutlet NSTabViewItem *formattab;
	IBOutlet NSPopUpButton *destinationpopup;
	IBOutlet NSMenuItem *diritem;
}

-(BOOL)application:(NSApplication *)app openFile:(NSString *)filename;

-(void)newArchiveForFile:(NSString *)filename;
-(void)archiveFinished:(TUArchiveController *)archive;
-(void)archiveCancelled:(TUArchiveController *)archive;

-(TUListView *)listView;
-(NSWindow *)window;

-(void)listResized:(id)sender;

-(void)updateDestinationPopup;
-(IBAction)changeDestination:(id)sender;
-(void)destinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)context;

-(void)runDestinationPanelForAllArchives;
-(void)runDestinationPanelForArchive:(TUArchiveController *)archive;
-(void)archiveDestinationPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)res contextInfo:(void  *)info;

/*-(void)lockFileSystem:(NSString *)filename;
-(BOOL)tryFileSystemLock:(NSString *)filename;
-(void)unlockFileSystem:(NSString *)filename;
-(NSNumber *)_fileSystemNumber:(NSString *)filename;*/


@end
