//
//  KlineView.h
//  Kline
//
//  Created by yndfcd on 15/3/27.
//  Copyright (c) 2015年 BlueMobi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface KlineView : UIView

@property (nonatomic,strong) NSArray* rawData;

@property (nonatomic,assign) int startPos;
@property (nonatomic,assign) CGFloat segmentWidth;
@property (nonatomic,assign) CGFloat macdHeight;
@property (nonatomic,assign) CGFloat maHeight;
@property (nonatomic,assign) CGFloat diagramWidth;
@property (nonatomic,assign) CGFloat leading;
@property (nonatomic,assign) CGFloat top;

-(void)fetchData;
-(id) initWithFrame:(CGRect)frame;

@end
