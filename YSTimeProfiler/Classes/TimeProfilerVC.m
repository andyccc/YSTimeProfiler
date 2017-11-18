//
//  TimeProfilerVC.m
//  YYStubHook
//
//  Created by yans on 2017/11/18.
//

#import "TimeProfilerVC.h"
#import "YSCallTrace.h"
#import "YSRecordCell.h"
#import "YSRecordModel.h"
#import "YSRecordHierarchyModel.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, YSTableType) {
    tableTypeSequential,
    tableTypecostTime,
    tableTypeCallCount,
};

static CGFloat YSScrollWidth = 600;
static CGFloat YSHeaderHight = 100;

@interface TimeProfilerVC () <UITableViewDataSource, YSRecordCellDelegate>

@property (nonatomic, strong)UIButton *RecordBtn;
@property (nonatomic, strong)UIButton *costTimeSortBtn;
@property (nonatomic, strong)UIButton *callCountSortBtn;
@property (nonatomic, strong)UIButton *popVCBtn;
@property (nonatomic, strong)UITableView *tableView;
@property (nonatomic, strong)UILabel *tableHeaderViewLabel;
@property (nonatomic, strong)UIScrollView *scrollView;
@property (nonatomic, copy)NSArray *sequentialMethodRecord;
@property (nonatomic, copy)NSArray *costTimeSortMethodRecord;
@property (nonatomic, copy)NSArray *callCountSortMethodRecord;
@property (nonatomic, assign)YSTableType tableType;

@end

@implementation TimeProfilerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    _sequentialMethodRecord = [NSArray array];
    _tableType = tableTypeSequential;
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.RecordBtn];
    [self.view addSubview:self.costTimeSortBtn];
    [self.view addSubview:self.callCountSortBtn];
    [self.view addSubview:self.popVCBtn];
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.tableHeaderViewLabel];
    [self.scrollView addSubview:self.tableView];
    // Do any additional setup after loading the view.
    [self stopAndGetCallRecord];
}

- (NSUInteger)findStartDepthIndex:(NSUInteger)start arr:(NSArray *)arr
{
    NSUInteger index = start;
    if (arr.count > index) {
        YSRecordModel *model = arr[index];
        int minDepth = model.depth;
        int minTotal = model.total;
        for (NSUInteger i = index+1; i < arr.count; i++) {
            YSRecordModel *tmp = arr[i];
            if (tmp.depth < minDepth || (tmp.depth == minDepth && tmp.total < minTotal)) {
                minDepth = tmp.depth;
                minTotal = tmp.total;
                index = i;
            }
        }
    }
    return index;
}

- (NSArray *)recursive_getRecord:(NSMutableArray *)arr
{
    if ([arr isKindOfClass:NSArray.class] && arr.count > 0) {
        BOOL isValid = YES;
        NSMutableArray *recordArr = [NSMutableArray array];
        NSMutableArray *splitArr = [NSMutableArray array];
        NSUInteger index = [self findStartDepthIndex:0 arr:arr];
        if (index > 0) {
            [splitArr addObject:[NSMutableArray array]];
            for (int i = 0; i < index; i++) {
                [[splitArr lastObject] addObject:arr[i]];
            }
        }
        YSRecordModel *model = arr[index];
        [recordArr addObject:model];
        [arr removeObjectAtIndex:index];
        int startDepth = model.depth;
        int startTotal = model.total;
        for (NSUInteger i = index; i < arr.count; ) {
            model = arr[i];
            if (model.total == startTotal && model.depth-1==startDepth) {
                [recordArr addObject:model];
                [arr removeObjectAtIndex:i];
                startDepth++;
                isValid = YES;
            }
            else
            {
                if (isValid) {
                    isValid = NO;
                    [splitArr addObject:[NSMutableArray array]];
                }
                [[splitArr lastObject] addObject:model];
                i++;
            }
            
        }
        
        for (NSUInteger i = splitArr.count; i > 0; i--) {
            NSMutableArray *sArr = splitArr[i-1];
            [recordArr addObjectsFromArray:[self recursive_getRecord:sArr]];
        }
        return recordArr;
    }
    return @[];
}

