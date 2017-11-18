//
//  YSViewController.m
//  YSTimeProfiler
//
//  Created by yans on 2017/11/18.
//

#import "YSViewController.h"
#import "YSCallTrace.h"

@interface YSViewController ()

@end

@implementation YSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    startTrace();
    
    [self test];
    
}

- (void)test
{
    NSLog(@"begin");
    sleep(1);
    NSLog(@"end");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
