//
//  KlineView.m
//  Kline
//
//  Created by yndfcd on 15/3/27.
//  Copyright (c) 2015年 BlueMobi. All rights reserved.
//

#import "KlineView.h"

//static const NSUInteger TotalWidth = 320 - 40;
//static const NSUInteger Heading = 0;

static int OPEN = 1;
static int HIGH = 2;
static int LOW = 3;
static int CLOSE = 4;
static int VOL = 5;
static int AMO = 6;
static int OI = 7;
static int DATE = 0;

static float LeftMarkWidth = 40;
static float TopTextHeight = 20;

@interface KlineView()
{
    UIView* statisticView;
    UIPanGestureRecognizer* panRec;
    UILongPressGestureRecognizer* longPressRec;
    UIPinchGestureRecognizer* pinchRec;
}

@property (nonatomic,strong) NSMutableArray* ema12;
@property (nonatomic,strong) NSMutableArray* ema26;
@property (nonatomic,strong) NSMutableArray* ma5;
@property (nonatomic,strong) NSMutableArray* ma10;
@property (nonatomic,strong) NSMutableArray* ma20;
@property (nonatomic,strong) NSMutableArray* dif;
@property (nonatomic,strong) NSMutableArray* dea;
@property (nonatomic,strong) NSMutableArray* macd;
@property (nonatomic,assign) int numberSegment;

//@property (nonatomic,assign) float maxEMA;
//@property (nonatomic,assign) float minEMA;

@property (nonatomic,assign) float maxDEA;
@property (nonatomic,assign) float minDEA;

@property (nonatomic,assign) float maxPrice;
@property (nonatomic,assign) float minPrice;

@property (nonatomic,assign) float showCross;
@property (nonatomic,assign) CGPoint crossPosition;

@end

@implementation KlineView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

-(void)fetchData
{
    NSString* url = [NSString stringWithFormat:@"http://ichart.yahoo.com/table.csv?s=601888.SS&g=d"];
    
    NSURLRequest *urlRequest = [[NSURLRequest alloc]initWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    
    NSData *response = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:nil error:nil];
    
    NSString* data = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    self.rawData = [self convertData:data];
    
}

-(NSArray*)convertData:(NSString*)data
{
    NSMutableArray* ret = [NSMutableArray array];
    NSArray* lines = [data componentsSeparatedByString:@"\n"];
    
    for( int i = 1; i < lines.count; ++i)
    {
        NSString* line = lines[i];
        NSArray* prices = [line componentsSeparatedByString:@","];
        
        if(prices.count > 6)
            [ret addObject:@[prices[0],
                             prices[1],
                             prices[2],
                             prices[3],
                             prices[4],
                             prices[5],
                             prices[6],
                             ]];
    }
    
    return ret;
}

-(void)setRawData:(NSArray *)rawData
{
    _rawData = rawData;
    
    [self.ma5 removeAllObjects];
    [self.ma10 removeAllObjects];
    [self.ma20 removeAllObjects];
    [self.ema12 removeAllObjects];
    [self.ema26 removeAllObjects];
    [self.dea removeAllObjects];
    [self.dif removeAllObjects];
    [self.macd removeAllObjects];

    self.startPos = INT32_MAX;
    [self calculateMAs];
    [self calculateMACD];
    
    [self setNeedsDisplay];
}

-(BOOL)pointInBox:(CGPoint)point
{
    CGRect rect = CGRectMake(self.leading+LeftMarkWidth, self.top+TopTextHeight, self.diagramWidth, self.maHeight+self.macdHeight);
    
    return CGRectContainsPoint(rect, point);
}

-(void)pinch:(UIPinchGestureRecognizer*)rec
{
    float last;
    CGPoint point = [rec locationInView:self];
    if( [self pointInBox:point] )
    {
        if( rec.state == UIGestureRecognizerStateBegan )
        {
            last = rec.scale;
        }
        
        if( rec.scale > 1 )
        {
            self.segmentWidth += 1;
        }
        else
        {
            self.segmentWidth -= 1;
        }
        
        if( self.segmentWidth < 5 )
        {
            self.segmentWidth = 5;
        }
        if( self.segmentWidth > 20 )
        {
            self.segmentWidth = 20;
        }
        
        last = rec.scale;
    }
    [self setNeedsDisplay];
}
-(void)pan:(UIPanGestureRecognizer*)rec
{
    static CGPoint last;
    
    CGPoint point = [rec locationInView:self];
    if( [self pointInBox:point])
    {
        if( rec.state == UIGestureRecognizerStateBegan )
        {
            last = [rec locationInView:self];
        }
        
        float xOffset = point.x - last.x;
        float yOffset = point.y - last.y;
        
        if( abs(xOffset) > abs(yOffset) )
        {
            if( xOffset > 0 )
            {
                self.startPos -= 1;
            }
            else
            {
                self.startPos += 1;
            }
            
            if( self.startPos < 0 )
            {
                self.startPos = 0;
            }
            if( self.startPos + self.numberSegment >= self.rawData.count )
            {
                self.startPos = self.rawData.count - self.numberSegment;
            }
        }
        else
        {
            /*if( yOffset > 0 )
            {
                self.segmentWidth += 1;
            }
            else
            {
                self.segmentWidth -= 1;
            }
            
            if( self.segmentWidth < 5 )
            {
                self.segmentWidth = 5;
            }
            if( self.segmentWidth > 20 )
            {
                self.segmentWidth = 20;
            }*/
        }
        
        last = point;
        [self setNeedsDisplay];
    }
}

