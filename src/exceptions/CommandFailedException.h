#import <ObjFW/ObjFW.h>

@interface CommandFailedException: OFInitializationFailedException
{
	OFString *command;
}

+ exceptionWithClass: (Class)class_
	     command: (OFString*)command;
- initWithClass: (Class)class_
	command: (OFString*)command;
- (OFString*)command;
@end
