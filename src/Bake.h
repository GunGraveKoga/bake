#import <ObjFW/ObjFW.h>

#import "Recipe.h"
#import "Target.h"

@interface Bake: OFObject
{
	Recipe *_recipe;
	BOOL _verbose, _rebake, _install, _produceIngredient;
	OFString* _prefix;
}

@property(assign)BOOL verbose;
@property(assign)BOOL rebake;
@property(assign)BOOL install;
@property(retain)Recipe* recipe;
@property(assign)BOOL produceIngredient;
@property(copy)OFString* prefix;

- (void)findRecipe;
- (BOOL)shouldRebuildFile: (OFString*)file
		   target: (Target*)target;

- (void)produceIngredientWithArguments:(OFArray OF_GENERIC(OFString*) *)arguments;

@end