-(void)longPress:(UILongPressGestureRecognizer*)rec
{
    CGPoint point = [rec locationInView:self];
    if( [self pointInBox:point])
    {
        if( rec.state == UIGestureRecognizerStateBegan )
        {
            self.showCross = YES;
        }
        
        point.x -= (self.leading + LeftMarkWidth);
        point.y -= (self.top + TopTextHeight);
        
        int seg = point.x / self.segmentWidth;
        seg += self.startPos;
        
        if( seg < 0 )
            seg = 0;
        if( seg >= self.rawData.count )
        {
            seg = self.rawData.count - 1;
        }
        
        NSArray* data = self.rawData[seg];
        float low = [data[LOW] floatValue];
        float high = [data[HIGH] floatValue];
        float open = [data[OPEN] floatValue];
        float close = [data[CLOSE] floatValue];
        
        float y = open > close ? low : high;
        
        self.crossPosition = CGPointMake(seg + 0.5, y);
        //NSLog(@"cross position = (%f,%f)", (float)seg, y );
    }
    if( rec.state == UIGestureRecognizerStateEnded )
    {
        self.showCross = NO;
    }
    [self setNeedsDisplay];
}

-(instancetype) initWithFrame:(CGRect)frame
{
    if( self = [super initWithFrame:frame])
    {
        self.segmentWidth = 5.0;
        self.macdHeight = 70;
        self.maHeight = 140;
        self.diagramWidth = 240;
        self.leading = 10;
        self.top = 10;
        
        self.ema12 = [NSMutableArray array];
        self.ema26 = [NSMutableArray array];
        self.dif = [NSMutableArray array];
        self.dea = [NSMutableArray array];
        self.macd = [NSMutableArray array];
        self.ma5 = [NSMutableArray array];
        self.ma10 = [NSMutableArray array];
        self.ma20 = [NSMutableArray array];
        
        panRec = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                         action:@selector(pan:)];
        [self addGestureRecognizer:panRec];
        
        longPressRec = [[UILongPressGestureRecognizer alloc]
                        initWithTarget:self
                                action:@selector(longPress:)];
        [self addGestureRecognizer:longPressRec];
        
        pinchRec = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                             action:@selector(pinch:)];
        [self addGestureRecognizer:pinchRec];
        
        [self fetchData];
    }
    
    return self;
}
-(void)awakeFromNib
{
    self.segmentWidth = 5.0;
    self.macdHeight = 70;
    self.maHeight = 140;
    self.diagramWidth = 320;
    self.leading = 10;
    self.top = 10;
    
    self.ema12 = [NSMutableArray array];
    self.ema26 = [NSMutableArray array];
    self.dif = [NSMutableArray array];
    self.dea = [NSMutableArray array];
    self.macd = [NSMutableArray array];
    self.ma5 = [NSMutableArray array];
    self.ma10 = [NSMutableArray array];
    self.ma20 = [NSMutableArray array];
    
    panRec = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                     action:@selector(pan:)];
    [self addGestureRecognizer:panRec];
    
    longPressRec = [[UILongPressGestureRecognizer alloc]
                    initWithTarget:self
                            action:@selector(longPress:)];
    [self addGestureRecognizer:longPressRec];
    
    pinchRec = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                         action:@selector(pinch:)];
    [self addGestureRecognizer:pinchRec];
    
    [self fetchData];
}

-(void)calculateEMA
{
    static float l12 = 2.0/(12+1);
    static float l26 = 2.0/(26+1);
    if( self.rawData.count > 0 )
    {
        NSNumber* close = [self.rawData[0] objectAtIndex:CLOSE];
        [self.ema12 addObject:close];
        [self.ema26 addObject:close];
        [self.dif addObject:[NSNumber numberWithFloat:0.0]];
    }
    for( int i = 1; i < self.rawData.count; ++i )
    {
        NSNumber* cp = [self.rawData[i] objectAtIndex:CLOSE];
        NSNumber* ema12Yesterday = self.ema12[i-1];
        NSNumber* ema26Yesterday = self.ema26[i-1];
        float ema12 = cp.floatValue * l12 + ema12Yesterday.floatValue * (1-l12);
        float ema26 = cp.floatValue * l26 + ema26Yesterday.floatValue * (1-l26);
        
        [self.ema12 addObject:[NSNumber numberWithFloat:ema12]];
        [self.ema26 addObject:[NSNumber numberWithFloat:ema26]];
        
        float dif = ema12 - ema26;
        [self.dif addObject:[NSNumber numberWithFloat:dif]];
    }
}

