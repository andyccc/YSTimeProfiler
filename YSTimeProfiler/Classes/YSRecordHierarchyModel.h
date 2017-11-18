//
//  YSRecordHierarchyModel.h
//  YYStubHook
//
//  Created by yans on 2017/11/18.
//

#import <Foundation/Foundation.h>
#import "YSRecordModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface YSRecordHierarchyModel : NSObject <NSCopying>

@property (nonatomic, strong)YSRecordModel *rootMethod;
@property (nonatomic, copy)NSArray *subMethods;
@property (nonatomic, assign)BOOL isExpand;   //是否展开所有的子函数

- (instancetype)initWithRecordModelArr:(NSArray *)recordModelArr;
- (YSRecordModel *)getRecordModel:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
