//
//  EjectionFractionImage.mm
//  Ejection Fraction II
//
//  Created by Alessandro Volz on 17.12.09.
//  Copyright 2009 OsiriX Team. All rights reserved.
//

#import "EjectionFractionImage.h"
#import <OsiriX Headers/DCMPix.h>
#import <OsiriX Headers/ROI.h>
#import <OsiriX Headers/MyPoint.h>
#import <Nitrogen/N2Operators.h>
#import <Nitrogen/N2MinMax.h>


@implementation EjectionFractionImage
@synthesize rois = _rois, pix = _pix;

+(id)imageWithObjects:(NSArray*)objects {
	return [[(EjectionFractionImage*)[self alloc] initWithObjects:objects] autorelease];
}

-(id)initWithObjects:(NSArray*)objects {
	NSMutableArray* rois = [NSMutableArray arrayWithCapacity:[objects count]];
	for (id o in objects)
		if ([o isKindOfClass:[DCMPix class]]) {
			[o baseAddr]; // make sure baseAddr is valid
			NSImage* image = [o image];
		//	[image setSize:[image size]*NSMakeSize([o pixelSpacingX], [o pixelSpacingY])];
			[self setPix:image];
		} else [rois addObject:o];
	[self setRois:rois];
	
	self = [self initWithSize: _pix? [_pix size] : NSMakeSize(128)];
	
	return self;
}

-(void)dealloc {
	[self setRois:NULL];
	[self setPix:NULL];
	[super dealloc];
}

-(BOOL)isLogicallyResizable {
	return YES;
}

-(NSRect)optimalRoiRect {
	NSMutableArray* points = [NSMutableArray arrayWithCapacity:0];
	for (ROI* roi in _rois)
		[points addObjectsFromArray:[roi splinePoints]];
	
	N2MinMax x = N2MakeMinMax([[points objectAtIndex:0] x]);
	N2MinMax y = N2MakeMinMax([[points objectAtIndex:0] y]);
	for (MyPoint* p in points) {
		N2ExtendMinMax(x, p.x);
		N2ExtendMinMax(y, p.y);
	}
	
	NSRect space = NSMakeRect(x.min, y.min, x.max-x.min, y.max-y.min);
	
	NSRect contentRect;
	contentRect.size = NSMakeSize(std::max(space.size.width, space.size.height));
	contentRect.origin = space.origin - (contentRect.size-space.size)/2;
	
	contentRect = NSInsetRect(contentRect, -contentRect.size.width/100, -contentRect.size.height/100);
	
	return contentRect;
}

-(void)paintImageWithPic:(NSImage*)pic rois:(NSArray*)rois {
	NSSize size = [self size];
	[self lockFocus];
	
	NSRectFillUsingOperation(NSMakeRect(NSZeroPoint, size), NSCompositeClear);

	NSAffineTransform* transform = [NSAffineTransform transform];
	[transform scaleXBy:1 yBy:-1];
	[transform translateXBy:0 yBy:-size.height];
	
	NSRect contentRect = NSZeroRect;
	if (pic) {
		contentRect.size = [pic size];
		[pic drawInRect:NSMakeRect(NSZeroPoint, size) fromRect:NSMakeRect(NSZeroPoint, contentRect.size) operation:NSCompositeCopy fraction:1];
	} else {
		contentRect = [self optimalRoiRect];
	}
	
	[transform translateXBy:-contentRect.origin.x*size.width/contentRect.size.width yBy:-contentRect.origin.y*size.height/contentRect.size.height];
	[transform scaleXBy:size.width/contentRect.size.width yBy:size.height/contentRect.size.height];
	
	for (ROI* roi in rois) {
		NSBezierPath* path = [NSBezierPath bezierPath];
		NSMutableArray* points = [roi splinePoints];
		
		[path moveToPoint:[[points objectAtIndex:0] point]];
		for (MyPoint* p in points)
			[path lineToPoint:[p point]];
		[path closePath];
		[path transformUsingAffineTransform:transform];
		
		[[roi NSColor] setStroke];
		[path setLineWidth:(contentRect.size.width+contentRect.size.height)/320];
		[path stroke];
	}
	
	[self unlockFocus];
	return;
}

-(void)setSize:(NSSize)size {
	[super setSize:size];
	[self paintImageWithPic:_pix rois:_rois];
}

-(NSSize)optimalSize {
	return n2::ceil(_pix? [_pix size] : [self optimalRoiRect].size);
}

-(NSSize)optimalSizeForWidth:(CGFloat)width {
	NSSize imageSize = _pix? [_pix size] : [self optimalRoiRect].size;
	if (width == CGFLOAT_MAX) width = imageSize.width;
	return n2::ceil(NSMakeSize(width, width/imageSize.width*imageSize.height));
}

@end