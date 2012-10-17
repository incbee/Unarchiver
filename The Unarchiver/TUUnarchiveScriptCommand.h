#import "TUController.h"

@interface TUUnarchiveScriptCommand : NSScriptCommand
{
	NSDictionary *oldDefaults;
	NSTimer *restoringTimer;
	TUController * appController; //Needed for calling the unarchaving methods
}

@property BOOL deleteOriginals;
@property BOOL openFolders; //currently not used
@property BOOL waitUntilFinished;
@property NSInteger creatingFolder;
@property (assign) NSString * extractDestination;

-(BOOL)evalBooleanParameterForKey:(NSString *)parameterKey;
-(id)errorFileDontExist:(NSString *)file;
-(void)saveDefaults;
-(void)modifyDefaults;
-(void)restoreDefaults;
@end