- (void)setRecordDic:(NSMutableArray *)arr record:(YSCallRecord *)record
{
    if ([arr isKindOfClass:NSMutableArray.class] && record) {
        int total=1;
        for (NSUInteger i = 0; i < arr.count; i++)
        {
            YSRecordModel *model = arr[i];
            if (model.depth == record->depth) {
                total = model.total+1;
                break;
            }
        }
        
        YSRecordModel *model = [[YSRecordModel alloc] initWithCls:record->cls sel:record->sel time:record->costTime depth:record->depth total:total];
        [arr insertObject:model atIndex:0];
    }
}

- (void)stopAndGetCallRecord
{
    stopTrace();
    YSMainThreadCallRecord *mainThreadCallRecord = getMainThreadCallRecord();
    if (mainThreadCallRecord==NULL) {
        NSLog(@"=====================================");
        NSLog(@"没有调用startTrace()函数");
        NSLog(@"请看下用法：https://github.com/andyccc/YSTimeProfiler");
        NSLog(@"=====================================");
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableString *textM = [[NSMutableString alloc] init];
        NSMutableArray *allMethodRecord = [NSMutableArray array];
        int i = 0, j;
        while (i <= mainThreadCallRecord->index) {
            NSMutableArray *methodRecord = [NSMutableArray array];
            for (j = i; j <= mainThreadCallRecord->index;j++)
            {
                YSCallRecord *callRecord = &mainThreadCallRecord->record[j];
                NSString *str = [self debug_getMethodCallStr:callRecord];
                [textM appendString:str];
                [textM appendString:@"\r"];
                [self setRecordDic:methodRecord record:callRecord];
                if (callRecord->depth==0 || j==mainThreadCallRecord->index)
                {
                    NSArray *recordModelArr = [self recursive_getRecord:methodRecord];
                    YSRecordHierarchyModel *model = [[YSRecordHierarchyModel alloc] initWithRecordModelArr:recordModelArr];
                    [allMethodRecord addObject:model];
                    //退出循环
                    break;
                }
            }
            
            i = j+1;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sequentialMethodRecord = [[NSArray alloc] initWithArray:allMethodRecord copyItems:YES];
            self.tableType = tableTypeSequential;
            self.RecordBtn.hidden = NO;
            [self clickRecordBtn];
        });
        [self sortCostTimeRecord:[[NSArray alloc] initWithArray:allMethodRecord copyItems:YES]];
        [self sortCallCountRecord:[[NSArray alloc] initWithArray:allMethodRecord copyItems:YES]];
        [self debug_printMethodRecord:textM];
    });
}

- (void)debug_printMethodRecord:(NSString *)text
{
    //记录的顺序是方法完成时间
    NSLog(@"=========printMethodRecord==Start================");
    NSLog(@"%@", text);
    NSLog(@"=========printMethodRecord==End================");
}

- (NSString *)debug_getMethodCallStr:(YSCallRecord *)callRecord
{
    NSMutableString *str = [[NSMutableString alloc] init];
    double ms = callRecord->costTime/1000.0;
    [str appendString:[NSString stringWithFormat:@"　%d　|　%lgms　|　", callRecord->depth, ms]];
    if (callRecord->depth>0) {
        [str appendString:[[NSString string] stringByPaddingToLength:callRecord->depth withString:@"　" startingAtIndex:0]];
    }
    if (class_isMetaClass(callRecord->cls))
    {
        [str appendString:@"+"];
    }
    else
    {
        [str appendString:@"-"];
    }
    [str appendString:[NSString stringWithFormat:@"[%@　　%@]", NSStringFromClass(callRecord->cls), NSStringFromSelector(callRecord->sel)]];
    return str.copy;
}

- (void)sortCostTimeRecord:(NSArray *)arr
{
    NSArray *sortArr = [arr sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        YSRecordHierarchyModel *model1 = (YSRecordHierarchyModel *)obj1;
        YSRecordHierarchyModel *model2 = (YSRecordHierarchyModel *)obj2;
        if (model1.rootMethod.costTime > model2.rootMethod.costTime) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    for (YSRecordHierarchyModel *model in sortArr) {
        model.isExpand = NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.costTimeSortMethodRecord = sortArr;
        self.costTimeSortBtn.hidden = NO;
    });
}

- (void)arrAddRecord:(YSRecordModel *)model arr:(NSMutableArray *)arr
{
    for (int i = 0; i < arr.count; i++) {
        YSRecordModel *temp = arr[i];
        if ([temp isEqualRecordModel:model]) {
            temp.callCount++;
            return;
        }
    }
    model.callCount = 1;
    [arr addObject:model];
}

