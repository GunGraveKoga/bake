#import <ObjFW/ObjFW.h>

@interface MissingDependencyException: OFInitializationFailedException
{
	OFString *dependencyName;
}

+ exceptionWithClass: (Class)class_
      dependencyName: (OFString*)dependencyName;
-  initWithClass: (Class)class_
  dependencyName: (OFString*)dependencyName;
- (OFString*)dependencyName;
@end