-(void)calculateDEA
{
    [self calculateEMA];
    
    static float fp = 8.0/10.f;
    static float ft = 2.0/10.f;
    
    if( self.rawData > 0 )
    {
        [self.dea addObject:[NSNumber numberWithFloat:0.0]];
    }
    
    for( int i = 1; i < self.rawData.count; ++i )
    {
        NSNumber* deap = self.dea[i-1];
        NSNumber* dif = self.dif[i];
        
        float dea = deap.floatValue * fp + dif.floatValue * ft;
        [self.dea addObject:[NSNumber numberWithFloat:dea]];
    }
}
-(void)calculateMAs
{
    if( self.rawData.count > 0 )
    {
        NSNumber* c1 = [self.rawData[0] objectAtIndex:CLOSE];
        [self.ma5 addObject:c1];
        [self.ma10 addObject:c1];
        [self.ma20 addObject:c1];
    }
    //MA5
    for( int i = 1; i < self.rawData.count; ++i )
    {
        float sum = 0;
        int count = 0;
        for( int j = i - 1; (j >= i-5-1) && (j >= 0); --j, ++count )
        {
            NSNumber* c = [self.rawData[j] objectAtIndex:CLOSE];
            sum += c.floatValue;
        }
        [self.ma5 addObject:[NSNumber numberWithFloat:sum/count]];
    }
    
    //MA10
    for( int i = 1; i < self.rawData.count; ++i )
    {
        float sum = 0;
        int count = 0;
        for( int j = i - 1; (j >= i-10-1) && (j >= 0); --j, ++count )
        {
            NSNumber* c = [self.rawData[j] objectAtIndex:CLOSE];
            sum += c.floatValue;
        }
        [self.ma10 addObject:[NSNumber numberWithFloat:sum/count]];
    }
    
    //MA20
    for( int i = 1; i < self.rawData.count; ++i )
    {
        float sum = 0;
        int count = 0;
        for( int j = i - 1; (j >= i-20-1) && (j >= 0); --j, ++count )
        {
            NSNumber* c = [self.rawData[j] objectAtIndex:CLOSE];
            sum += c.floatValue;
        }
        [self.ma20 addObject:[NSNumber numberWithFloat:sum/count]];
    }
}

-(void)calculateMACD
{
    [self calculateDEA];
    
    for( int i = 0; i < self.rawData.count; ++i )
    {
        NSNumber* dea = self.dea[i];
        NSNumber* dif = self.dif[i];
        
        float macd = dea.floatValue - dif.floatValue;
        [self.macd addObject:[NSNumber numberWithFloat:macd]];
    }
}

-(void)calculateBoundary
{
    //self.maxEMA = 0;
    //self.minEMA = MAXFLOAT;
    self.maxDEA = 0;
    self.minDEA = MAXFLOAT;
    self.maxPrice = 0;
    self.minPrice = MAXFLOAT;
    
    int endPos = self.startPos + self.numberSegment;
    for( NSInteger i = self.startPos; i < endPos; ++i )
    {
        if( i < 0 || i >= self.rawData.count )
            continue;
        NSNumber* dif = self.dif[i];
        NSNumber* dea = self.dea[i];
        NSNumber* macd = self.macd[i];
        
        if( dif.floatValue < self.minDEA )
        {
            self.minDEA = dif.floatValue;
        }
        if( dif.floatValue > self.maxDEA )
        {
            self.maxDEA = dif.floatValue;
        }
        if( dea.floatValue < self.minDEA )
        {
            self.minDEA = dea.floatValue;
        }
        if( dea.floatValue > self.maxDEA )
        {
            self.maxDEA = dea.floatValue;
        }
        if( -macd.floatValue > self.maxDEA )
        {
            self.maxDEA = -macd.floatValue;
        }
        if( -macd.floatValue < self.minDEA )
        {
            self.minDEA = -macd.floatValue;
        }
        
        NSNumber* low = [self.rawData[i] objectAtIndex:LOW];
        if( low.floatValue < self.minPrice )
        {
            self.minPrice = low.floatValue;
        }
        NSNumber* high = [self.rawData[i] objectAtIndex:HIGH];
        if( high.floatValue > self.maxPrice )
        {
            self.maxPrice = high.floatValue;
        }
        
        NSNumber* ma = self.ma5[i];
        if( (ma.floatValue != 0) && (ma.floatValue < self.minPrice) )
        {
            self.minPrice = ma.floatValue;
        }
        if( ma.floatValue > self.maxPrice )
        {
            self.maxPrice = ma.floatValue;
        }

        ma = self.ma10[i];
        if( (ma.floatValue < self.minPrice) )
        {
            self.minPrice = ma.floatValue;
        }
        if( ma.floatValue > self.maxPrice )
        {
            self.maxPrice = ma.floatValue;
        }
        
        ma = self.ma20[i];
        if( (ma.floatValue < self.minPrice) )
        {
            self.minPrice = ma.floatValue;
        }
        if( ma.floatValue > self.maxPrice )
        {
            self.maxPrice = ma.floatValue;
        }
    }
    
    if( self.maxDEA == self.minDEA )
    {
        self.maxDEA += 1.0;
        self.minDEA -= 1.0;
    }
}