- (void)sortCallCountRecord:(NSArray *)arr
{
    NSMutableArray *arrM = [NSMutableArray array];
    for (YSRecordHierarchyModel *model in arr) {
        [self arrAddRecord:model.rootMethod arr:arrM];
        if ([model.subMethods isKindOfClass:NSArray.class]) {
            for (YSRecordModel *recoreModel in model.subMethods) {
                [self arrAddRecord:recoreModel arr:arrM];
            }
        }
    }
    
    NSArray *sortArr = [arrM sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        YSRecordModel *model1 = (YSRecordModel *)obj1;
        YSRecordModel *model2 = (YSRecordModel *)obj2;
        if (model1.callCount > model2.callCount) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.callCountSortMethodRecord = sortArr;
        self.callCountSortBtn.hidden = NO;
    });
}

- (void)clickPopVCBtn:(UIButton *)btn
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - YSRecordCellDelegate

- (void)recordCell:(YSRecordCell *)cell clickExpandWithSection:(NSInteger)section
{
    NSIndexSet *indexSet;
    YSRecordHierarchyModel *model;
    switch (self.tableType) {
        case tableTypeSequential:
            model = self.sequentialMethodRecord[section];
            break;
        case tableTypecostTime:
            model = self.costTimeSortMethodRecord[section];
            break;
            
        default:
            break;
    }
    model.isExpand = !model.isExpand;
    indexSet=[[NSIndexSet alloc] initWithIndex:section];
    [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.tableType == tableTypeSequential) {
        return self.sequentialMethodRecord.count;
    }
    else if (self.tableType == tableTypecostTime)
    {
        return self.costTimeSortMethodRecord.count;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.tableType == tableTypeSequential) {
        YSRecordHierarchyModel *model = self.sequentialMethodRecord[section];
        if (model.isExpand && [model.subMethods isKindOfClass:NSArray.class]) {
            return model.subMethods.count+1;
        }
    }
    else if (self.tableType == tableTypecostTime)
    {
        YSRecordHierarchyModel *model = self.costTimeSortMethodRecord[section];
        if (model.isExpand && [model.subMethods isKindOfClass:NSArray.class]) {
            return model.subMethods.count+1;
        }
    }
    else
    {
        return self.callCountSortMethodRecord.count;
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *YSRecordCell_reuseIdentifier = @"YSRecordCell_reuseIdentifier";
    YSRecordCell *cell = [tableView dequeueReusableCellWithIdentifier:YSRecordCell_reuseIdentifier];
    if (!cell) {
        cell = [[YSRecordCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:YSRecordCell_reuseIdentifier];
    }
    YSRecordHierarchyModel *model;
    YSRecordModel *recordModel;
    BOOL isShowExpandBtn;
    switch (self.tableType) {
        case tableTypeSequential:
            model = self.sequentialMethodRecord[indexPath.section];
            recordModel = [model getRecordModel:indexPath.row];
            isShowExpandBtn = indexPath.row == 0 && [model.subMethods isKindOfClass:NSArray.class] && model.subMethods.count > 0;
            cell.delegate = self;
            [cell bindRecordModel:recordModel isHiddenExpandBtn:!isShowExpandBtn isExpand:model.isExpand section:indexPath.section isCallCountType:NO];
            break;
        case tableTypecostTime:
            model = self.costTimeSortMethodRecord[indexPath.section];
            recordModel = [model getRecordModel:indexPath.row];
            isShowExpandBtn = indexPath.row == 0 && [model.subMethods isKindOfClass:NSArray.class] && model.subMethods.count > 0;
            cell.delegate = self;
            [cell bindRecordModel:recordModel isHiddenExpandBtn:!isShowExpandBtn isExpand:model.isExpand section:indexPath.section isCallCountType:NO];
            break;
        case tableTypeCallCount:
            recordModel = self.callCountSortMethodRecord[indexPath.row];
            [cell bindRecordModel:recordModel isHiddenExpandBtn:YES isExpand:YES section:indexPath.section isCallCountType:YES];
            break;
            
        default:
            break;
    }
    return cell;
}

#pragma mark - Btn click method

- (void)clickRecordBtn
{
    self.costTimeSortBtn.selected = NO;
    self.callCountSortBtn.selected = NO;
    if (!self.RecordBtn.selected) {
        self.RecordBtn.selected = YES;
        self.tableType = tableTypeSequential;
        [self.tableView reloadData];
    }
}

- (void)clickCostTimeSortBtn
{
    self.RecordBtn.selected = NO;
    self.callCountSortBtn.selected = NO;
    if (!self.costTimeSortBtn.selected) {
        self.costTimeSortBtn.selected = YES;
        self.tableType = tableTypecostTime;
        [self.tableView reloadData];
    }
}

- (void)clickCallCountSortBtn
{
    self.costTimeSortBtn.selected = NO;
    self.RecordBtn.selected = NO;
    if (!self.callCountSortBtn.selected) {
        self.callCountSortBtn.selected = YES;
        self.tableType = tableTypeCallCount;
        [self.tableView reloadData];
    }
}


#pragma mark - get&set method

- (UIScrollView *)scrollView
{
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, YSHeaderHight, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-YSHeaderHight)];
        _scrollView.showsHorizontalScrollIndicator = YES;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.contentSize = CGSizeMake(YSScrollWidth, 0);
    }
    return _scrollView;
}

