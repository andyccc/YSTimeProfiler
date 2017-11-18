//
//  YSRecordCell.h
//  YYStubHook
//
//  Created by yans on 2017/11/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class YSRecordModel;
@class YSRecordCell;

@protocol YSRecordCellDelegate <NSObject>

- (void)recordCell:(YSRecordCell *)cell clickExpandWithSection:(NSInteger)section;

@end

@interface YSRecordCell : UITableViewCell

@property (nonatomic, weak)id<YSRecordCellDelegate> delegate;

- (void)bindRecordModel:(YSRecordModel *)model isHiddenExpandBtn:(BOOL)isHidden isExpand:(BOOL)isExpand section:(NSInteger)section isCallCountType:(BOOL)isCallCountType;

@end

NS_ASSUME_NONNULL_END
