#import "MenusHeaderView.h"
#import "MenusSelectionView.h"
#import "Blog.h"
#import "WPStyleGuide.h"
#import "MenusDesign.h"

@interface MenusHeaderView () <MenusSelectionViewDelegate>

@property (nonatomic, weak) IBOutlet UIStackView *stackView;
@property (nonatomic, weak) IBOutlet MenusSelectionView *locationsView;
@property (nonatomic, weak) IBOutlet MenusSelectionView *menusView;
@property (nonatomic, weak) IBOutlet UILabel *textLabel;

@end

static CGFloat const MenusHeaderViewDesignStrokeWidth = 2.0;

@implementation MenusHeaderView

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // provide extra margin to easily draw the design stroke, see drawRect:
    UIEdgeInsets margins = MenusDesignDefaultInsets();
    margins.bottom += MenusHeaderViewDesignStrokeWidth;
    self.stackView.layoutMargins = margins;
    self.stackView.layoutMarginsRelativeArrangement = YES;
    self.stackView.spacing = margins.left; // use a relative spacing to our margin padding
    
    self.backgroundColor = [WPStyleGuide lightGrey];
    self.textLabel.font = [WPStyleGuide subtitleFont];
    self.textLabel.backgroundColor = [UIColor clearColor];
    
    self.locationsView.selectionType = MenuSelectionViewTypeLocations;
    self.locationsView.delegate = self;
    self.menusView.selectionType = MenuSelectionViewTypeMenus;
    self.menusView.delegate = self;
}

- (void)updateWithMenusForBlog:(Blog *)blog
{
    {
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:blog.menuLocations.count];
        for(MenuLocation *location in blog.menuLocations) {
            MenusSelectionViewItem *item = [MenusSelectionViewItem itemWithLocation:location];
            [items addObject:item];
        }
        
        MenusSelectionViewItem *selected = [items firstObject];
        [self.locationsView updateItems:items selectedItem:selected];
    }
    {
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:blog.menus.count];
        for(Menu *menu in blog.menus) {
            MenusSelectionViewItem *item = [MenusSelectionViewItem itemWithMenu:menu];
            [items addObject:item];
        }
        
        MenusSelectionViewItem *selected = [items firstObject];
        [self.menusView updateItems:items selectedItem:selected];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    // required to redraw the stroke because our intrinsicContentSize changed based on the stack view axis change
    // perhaps this won't be needed in a future version of iOS
    // via Brent Coursey 10/30/15
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetLineWidth(context, MenusHeaderViewDesignStrokeWidth);
    
    const CGFloat lineY = rect.size.height - (MenusHeaderViewDesignStrokeWidth / 2);
    CGContextMoveToPoint(context, rect.origin.x, lineY);
    CGContextAddLineToPoint(context, rect.size.width - rect.origin.x, lineY);
    
    CGContextSetStrokeColorWithColor(context, [[WPStyleGuide greyLighten20] CGColor]);
    CGContextStrokePath(context);
}

#pragma mark - MenusSelectionViewDelegate



@end
