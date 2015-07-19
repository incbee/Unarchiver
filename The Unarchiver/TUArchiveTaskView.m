#import "TUArchiveTaskView.h"
#import "TUArchiveController.h"


@implementation TUArchiveTaskView

-(id)init
{
	if((self=[super init]))
	{
		archive=nil;

		waitview=nil;
		progressview=nil;
		errorview=nil;
		openerrorview=nil;
		passwordview=nil;
		encodingview=nil;

		pauselock=[[NSConditionLock alloc] initWithCondition:0];
	}
	return self;
}

-(void)dealloc
{
	[pauselock release];

	[waitview release];
	[progressview release];
	[errorview release];
	[openerrorview release];
	[passwordview release];
	[encodingview release];

	[super dealloc];
}

-(TUArchiveController *)archiveController { return archive; }

-(void)setArchiveController:(TUArchiveController *)archivecontroller { archive=archivecontroller; }




-(void)setCancelAction:(SEL)selector target:(id)target
{
	canceltarget=target;
	cancelselector=selector;
}



-(void)setName:(NSString *)name
{
	[namefield performSelectorOnMainThread:@selector(setStringValue:) withObject:name waitUntilDone:NO];
}

-(void)setProgress:(double)fraction
{
	[self performSelectorOnMainThread:@selector(_setProgress:)
	withObject:[NSNumber numberWithDouble:fraction] waitUntilDone:NO];
}

-(void)_setProgress:(NSNumber *)fraction
{
	if([progressindicator isIndeterminate])
	{
		[actionfield setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"Extracting \"%@\"",@"Status text while extracting an archive"),
		[[archive filename] lastPathComponent]]];
		[progressindicator setDoubleValue:0];
		[progressindicator setMaxValue:1];
		[progressindicator setIndeterminate:NO];
		// TODO: Update dock
	}

	[progressindicator setDoubleValue:[fraction doubleValue]];
	// TODO: Update dock
}




-(void)displayNotWritableErrorWithResponseAction:(SEL)selector target:(id)target
{
	[self performSelectorOnMainThread:@selector(setupNotWritableView) withObject:nil waitUntilDone:NO];
	[self setUIResponseAction:selector target:target];
}

-(BOOL)displayError:(NSString *)error ignoreAll:(BOOL *)ignoreall
{
	[self performSelectorOnMainThread:@selector(setupErrorView:) withObject:error waitUntilDone:NO];

	BOOL res=[self waitForResponseFromUI];

	[self performSelectorOnMainThread:@selector(setDisplayedView:) withObject:progressview waitUntilDone:NO];

	if(res && ignoreall)
	{
		if([errorapplyallcheck state]==NSOnState) *ignoreall=YES;
		else *ignoreall=NO;
	}

	return res;
}

-(void)displayOpenError:(NSString *)error
{
	[self performSelectorOnMainThread:@selector(setupOpenErrorView:) withObject:error waitUntilDone:NO];
	[self waitForResponseFromUI];
}

-(NSStringEncoding)displayEncodingSelectorForXADString:(id <XADString>)string
{
	[self performSelectorOnMainThread:@selector(setupEncodingViewForXADString:)
	withObject:string waitUntilDone:NO];

	BOOL res=[self waitForResponseFromUI];

	[self performSelectorOnMainThread:@selector(setDisplayedView:) withObject:progressview waitUntilDone:NO];

	if(res) return [encodingpopup selectedTag];
	else return 0;
}

-(NSString *)displayPasswordInputWithApplyToAllPointer:(BOOL *)applyall encodingPointer:(NSStringEncoding *)encoding
{
	[self performSelectorOnMainThread:@selector(setupPasswordView) withObject:nil waitUntilDone:NO];

	BOOL res=[self waitForResponseFromUI];

	[self performSelectorOnMainThread:@selector(setDisplayedView:) withObject:progressview waitUntilDone:NO];

	if([archive caresAboutPasswordEncoding]) *encoding=[passwordpopup selectedTag];
	else *encoding=0;

	if(res && applyall)
	{
		if([passwordapplyallcheck state]==NSOnState) *applyall=YES;
		else *applyall=NO;
	}

	if(res) return [passwordfield stringValue];
	else return nil;
}



-(void)setupWaitView
{
	if(!waitview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"WaitView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[self updateWaitView];

	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:[archive filename]];
	[icon setSize:[waiticon frame].size];
	[waiticon setImage:icon];

	[self setDisplayedView:waitview];
}

-(void)updateWaitView
{
	NSString *filename=[[archive filename] lastPathComponent];
	NSArray *allfilenames=[archive allFilenames];
	if(allfilenames && [allfilenames count]>1)
	{
		[waitfield setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%@ (+%d more)",@"Status text for queued multi-part archives"),
		filename,[allfilenames count]-1]];
	}
	else
	{
		[waitfield setStringValue:filename];
	}
}

-(void)setupProgressViewInPreparingMode
{
	if(!progressview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"ProgressView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[actionfield setStringValue:[NSString stringWithFormat:
	NSLocalizedString(@"Preparing to extract \"%@\"",@"Status text when preparing to extract an archive"),
	[[archive filename] lastPathComponent]]];

	[namefield setStringValue:@""];

	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:[archive filename]];
	[icon setSize:[progressicon frame].size];
	[progressicon setImage:icon];

	[progressindicator setIndeterminate:YES];
	[progressindicator startAnimation:self];

	[self setDisplayedView:progressview];
}

