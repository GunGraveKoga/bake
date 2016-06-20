#import "MissingDependencyException.h"

@implementation MissingDependencyException
+ exceptionWithClass: (Class)class
      dependencyName: (OFString*)dependencyName
{
	return [[[self alloc] initWithClass: class
			     dependencyName: dependencyName] autorelease];
}

-  initWithClass: (Class)class
  dependencyName: (OFString*)dependencyName_
{
	self = [super initWithClass: class];

	@try {
		dependencyName = [dependencyName_ copy];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- init
{
	Class c = [self class];
	[self release];
	@throw [OFNotImplementedException exceptionWithSelector: _cmd
						    object: c];
}

- (void)dealloc
{
	[dependencyName release];

	[super dealloc];
}

- (OFString*)dependencyName
{
	return dependencyName;
}
@end