-(void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor( context, self.backgroundColor.CGColor );
    CGContextFillRect( context, rect );
    
    int old = self.numberSegment;
    self.numberSegment = self.diagramWidth / self.segmentWidth;
    self.startPos -= (self.numberSegment - old );
    if( self.startPos + self.numberSegment >= self.rawData.count )
    {
        self.startPos = self.rawData.count - self.numberSegment;
    }

    [self calculateBoundary];
    
    [self drawTextWithContext:context];
    
    CGContextScaleCTM(context, 1, -1);
    CGContextTranslateCTM(context, 0, -(self.macdHeight+self.maHeight));
    
    CGRect box = CGRectMake(0, 0, self.diagramWidth, self.macdHeight+self.maHeight);
    CGContextClipToRect(context, box);
    [self drawOutlineWithContext:context andRect:box];
    [self drawDEAWithContext:context];
    [self drawMACDWithContext:context];
    
    CGContextTranslateCTM(context, 0, (self.macdHeight));
    [self drawMAWithContext:context];
    [self drawPriceWithContext:context];
}

-(CGPoint)convertDEAPoint:(CGPoint)original
{
    CGFloat x = (original.x - self.startPos) * self.segmentWidth;
    CGFloat deltaY = self.maxDEA - self.minDEA;
    CGFloat scale = self.macdHeight / deltaY;
    CGFloat y = (original.y - self.minDEA) * scale;
    return CGPointMake(x, y);
}

/*-(CGPoint)convertDifPoint:(CGPoint)original
{
    CGFloat deltaY = self.maxEMA - self.minEMA;
    CGFloat scale = self.frame.size.height / deltaY;
    
    if( self.minDEA > 0 && self.maxDEA > 0 )
    {
        CGFloat x = (original.x - self.startPos) * self.segmentWidth;
       
        CGFloat y = original.y * scale;
        return CGPointMake(x, y);
    }
    else if( self.maxDEA > 0 && self.minDEA < 0 )
    {
        CGFloat x = (original.x - self.startPos) * self.segmentWidth;
        CGFloat y = original.y * scale;
        return CGPointMake(x, y);
    }
    else
    {
        CGFloat x = (original.x - self.startPos) * self.segmentWidth;
        CGFloat y = original.y * scale;
        return CGPointMake(x, y);
    }
    
}*/

-(CGPoint)convertPricePoint:(CGPoint)original
{
    CGFloat x = (original.x - self.startPos) * self.segmentWidth;
    CGFloat deltaY = self.maxPrice - self.minPrice;
    CGFloat scale = self.maHeight / deltaY;
    CGFloat y = (original.y - self.minPrice) * scale;
    return CGPointMake(x, y);
}