-(void)setupNotWritableView
{
	if(!notwritableview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"NotWritableView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[self setDisplayedView:notwritableview];
	[self getUserAttention];
}

-(void)setupErrorView:(NSString *)error
{
	if(!errorview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"ErrorView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[errorfield setStringValue:error];
	[self setDisplayedView:errorview];
	[self getUserAttention];
}

-(void)setupOpenErrorView:(NSString *)error
{
	if(!openerrorview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"OpenErrorView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[openerrorfield setStringValue:error];
	[self setDisplayedView:openerrorview];
	[self getUserAttention];
}

-(void)setupPasswordView
{
	if(!passwordview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"PasswordView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	[passwordmessagefield setStringValue:[NSString stringWithFormat:
	NSLocalizedString(@"You need to supply a password to open the archive \"%@\".",@"Status text when asking for a password"),
	[[archive filename] lastPathComponent]]];

	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:[archive filename]];
	[icon setSize:[passwordicon frame].size];
	[passwordicon setImage:icon];

	if([archive caresAboutPasswordEncoding])
	{
		NSRect frame=[passwordview frame];
		frame.size.height=106;
		[passwordview setFrame:frame];

		[passwordpopup buildEncodingListWithDefaultEncoding];
		[passwordpopup selectItemWithTag:0];
	}
	else
	{
		NSRect frame=[passwordview frame];
		frame.size.height=86;
		[passwordview setFrame:frame];

		[passwordpopuplabel setHidden:YES];
		[passwordpopup setHidden:YES];
	}

	[self setDisplayedView:passwordview];
	[[passwordfield window] makeFirstResponder:passwordfield];
	[self getUserAttention];
}

-(void)setupEncodingViewForXADString:(id <XADString>)string
{
	namestring=string; // Does not need retaining, as the thread that provided it is paused.

	if(!encodingview)
	{
		NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"EncodingView" bundle:nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:[archive filename]];
	[icon setSize:[encodingicon frame].size];
	[encodingicon setImage:icon];

	NSStringEncoding encoding=[string encoding];

	[encodingpopup buildEncodingListMatchingXADString:string];
	if(encoding)
	{
		int index=(int)[encodingpopup indexOfItemWithTag:encoding];
		if(index>=0) [encodingpopup selectItemAtIndex:index];
		else [encodingpopup selectItemAtIndex:[encodingpopup indexOfItemWithTag:NSISOLatin1StringEncoding]];
	}

	[self selectEncoding:self];

	[self setDisplayedView:encodingview];
	[[passwordfield window] makeFirstResponder:passwordfield];
	[self getUserAttention];
}




-(void)getUserAttention
{
	[self performSelectorOnMainThread:@selector(getUserAttentionOnMainThread) withObject:nil waitUntilDone:NO];
}

-(void)getUserAttentionOnMainThread
{
	[NSApp activateIgnoringOtherApps:YES];
	[[self window] makeKeyAndOrderFront:self];
}




-(IBAction)cancelWait:(id)sender
{
	[sender setEnabled:NO];
	[canceltarget performSelector:cancelselector withObject:self];
}

-(IBAction)cancelExtraction:(id)sender
{
	[sender setEnabled:NO];
	[canceltarget performSelector:cancelselector withObject:self];
}

-(IBAction)stopAfterNotWritable:(id)sender
{
	[self provideResponseFromUI:0];
}

-(IBAction)extractToDesktopAfterNotWritable:(id)sender
{
	[self provideResponseFromUI:1];
}

-(IBAction)extractElsewhereAfterNotWritable:(id)sender
{
	[self provideResponseFromUI:2];
}

-(IBAction)stopAfterError:(id)sender
{
	[self provideResponseFromUI:NO];
}

-(IBAction)continueAfterError:(id)sender
{
	[self provideResponseFromUI:YES];
}

-(IBAction)okAfterOpenError:(id)sender
{
	[self provideResponseFromUI:0];
}

-(IBAction)stopAfterPassword:(id)sender
{
	[self provideResponseFromUI:NO];
}

-(IBAction)continueAfterPassword:(id)sender
{
	[self provideResponseFromUI:YES];
}

-(IBAction)stopAfterEncoding:(id)sender
{
	[self provideResponseFromUI:NO];
}

-(IBAction)continueAfterEncoding:(id)sender
{
	[self provideResponseFromUI:YES];
}

-(IBAction)selectEncoding:(id)sender
{
	NSStringEncoding encoding=[encodingpopup selectedTag];
	if([namestring canDecodeWithEncoding:encoding]) [encodingfield setStringValue:[namestring stringWithEncoding:encoding]];
	else [encodingfield setStringValue:@""]; // Can't happen, probably.
}



// Uiiiiii~ Aisuuuuu~
-(int)waitForResponseFromUI
{
	responsetarget=nil;
	[pauselock lockWhenCondition:1];
	[pauselock unlockWithCondition:0];
	return uiresponse;
}

-(void)setUIResponseAction:(SEL)selector target:(id)target
{
	responsetarget=target;
	responseselector=selector;
}

-(void)provideResponseFromUI:(int)response
{
	if(responsetarget)
	{
		NSInvocation *invocation=[NSInvocation invocationWithMethodSignature:
		[responsetarget methodSignatureForSelector:responseselector]];

		[invocation setTarget:responsetarget];
		[invocation setSelector:responseselector];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&response atIndex:3];

		[invocation invoke];
//		[invocation performSelector:@selector(invoke) withObject:nil afterDelay:0];
	}
	else
	{
		uiresponse=response;
		[pauselock lockWhenCondition:0];
		[pauselock unlockWithCondition:1];
	}
}


@end
