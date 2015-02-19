//
//  RVButtonBlock.m
//  Pods
//
//  Created by Ata Namvari on 2015-02-18.
//
//

#import "RVButtonBlock.h"
#import "RVModelProject.h"

@interface RVButtonBlock()

@property (nonatomic, strong) NSString *iconPath;
@property (nonatomic, strong) NSAttributedString *label;

@end

@implementation RVButtonBlock

- (void)setLabelString:(NSString *)labelString {
    _labelString = labelString;
    _label = nil;
}

- (void)updateWithJSON:(NSDictionary *)JSON {
    [super updateWithJSON:JSON];
    
    // label
    NSString *label = [JSON objectForKey:@"buttonLabel"];
    if (label && label != (id)[NSNull null]) {
        self.labelString = label;
    }
    
    // iconPath
    NSString *iconPath = [JSON objectForKey:@"iconPath"];
    if (iconPath && iconPath != (id)[NSNull null]) {
        self.iconPath = iconPath;
    }
}

- (NSAttributedString *)label {
    if (!_label) {
        _label = [[NSAttributedString alloc] initWithData:[self.labelString dataUsingEncoding:NSUnicodeStringEncoding] options:@{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType} documentAttributes:nil error:nil];
        
        // Remove any trailing newline
        if (_label.length) {
            NSAttributedString *last = [_label attributedSubstringFromRange:NSMakeRange(_label.length - 1, 1)];
            if ([[last string] isEqualToString:@"\n"]) {
                _label = [_label attributedSubstringFromRange:NSMakeRange(0, _label.length - 1)];
            }
        }
    }
    
    return _label;
}

- (NSURL *)iconURL {
    return [NSURL URLWithString:self.iconPath];
}

- (CGFloat)heightForWidth:(CGFloat)width {
    return [super heightForWidth:width] + [[self label] boundingRectWithSize:CGSizeMake(width, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size.height;
}

@end