-(void)drawStaticstic:(CGContextRef)context
{
    static CGFloat BKWidth = 60;
    static CGFloat BKHeight = 90;
    static CGFloat Left = 3;
    int middel = self.startPos + self.numberSegment/2;
    CGContextScaleCTM( context, 1.f, -1.f);
    CGContextTranslateCTM( context, 0, -self.maHeight);
    CGFloat x = self.crossPosition.x > middel ? 0 : self.diagramWidth - BKWidth;
    CGRect background = CGRectMake( x, 0, BKWidth, BKHeight);
    CGContextSetRGBFillColor(context, 0.4, 0.4, 0.4, 0.5);
    
    CGContextFillRect( context, background );
    
    int pos = (int)self.crossPosition.x;
    NSArray* data = self.rawData[pos];
    
    float closeYes;
    if( pos - 1 < 0 )
    {
        closeYes = [data[CLOSE] floatValue];
    }
    else
    {
        closeYes = [[self.rawData[pos -1] objectAtIndex:CLOSE] floatValue];
    }
    float high = [data[HIGH] floatValue];
    float low = [data[LOW] floatValue];
    float open = [data[OPEN] floatValue];
    float close = [data[CLOSE] floatValue];

    NSString* dateText = [NSString stringWithFormat:@"日期:%@", data[DATE]];
    NSString* temp = [NSString stringWithFormat:@"最高:%0.2f", high];
    NSMutableAttributedString* highText = [[NSMutableAttributedString alloc] initWithString:temp];
    NSRange range = { 0, 3 };
    [highText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [highText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:range];
    range.location = 3, range.length = temp.length-range.location;
    UIColor* color;
    if( high > closeYes)
    {
        color = [UIColor redColor];
    }
    else if( high < closeYes )
    {
        color = [UIColor greenColor];
    }
    else
    {
        color = [UIColor whiteColor];
    }
    [highText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [highText addAttribute:NSForegroundColorAttributeName value:color range:range];
    
    temp = [NSString stringWithFormat:@"最低:%0.2f", low];
    NSMutableAttributedString* lowText = [[NSMutableAttributedString alloc] initWithString:temp];
    range.location = 0, range.length = 3;
    [lowText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [lowText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:range];
    range.location = 3, range.length = temp.length-range.location;
    if( low > closeYes)
    {
        color = [UIColor redColor];
    }
    else if( low < closeYes )
    {
        color = [UIColor greenColor];
    }
    else
    {
        color = [UIColor whiteColor];
    }
    [lowText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [lowText addAttribute:NSForegroundColorAttributeName value:color range:range];
    
    temp = [NSString stringWithFormat:@"开盘:%0.2f", open];
    NSMutableAttributedString* openText = [[NSMutableAttributedString alloc] initWithString:temp];
    range.location = 0, range.length = 3;
    [openText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [openText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:range];
    range.location = 3, range.length = temp.length-range.location;
    if( open > closeYes)
    {
        color = [UIColor redColor];
    }
    else if( open < closeYes )
    {
        color = [UIColor greenColor];
    }
    else
    {
        color = [UIColor whiteColor];
    }
    [openText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [openText addAttribute:NSForegroundColorAttributeName value:color range:range];
    
    temp = [NSString stringWithFormat:@"收盘:%0.2f", close];
    NSMutableAttributedString* closeText = [[NSMutableAttributedString alloc] initWithString:temp];
    range.location = 0, range.length = 3;
    [closeText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [closeText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:range];
    range.location = 3, range.length = temp.length-range.location;
    if( close > closeYes)
    {
        color = [UIColor redColor];
    }
    else if( close < closeYes )
    {
        color = [UIColor greenColor];
    }
    else
    {
        color = [UIColor whiteColor];
    }
    [closeText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [closeText addAttribute:NSForegroundColorAttributeName value:color range:range];
    
    float rate = (close - closeYes) / closeYes * 100.0;
    temp = [NSString stringWithFormat:@"涨跌幅:%0.2f%%", rate];
    NSMutableAttributedString* rateText = [[NSMutableAttributedString alloc] initWithString:temp];
    range.location = 0, range.length = 4;
    [rateText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [rateText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:range];
    range.location = 4, range.length = temp.length-range.location;
    if( rate > 0)
    {
        color = [UIColor redColor];
    }
    else if( rate < 0 )
    {
        color = [UIColor greenColor];
    }
    else
    {
        color = [UIColor whiteColor];
    }
    [rateText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [rateText addAttribute:NSForegroundColorAttributeName value:color range:range];
    
    NSString* macdText = @"指标:MACD";
    temp = [NSString stringWithFormat:@"DIF:%0.2f", [self.dif[pos] floatValue]];
    NSMutableAttributedString* difText = [[NSMutableAttributedString alloc] initWithString:temp];
    range.location = 0, range.length = 4;
    [difText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [difText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:range];
    range.location = 4, range.length = temp.length-range.location;
    if( [self.dif[pos] floatValue] > 0)
    {
        color = [UIColor redColor];
    }
    else
    {
        color = [UIColor greenColor];
    }
    [difText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [difText addAttribute:NSForegroundColorAttributeName value:color range:range];
    
    temp = [NSString stringWithFormat:@"DEA:%0.2f", [self.dea[pos] floatValue]];
    NSMutableAttributedString* deaText = [[NSMutableAttributedString alloc] initWithString:temp];
    range.location = 0, range.length = 4;
    [deaText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [deaText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:range];
    range.location = 4, range.length = temp.length-range.location;
    if( [self.dea[pos] floatValue] > 0)
    {
        color = [UIColor redColor];
    }
    else
    {
        color = [UIColor greenColor];
    }
    [deaText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:8.f] range:range];
    [deaText addAttribute:NSForegroundColorAttributeName value:color range:range];
    
    CGAffineTransform t = CGAffineTransformMakeScale(1.f, 2.5f);
    CGContextSetTextMatrix(context, t);
    
    NSDictionary* attr = @{
                           NSFontAttributeName:[UIFont systemFontOfSize:8.f],
                           NSForegroundColorAttributeName:[UIColor whiteColor]
                           };
    [dateText drawAtPoint:CGPointMake(x+Left, 0) withAttributes:attr];
    [openText drawAtPoint:CGPointMake(x+Left, 10)];
    [highText drawAtPoint:CGPointMake(x+Left, 20)];
    [lowText drawAtPoint:CGPointMake(x+Left, 30)];
    [closeText drawAtPoint:CGPointMake(x+Left, 40)];
    [rateText drawAtPoint:CGPointMake(x+Left, 50)];
    [macdText drawAtPoint:CGPointMake(x+Left, 60) withAttributes:attr];
    [difText drawAtPoint:CGPointMake(x+Left, 70)];
    [deaText drawAtPoint:CGPointMake(x+Left, 80)];
}

-(void)drawCross:(CGContextRef)context
{
    CGPoint point = [self convertPricePoint:self.crossPosition];
    
    CGContextSetStrokeColorWithColor( context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth( context, 0.5f );
    CGContextMoveToPoint( context, 0, point.y );
    CGContextAddLineToPoint( context, self.diagramWidth, point.y );
    
    CGContextMoveToPoint( context, point.x, -self.macdHeight );
    CGContextAddLineToPoint( context, point.x, self.maHeight);
    CGContextStrokePath(context);
    
    [self drawStaticstic:context];
}

-(void)drawTextWithContext:(CGContextRef)context
{
    //MAs
    int pos = self.startPos + self.numberSegment - 1;
    //NSLog(@" pos = %d, cout = %d", self.startPos, self.numberSegment );
    if( self.showCross )
    {
        pos = self.crossPosition.x;
    }
    NSDictionary* attr;
    if( (pos >= 0) && (pos < self.rawData.count) )
    {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, self.leading * 1.1 + LeftMarkWidth, self.top );
        NSNumber* ma = self.ma5[pos];
        NSString* ma5Text = [NSString stringWithFormat:@"MA5=%0.2f", ma.floatValue];
        attr = @{
                               NSFontAttributeName:[UIFont systemFontOfSize:10.f],
                               NSForegroundColorAttributeName:[UIColor whiteColor]
                               };
        [ma5Text drawAtPoint:CGPointMake(0, 0) withAttributes:attr];
        
        ma = self.ma10[pos];
        NSString* ma10Text = [NSString stringWithFormat:@"MA10=%0.2f", ma.floatValue];
        attr = @{
                 NSFontAttributeName:[UIFont systemFontOfSize:10.f],
                 NSForegroundColorAttributeName:[UIColor yellowColor]
                 };
        [ma10Text drawAtPoint:CGPointMake(self.diagramWidth/3.0, 0) withAttributes:attr];
        
        ma = self.ma20[pos];
        NSString* ma20Text = [NSString stringWithFormat:@"MA20=%0.2f", ma.floatValue];
        attr = @{
                 NSFontAttributeName:[UIFont systemFontOfSize:10.f],
                 NSForegroundColorAttributeName:[UIColor purpleColor]
                 };
        [ma20Text drawAtPoint:CGPointMake(self.diagramWidth*2/3, 0) withAttributes:attr];
        CGContextRestoreGState(context);
    }

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, self.leading, self.top + TopTextHeight - 7 );
    attr = @{
             NSFontAttributeName:[UIFont systemFontOfSize:10.f],
             NSForegroundColorAttributeName:[UIColor redColor]
             };
    if( self.maxDEA > self.minDEA )
    {
        NSString* maxDEA = [NSString stringWithFormat:@"%0.2f", self.maxDEA];
        NSString* midDEA = [NSString stringWithFormat:@"%0.2f", (self.maxDEA + self.minDEA)*0.5];
        NSString* minDEA = [NSString stringWithFormat:@"%0.2f", self.minDEA];
        [maxDEA drawAtPoint:CGPointMake(0, self.maHeight + 5) withAttributes:attr];
        [midDEA drawAtPoint:CGPointMake(0, self.maHeight + self.macdHeight*0.5) withAttributes:attr];
        [minDEA drawAtPoint:CGPointMake(0, self.macdHeight + self.maHeight ) withAttributes:attr];
    }
    else
    {
        [@"--/--" drawAtPoint:CGPointMake(0, self.maHeight + 5) withAttributes:attr];
        [@"--/--" drawAtPoint:CGPointMake(0, self.maHeight + self.macdHeight*0.5) withAttributes:attr];
        [@"--/--" drawAtPoint:CGPointMake(0, self.macdHeight + self.maHeight ) withAttributes:attr];
    }
    
    if( self.maxPrice > self.minPrice )
    {
        float delta = self.maxPrice - self.minPrice;
        NSString* pmax = [NSString stringWithFormat:@"%0.2f", self.maxPrice];
        NSString* p1 = [NSString stringWithFormat:@"%0.2f", self.minPrice + delta * 0.75];
        NSString* p2 = [NSString stringWithFormat:@"%0.2f", self.minPrice + delta * 0.5];
        NSString* p3 = [NSString stringWithFormat:@"%0.2f", self.minPrice + delta * 0.25];
        NSString* pmin = [NSString stringWithFormat:@"%0.2f", self.minPrice];
        [pmax drawAtPoint:CGPointMake(0, 0) withAttributes:attr];
        [p1 drawAtPoint:CGPointMake(0, self.maHeight*0.25) withAttributes:attr];
        [p2 drawAtPoint:CGPointMake(0, self.maHeight*0.5) withAttributes:attr];
        [p3 drawAtPoint:CGPointMake(0, self.maHeight*0.75) withAttributes:attr];
        [pmin drawAtPoint:CGPointMake(0, self.maHeight - 5) withAttributes:attr];
    }
    else
    {
        [@"--/--" drawAtPoint:CGPointMake(0, 0) withAttributes:attr];
        [@"--/--" drawAtPoint:CGPointMake(0, self.maHeight*0.25) withAttributes:attr];
        [@"--/--" drawAtPoint:CGPointMake(0, self.maHeight*0.5) withAttributes:attr];
        [@"--/--" drawAtPoint:CGPointMake(0, self.maHeight*0.75) withAttributes:attr];
        [@"--/--" drawAtPoint:CGPointMake(0, self.maHeight - 5) withAttributes:attr];
    }
    CGContextRestoreGState(context);
    //CGContextSaveGState(context);
    
    CGContextTranslateCTM(context, self.leading * 1.1 + LeftMarkWidth, self.top + TopTextHeight );
    //Dates
    attr = @{
             NSFontAttributeName:[UIFont systemFontOfSize:10.f],
             NSForegroundColorAttributeName:[UIColor whiteColor]
             };
    if( self.startPos >= 0 && self.startPos < self.rawData.count )
    {
        NSString* date1 = [self.rawData[self.startPos] objectAtIndex:DATE];
        [date1 drawAtPoint:CGPointMake(0, self.maHeight+self.macdHeight) withAttributes:attr];
    }
    
    int middle = self.startPos + self.numberSegment/2;
    if( middle >= 0 && middle < self.rawData.count )
    {
        NSString* date2 = [self.rawData[middle] objectAtIndex:DATE];
        [date2 drawAtPoint:CGPointMake(self.diagramWidth/2.0-25, self.maHeight+self.macdHeight)
            withAttributes:attr];
    }
    
    int end = self.startPos + self.numberSegment - 1;
    if( end >= 0 && end < self.rawData.count )
    {
        NSString* date3 = [self.rawData[end] objectAtIndex:DATE];
        [date3 drawAtPoint:CGPointMake(self.diagramWidth-45, self.maHeight+self.macdHeight)
            withAttributes:attr];
    }
    //CGContextRestoreGState(context);
}

-(void)drawOutlineWithContext:(CGContextRef)context andRect:(CGRect)rect
{
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextAddRect(context, rect);
    CGContextStrokePath(context);
    
    CGContextSaveGState(context);
    CGFloat pattern[] = { 3.f, 3.f, };
    CGContextSetLineDash(context, 0.f , pattern, 2);
    
    CGContextMoveToPoint( context, rect.origin.x, self.macdHeight*0.5);
    CGContextAddLineToPoint( context, rect.origin.x+rect.size.width, self.macdHeight*0.5);
    
    CGContextMoveToPoint( context, rect.origin.x, self.macdHeight);
    CGContextAddLineToPoint( context, rect.origin.x+rect.size.width, self.macdHeight);
    
    CGContextMoveToPoint( context, rect.origin.x, self.macdHeight+self.maHeight*0.25);
    CGContextAddLineToPoint( context, rect.origin.x+rect.size.width, self.macdHeight+self.maHeight*0.25);
    
    CGContextMoveToPoint( context, rect.origin.x, self.macdHeight+self.maHeight*0.5);
    CGContextAddLineToPoint( context, rect.origin.x+rect.size.width, self.macdHeight+self.maHeight*0.5);
    
    CGContextMoveToPoint( context, rect.origin.x, self.macdHeight+self.maHeight*0.75);
    CGContextAddLineToPoint( context, rect.origin.x+rect.size.width, self.macdHeight+self.maHeight*0.75);
    
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

-(void)drawPriceWithContext:(CGContextRef)context
{
    int endPos = self.startPos + self.numberSegment + 1;
    
    for( int i = self.startPos; i < endPos; ++i )
    {
        if( i < 0 || i >= self.rawData.count )
            continue;
        
        NSNumber* open = [self.rawData[i] objectAtIndex:OPEN];
        NSNumber* close = [self.rawData[i] objectAtIndex:CLOSE];
        NSNumber* high = [self.rawData[i] objectAtIndex:HIGH];
        NSNumber* low = [self.rawData[i] objectAtIndex:LOW];
        
        UIColor* color = open.floatValue > close.floatValue ? [UIColor greenColor] : [UIColor redColor];
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextSetLineWidth(context, 1.0);
        
        CGPoint start = [self convertPricePoint:CGPointMake(i+0.5, high.floatValue)];
        CGPoint end = [self convertPricePoint:CGPointMake(i+0.5, low.floatValue)];
        CGContextMoveToPoint( context, start.x, start.y);
        CGContextAddLineToPoint( context, end.x, end.y);
        CGContextStrokePath(context);
        
        CGContextSetLineWidth(context, 0.6*self.segmentWidth);
        start = [self convertPricePoint:CGPointMake(i+0.5, open.floatValue)];
        end = [self convertPricePoint:CGPointMake(i+0.5, close.floatValue)];
        if( abs(start.y - end.y) < 1.0 )
        {
            start.y = end.y - 1;
        }
        CGContextMoveToPoint( context, start.x, start.y);
        CGContextAddLineToPoint( context, end.x, end.y);
        CGContextStrokePath(context);
    }
    
    if( self.showCross )
    {
        [self drawCross:context];
    }
}

-(void)drawMAWithContext:(CGContextRef)context
{
    if( self.numberSegment < 1 )
        return;
    
    int endPos = self.startPos + self.numberSegment + 2;
    if( endPos > self.rawData.count )
    {
        endPos = self.rawData.count;
    }
    
    //ma5
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 1.0);
    
    BOOL isFirst = YES;
    for( int i = self.startPos; i < endPos; ++i )
    {
        if( i < 0 || i >= self.rawData.count )
            continue;
        
        if(isFirst)
        {
            NSNumber* ma = self.ma5[i];
            CGPoint point = [self convertPricePoint:CGPointMake(i, ma.floatValue)];
            CGContextMoveToPoint( context, point.x, point.y);
            isFirst = NO;
        }
        else
        {
            NSNumber* ma = self.ma5[i];
            CGPoint point = [self convertPricePoint:CGPointMake(i, ma.floatValue)];
            CGContextAddLineToPoint( context, point.x, point.y);
        }
    }
    CGContextStrokePath(context);
    
    //ma10
    CGContextSetStrokeColorWithColor(context, [UIColor yellowColor].CGColor);
    CGContextSetLineWidth(context, 1.0);
    isFirst = YES;
    for( int i = self.startPos; i < endPos; ++i )
    {
        if( i < 0 || i >= self.rawData.count )
            continue;
        
        if(isFirst)
        {
            NSNumber* ma = self.ma10[i];
            CGPoint point = [self convertPricePoint:CGPointMake(i, ma.floatValue)];
            CGContextMoveToPoint( context, point.x, point.y);
            isFirst = NO;
        }
        else
        {
            NSNumber* ma = self.ma10[i];
            CGPoint point = [self convertPricePoint:CGPointMake(i, ma.floatValue)];
            CGContextAddLineToPoint( context, point.x, point.y);
        }
    }
    CGContextStrokePath(context);
    
    //ma20
    CGContextSetStrokeColorWithColor(context, [UIColor purpleColor].CGColor);
    CGContextSetLineWidth(context, 1.0);
    isFirst = YES;
    for( int i = self.startPos; i < endPos; ++i )
    {
        if( i < 0 || i >= self.rawData.count )
            continue;
        
        if(isFirst)
        {
            NSNumber* ma = self.ma20[i];
            CGPoint point = [self convertPricePoint:CGPointMake(i, ma.floatValue)];
            CGContextMoveToPoint( context, point.x, point.y);
            isFirst = NO;
        }
        else
        {
            NSNumber* ma = self.ma20[i];
            CGPoint point = [self convertPricePoint:CGPointMake(i, ma.floatValue)];
            CGContextAddLineToPoint( context, point.x, point.y);
        }
    }
    CGContextStrokePath(context);
}

-(void)drawDEAWithContext:(CGContextRef)context
{
    int endPos = self.startPos + self.numberSegment + 2;
    
    //draw dif
    BOOL isFirst = YES;
    for( int i = self.startPos; i < endPos; ++i )
    {
        if( i < 0 || i >= self.rawData.count )
            continue;
        
        NSNumber* dif = self.dif[i];
        //float x = i*self.segmentWidth;
        
        if( isFirst )
        {
            CGPoint point = [self convertDEAPoint:CGPointMake(i, dif.floatValue)];
            CGContextMoveToPoint( context, point.x, point.y );
            isFirst = NO;
        }
        else
        {
            CGPoint point = [self convertDEAPoint:CGPointMake(i, dif.floatValue)];
            CGContextAddLineToPoint( context, point.x, point.y );
        }
    }
    CGContextSetStrokeColorWithColor(context, [UIColor yellowColor].CGColor);
    CGContextStrokePath(context);
    
    //draw dea
    isFirst = YES;
    for( int i = self.startPos; i < endPos; ++i )
    {
        if( i < 0 || i >= self.rawData.count )
            continue;
        
        NSNumber* dea = self.dea[i];
        //float x = i*self.segmentWidth;
        if( isFirst )
        {
            CGPoint point = [self convertDEAPoint:CGPointMake(i, dea.floatValue)];
            CGContextMoveToPoint( context, point.x, point.y );
            isFirst = NO;
        }
        else
        {
            CGPoint point = [self convertDEAPoint:CGPointMake(i, dea.floatValue)];
            CGContextAddLineToPoint( context, point.x, point.y );
        }
    }
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextStrokePath(context);
}

-(void)drawMACDWithContext:(CGContextRef)context
{
    //CGContextTranslateCTM(context, 0, self.minDIF);
    int endPos = self.startPos + self.numberSegment + 1;
    for( int i = self.startPos; i < endPos; ++i )
    {
        if( i < 0 || i >= self.rawData.count )
            continue;
        
        NSNumber* macd = self.macd[i];
        float macdf = -[macd floatValue];
        UIColor* color = macdf > 0 ? [UIColor redColor] : [UIColor greenColor];
        
        CGPoint start = [self convertDEAPoint:CGPointMake(i+0.5, 0)];
        CGPoint end = [self convertDEAPoint:CGPointMake(i+0.5, macdf)];
        CGContextMoveToPoint(context, start.x, start.y);
        
        //float y = dif.floatValue;
        CGContextAddLineToPoint(context, end.x, end.y);
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextSetLineWidth(context, self.segmentWidth/2);
        CGContextStrokePath(context);
    }
}

@end
