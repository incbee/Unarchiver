#import <Cocoa/Cocoa.h>
#import <XADMaster/XADArchive.h>

@class TUController,TUEncodingPopUp;

@interface TUArchiveController:NSObject
{
	TUController *maincontroller;
	XADArchive *archive;
	NSString *archivename,*destination,*tmpdest,*defaultname;
	NSView *view;

	NSConditionLock *pauselock;
	int uiresponse;

	BOOL cancelled,firstprogress,ignoreall;

	NSStringEncoding selected_encoding;
	const char *name_bytes;

	IBOutlet NSView *waitview;
	IBOutlet NSTextField *waitfield;
	IBOutlet NSImageView *waiticon;

	IBOutlet NSView *progressview;
	IBOutlet NSTextField *actionfield;
	IBOutlet NSTextField *namefield;
	IBOutlet NSProgressIndicator *progress;
	IBOutlet NSImageView *progressicon;

	IBOutlet NSView *notwritableview;

	IBOutlet NSView *errorview;
	IBOutlet NSTextField *errorfield;
	IBOutlet NSImageView *erroricon;
	IBOutlet NSButton *applyallcheck;

	IBOutlet NSView *openerrorview;
	IBOutlet NSTextField *openerrorfield;
	IBOutlet NSImageView *openerroricon;

	IBOutlet NSView *passwordview;
	IBOutlet NSTextField *passwordfield;
	IBOutlet NSImageView *passwordicon;

	IBOutlet NSView *encodingview;
	IBOutlet TUEncodingPopUp *encodingpopup;
	IBOutlet NSTextField *encodingfield;
	IBOutlet NSImageView *encodingicon;
}

-(id)initWithFilename:(NSString *)filename controller:(TUController *)maincontroller alwaysAsk:(BOOL)ask;
-(void)dealloc;

-(NSString *)destination;
-(void)setDestination:(NSString *)path;

-(void)wait;
-(void)go;
-(void)stop;
-(void)cancel;

-(void)extract;
-(void)extractFinished;
-(void)extractFailed;
-(NSString *)findUniqueDestinationWithDirectory:(NSString *)directory andFilename:(NSString *)filename;

-(BOOL)archiveExtractionShouldStop:(XADArchive *)archive;

-(void)archive:(XADArchive *)msgarchive extractionOfEntryWillStart:(int)n;
-(void)archive:(XADArchive *)msgarchive extractionProgressBytes:(xadSize)bytes of:(xadSize)total;
-(void)progressStart:(NSNumber *)total;
-(void)progressUpdate:(NSNumber *)bytes;

-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n bytes:(const char *)bytes;
-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n;
-(XADAction)archive:(XADArchive *)sender extractionOfEntryDidFail:(int)n error:(XADError)error;
-(XADAction)archive:(XADArchive *)sender extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error;

-(int)displayNotWritableError;
-(XADAction)displayError:(NSString *)error;
-(void)displayOpenError:(NSString *)error;
-(XADAction)displayEncodingSelectorForBytes:(const char *)bytes encoding:(NSStringEncoding)encoding;

-(IBAction)cancelExtraction:(id)sender;
-(IBAction)cancelWait:(id)sender;
-(IBAction)stopAfterNotWritable:(id)sender;
-(IBAction)extractToDesktopAfterNotWritable:(id)sender;
-(IBAction)extractElsewhereAfterNotWritable:(id)sender;
-(IBAction)stopAfterError:(id)sender;
-(IBAction)continueAfterError:(id)sender;
-(IBAction)okAfterOpenError:(id)sender;
-(IBAction)stopAfterPassword:(id)sender;
-(IBAction)continueAfterPassword:(id)sender;
-(IBAction)stopAfterEncoding:(id)sender;
-(IBAction)continueAfterEncoding:(id)sender;
-(IBAction)selectEncoding:(id)sender;

-(void)setupWaitView;
-(void)setupProgressView;
-(void)setupNotWritableView;
-(void)setupErrorView:(NSString *)error;
-(void)setupOpenErrorView:(NSString *)error;
-(void)setupPasswordView;
-(void)setupEncodingView;

-(void)setDisplayedView:(NSView *)dispview;
-(void)getUserAttention;

-(int)waitForResponseFromUI;
-(void)provideResponseFromUI:(int)response;

@end
