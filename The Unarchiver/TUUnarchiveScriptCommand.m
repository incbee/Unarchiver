#import "TUUnarchiveScriptCommand.h"

#define UseURLs
#define DEBUG

#define deleteKeyMacro @"deleteExtractedArchive"
#define openFolder @"openExtractedArchive"

//User defaults keys:

/*
 Keys -> type
 //importants:
 @"deleteExtractedArchive"
 @"openExtractedArchive"
 @"extractionDestinationPath" string
 
 @"createFolder" integer:
	1 : only …
	2 : always
	3 : never
 @"extractionDestination" integer
 @"changeDateOfFiles"
 */

#define UDKdelete  @"deleteExtractedArchive"
#define UDKopen  @"openExtractedFolder"
#define UDKdestination @"extractionDestination"
#define UDKdestinationPath @"extractionDestinationPath"
#define UDKcreateFolderMode @"createFolder"

//keys for the parameters of the command
#define PKdestination @"destination"
#define PKdeleting  @"deletingOriginal"
#define PKopening @"opening"
#define PKcreatingFolder @"creatingFolder"
#define PKwaitUntilFinished @"waitUntilFinished"

//Enum for the AppleScript enumerarion "File Destination"
enum destinationFolder {
	destinationFolderDesktop = 'Desk',
	destinationFolderAskUser = 'AskU',
	destinationFolderOriginal = 'Orig',
	destinationFolderUserDefault = 'UDef'
	};

//Enum for the AppleScript enumerarion "Create new folder"
enum creatingFolderEnum {
	creatingFolderNever = 'NevE',
	creatingFolderOnly = 'OnlY',
	creatingFolderAlways = 'AlwA'
	};

enum creatingFolderUD {
	creatingFolderUDOnly = 1,
	creatingFolderUDAlways = 2,
	creatingFolderUDNever = 3
	};

enum extracionDestination {
	extractionDestinationCurrentFolderDestination = 1,
	extractionDestinationDesktopDestination = 2, //selected by user at pref panel, maybe other than ~/Desktop
	extractionDestinationSelectedDestination = 3,
	extractionDestinationUnintializedDestination = 4,
	};

@implementation TUUnarchiveScriptCommand

@synthesize openFolders, deleteOriginals, creatingFolder, extractDestination, waitUntilFinished;

#pragma mark Overriding methods:
-(id)initWithCommandDescription:(NSScriptCommandDescription *)commandDef
{
	self=[super initWithCommandDescription:commandDef];
	self.extractDestination = [[NSUserDefaults standardUserDefaults] stringForKey:UDKdestinationPath];
	appController = [NSApplication sharedApplication].delegate;
	return self;
}

-(id)performDefaultImplementation
{
	/*
	 The commands will be something like:
	 unarchive listOfArchiver(orPaths?) [to destination] [deleting yes] [opening yes]
	 */
#ifdef DEBUG
	NSLog(@"Running default implementation of command \"unarchive\"");
#endif
	
	//Get the files to unarchive (an array) and the arguments
	NSArray *files=[self directParameter];
	NSDictionary *evaluatedArgs = [self evaluatedArguments];

	//We check that all the files exists
	NSFileManager *fileManager=[NSFileManager defaultManager];
	for (NSString *file in files) {
		if (![fileManager fileExistsAtPath:file])
		{
			return [self errorFileDontExist:file];
		}
	}
	
	//Check and evaluate the parameter "destination"
	id destination=[evaluatedArgs objectForKey:PKdestination];
	int destinationIntValue;
	if (destination)
	{
		if ([destination isKindOfClass:[NSString class]] && [fileManager fileExistsAtPath:destination])
		{
			self.extractDestination = destination;
			destinationIntValue = extractionDestinationDesktopDestination;
		}
		else
		{
			unsigned long destinationLongValue=[destination unsignedLongValue];
			switch (destinationLongValue)
			{
				case destinationFolderDesktop:
					destinationIntValue = extractionDestinationDesktopDestination;
					self.extractDestination = [@"~/Desktop" stringByExpandingTildeInPath];
					break;
				case destinationFolderOriginal:
					destinationIntValue = extractionDestinationCurrentFolderDestination;
					break;
				case destinationFolderAskUser:
					destinationIntValue = extractionDestinationSelectedDestination;
					break;
				case destinationFolderUserDefault:
					destinationIntValue = extractionDestinationDesktopDestination;
					break;
				default:
					//If there is no parameter we use the user defaults
					destinationIntValue = [[NSUserDefaults standardUserDefaults] integerForKey:UDKdestination];
					break;
			}
		}
	}
	
	//Get the rest of optional parameters
	self.deleteOriginals = [self evalBooleanParameterForKey:PKdeleting];
	self.openFolders = [self evalBooleanParameterForKey:PKopening];
	self.waitUntilFinished =[self evalBooleanParameterForKey:PKwaitUntilFinished];
	
	unsigned long creatingFolderValue  = [[evaluatedArgs objectForKey:PKcreatingFolder] unsignedLongValue];
	switch (creatingFolderValue) {
		case creatingFolderNever:
			self.creatingFolder = creatingFolderUDNever;
			break;
		case creatingFolderOnly:
			self.creatingFolder = creatingFolderUDOnly;
			break;
		case creatingFolderAlways:
			self.creatingFolder = creatingFolderUDAlways;
			break;
		default:
			self.creatingFolder = [[NSUserDefaults standardUserDefaults] integerForKey:UDKcreateFolderMode];
			break;
	}
	

	[self saveDefaults];[self modifyDefaults];
	
	
#ifdef UseURLs
	//transform string to URLs
	NSMutableArray *URLarray =[NSMutableArray array];
	for (int i=0; i<[files count]; i++) {
		NSURL *newURL = [NSURL URLWithString:[files objectAtIndex:i]];
		[URLarray addObject:newURL];
	}
	[appController newArchivesForURLs:URLarray destination:destinationIntValue];
#else
	[appController newArchivesForFiles:files destination:destinationIntValue];
#endif
	
	restoringTimer=[[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.5] interval:0.5 target:self selector:@selector(restoreDefaults) userInfo:nil repeats:YES];
	NSRunLoop *mainLoop =[NSRunLoop currentRunLoop];
	[mainLoop addTimer:restoringTimer forMode:NSDefaultRunLoopMode];
	if (self.waitUntilFinished) [self suspendExecution];
	return nil;
}

