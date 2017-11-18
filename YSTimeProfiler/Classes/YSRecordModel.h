//
//  YSRecordModel.h
//  YYStubHook
//
//  Created by yans on 2017/11/18.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface YSRecordModel : NSObject <NSCopying>

@property (nonatomic, strong)Class cls;
@property (nonatomic)SEL sel;
@property (nonatomic, assign)uint64_t costTime; //单位：纳秒（百万分之一秒）
@property (nonatomic, assign)int depth;

// 辅助堆栈排序
@property (nonatomic, assign)int total;
@property (nonatomic)BOOL isUsed;

//call 次数
@property (nonatomic, assign)int callCount;

- (instancetype)initWithCls:(Class)cls sel:(SEL)sel time:(uint64_t)costTime depth:(int)depth total:(int)total;

- (BOOL)isEqualRecordModel:(YSRecordModel *)model;

@end

NS_ASSUME_NONNULL_END
