#import <ObjFW/ObjFW.h>

@interface Buildinfo: OFObject
{
	OFMutableArray *ingredients;
	BOOL debug;
	OFString* platform;
	OFString *objC;
	OFMutableArray *objCFlags, *systemIncludes, *includeDirs, *defines, *libs, *libDirs;
	OFMutableArray *conditionals;
}

- (void)populateFromDictionary: (OFDictionary*)info;
- (void)inheritBuildinfo: (Buildinfo*)info;
- (OFArray*)ingredients;
- (BOOL)debug;
- (OFString*)platform;
- (OFString*)objC;
- (OFArray*)objCFlags;
- (OFArray*)systemIncludes;
- (OFArray*)includeDirs;
- (OFArray*)defines;
- (OFArray*)libs;
- (OFArray*)libDirs;
- (OFArray*)conditionals;
@end