- (UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 30, YSScrollWidth, [UIScreen mainScreen].bounds.size.height-YSHeaderHight-30) style:UITableViewStylePlain];
        _tableView.bounces = NO;
        _tableView.dataSource = self;
        _tableView.rowHeight = 18;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _tableView;
}

- (UIButton *)getYSBtnWithFrame:(CGRect)rect title:(NSString *)title sel:(SEL)sel
{
    UIButton *btn = [[UIButton alloc] initWithFrame:rect];
    btn.layer.cornerRadius = 2;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [UIColor blackColor].CGColor;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setBackgroundImage:[self imageWithColor:[UIColor colorWithRed:127/255.0 green:179/255.0 blue:219/255.0 alpha:1]] forState:UIControlStateSelected];
    btn.titleLabel.font = [UIFont systemFontOfSize:10];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (UIImage *)imageWithColor:(UIColor *)color{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
}

- (UIButton *)RecordBtn
{
    if (!_RecordBtn) {
        _RecordBtn = [self getYSBtnWithFrame:CGRectMake(5, 65, 60, 30) title:@"调用时间" sel:@selector(clickRecordBtn)];
        _RecordBtn.hidden = YES;
    }
    return _RecordBtn;
}

- (UIButton *)costTimeSortBtn
{
    if (!_costTimeSortBtn) {
        _costTimeSortBtn = [self getYSBtnWithFrame:CGRectMake(70, 65, 60, 30) title:@"最耗时" sel:@selector(clickCostTimeSortBtn)];
        _costTimeSortBtn.hidden = YES;
    }
    return _costTimeSortBtn;
}

- (UIButton *)callCountSortBtn
{
    if (!_callCountSortBtn) {
        _callCountSortBtn = [self getYSBtnWithFrame:CGRectMake(135, 65, 60, 30) title:@"调用次数" sel:@selector(clickCallCountSortBtn)];
        _callCountSortBtn.hidden = YES;
    }
    return _callCountSortBtn;
}

- (UIButton *)popVCBtn
{
    if (!_popVCBtn) {
        _popVCBtn = [self getYSBtnWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width-50, 65, 40, 30) title:@"关闭" sel:@selector(clickPopVCBtn:)];
    }
    return _popVCBtn;
}

- (UILabel *)tableHeaderViewLabel
{
    if (!_tableHeaderViewLabel) {
        _tableHeaderViewLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, YSScrollWidth, 30)];
        _tableHeaderViewLabel.font = [UIFont systemFontOfSize:15];
        _tableHeaderViewLabel.backgroundColor = [UIColor colorWithRed:219.0/255 green:219.0/255 blue:219.0/255 alpha:1];
    }
    return _tableHeaderViewLabel;
}

- (void)settableType:(YSTableType)tableType
{
    if (_tableType!=tableType) {
        if (tableType==tableTypeCallCount) {
            self.tableHeaderViewLabel.text = @"深度       耗时      次数            方法名";
        }
        else
        {
            self.tableHeaderViewLabel.text = @"深度       耗时                  方法名";
        }
        _tableType = tableType;
    }
}

@end
