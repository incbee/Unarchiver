#import "UniversalDetector.h"
#import "WrappedUniversalDetector.h"

@implementation UniversalDetector

+(UniversalDetector *)detector
{
	return [[self new] autorelease];
}

-(id)init
{
	if(self=[super init])
	{
		detector=AllocUniversalDetector();
		charset=nil;
	}
	return self;
}

-(void)dealloc
{
	FreeUniversalDetector(detector);
	[charset release];
	[super dealloc];
}

-(void)analyzeData:(NSData *)data
{
	[self analyzeBytes:(const char *)[data bytes] length:[data length]];
}

-(void)analyzeBytes:(const char *)data length:(int)len
{
	UniversalDetectorHandleData(detector,data,len);
	[charset release];
	charset=nil;
}

-(void)reset { UniversalDetectorReset(detector); }

-(BOOL)done { return UniversalDetectorDone(detector); }

-(NSString *)MIMECharset
{
	if(!charset)
	{
		const char *cstr=UniversalDetectorCharset(detector,&confidence);
		if(!cstr) return nil;
		charset=[[NSString alloc] initWithUTF8String:cstr];
	}
	return charset;
}

-(NSStringEncoding)encoding
{
	NSString *mimecharset=[self MIMECharset];
	if(!mimecharset) return 0;
	CFStringEncoding cfenc=CFStringConvertIANACharSetNameToEncoding((CFStringRef)mimecharset);
	if(cfenc==kCFStringEncodingInvalidId) return 0;
	return CFStringConvertEncodingToNSStringEncoding(cfenc);
}

-(float)confidence
{
	if(!charset) [self MIMECharset];
	return confidence;
}

@end
