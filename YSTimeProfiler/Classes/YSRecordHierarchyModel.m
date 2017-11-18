//
//  YSRecordHierarchyModel.m
//  YYStubHook
//
//  Created by yans on 2017/11/18.
//

#import "YSRecordHierarchyModel.h"

@implementation YSRecordHierarchyModel

- (instancetype)initWithRecordModelArr:(NSArray *)recordModelArr
{
    self = [super init];
    if (self) {
        if ([recordModelArr isKindOfClass:NSArray.class] && recordModelArr.count > 0) {
            self.rootMethod = recordModelArr[0];
            self.isExpand = YES;
            if (recordModelArr.count > 1) {
                self.subMethods = [recordModelArr subarrayWithRange:NSMakeRange(1, recordModelArr.count-1)];
            }
        }
    }
    return self;
}

- (YSRecordModel *)getRecordModel:(NSInteger)index
{
    if (index==0) {
        return self.rootMethod;
    }
    return self.subMethods[index-1];
}

- (id)copyWithZone:(NSZone *)zone
{
    YSRecordHierarchyModel *model = [[[self class] allocWithZone:zone] init];
    model.rootMethod = self.rootMethod;
    model.subMethods = self.subMethods;
    model.isExpand = self.isExpand;
    return model;
}

@end