#pragma mark Custom methods

-(BOOL)evalBooleanParameterForKey:(NSString *)parameterKey
{
	NSDictionary *evaluatedArgs = [self evaluatedArguments];
	id parameter = [evaluatedArgs objectForKey:parameterKey];
	if (! parameter) {
		if ([parameterKey isEqualToString:PKdeleting]) {
			return [[NSUserDefaults standardUserDefaults] boolForKey:UDKdelete];
		}
		if ([parameterKey isEqualToString:PKopening]) {
			return [[NSUserDefaults standardUserDefaults] boolForKey:UDKopen];
		}
		if ([parameterKey isEqualToString:PKwaitUntilFinished]) {
			return YES;
		}
	}
	return [parameter boolValue];
}

-(id)errorFileDontExist:(NSString *)file
{
	// TODO: choose a correct error number
	[self setScriptErrorNumber:1];
	NSString *errorMessage = [NSString stringWithFormat:@"The file %@ doesn't exist.",file];
	[self setScriptErrorString:errorMessage];
	return nil;

	return nil;
}

// TODO: Don't modify the user defaults
-(void)saveDefaults
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSNumber *oldDelete =[NSNumber numberWithBool: [userDefaults boolForKey: UDKdelete]];
	NSNumber *oldOpen = [NSNumber numberWithBool: [userDefaults boolForKey:UDKopen]];
	NSNumber *oldCreate =[NSNumber numberWithBool: [userDefaults integerForKey:UDKcreateFolderMode]];
	NSString *oldDestinationPath = [userDefaults stringForKey:UDKdestinationPath];
	
	oldDefaults = [NSDictionary dictionaryWithObjectsAndKeys:oldDelete,UDKdelete,oldOpen,UDKopen,oldDestinationPath,UDKdestinationPath,oldCreate,UDKcreateFolderMode, nil];
	[oldDefaults retain];
	
	while (! [userDefaults synchronize]) {}
}

-(void)modifyDefaults
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setBool:self.deleteOriginals forKey:UDKdelete];
	[userDefaults setBool:self.openFolders forKey:UDKopen];
	[userDefaults setObject:self.extractDestination forKey:UDKdestinationPath];
	[userDefaults setInteger:self.creatingFolder forKey:UDKcreateFolderMode];
	while (! [userDefaults synchronize]) {}
}

-(void)restoreDefaults
{
	TUTaskQueue *extractTasks = [appController extractTasks];
	TUTaskQueue *setupTasks = [appController setupTasks];
	if ([extractTasks isRunning] || [setupTasks isRunning]) {
		return;
	}
	
#ifdef DEBUG
	NSLog(@"Restoring DEFAULTS");
#endif
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	BOOL oldDelete = [[oldDefaults objectForKey:UDKdelete] boolValue];
	BOOL oldOpen = [[oldDefaults objectForKey:UDKopen] boolValue];
	NSInteger oldCreate = [[oldDefaults objectForKey:UDKcreateFolderMode] integerValue];
	
	NSString *oldDestinationPath = [oldDefaults objectForKey:UDKdestinationPath];
	if (self.deleteOriginals != oldDelete) [userDefaults setBool: oldDelete forKey:UDKdelete];
	if (self.openFolders != oldOpen) [userDefaults setBool:oldOpen forKey:UDKopen];
	if (self.creatingFolder != oldCreate) [userDefaults setInteger:oldCreate forKey:UDKcreateFolderMode];
	if (! [self.extractDestination isEqualToString:oldDestinationPath]) [userDefaults setObject:oldDestinationPath forKey:UDKdestinationPath];
	[restoringTimer invalidate];
	
	while (! [userDefaults synchronize]) {}
	if (self.waitUntilFinished) [self resumeExecutionWithResult:nil];
}

@end
