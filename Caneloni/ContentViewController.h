//
//  ContentViewController.h
//  Caneloni
//
//  Created by Antonio Marques on 11/03/15.
//  Copyright (c) 2015 Antonio Marques. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ContentViewController : UITableViewController

@property (nonatomic) BOOL processing;
@property (nonatomic) BOOL stopWhenPossible;

@property (weak, nonatomic) IBOutlet UILabel* vUnprocessed;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView* vProcessing;

@property (weak, nonatomic) IBOutlet UILabel* vCurrentFile;
@property (weak, nonatomic) IBOutlet UILabel* vLastFile;
@property (weak, nonatomic) IBOutlet UILabel* vLocation;
@property (weak, nonatomic) IBOutlet UILabel* vSaved;
@property (weak, nonatomic) IBOutlet UILabel* vDeleted;

@property (weak, nonatomic) IBOutlet UIButton* vProcess;
@property (weak, nonatomic) IBOutlet UIButton* vLog;

- (IBAction) didTapProcess:(id)sender;
- (IBAction) didTapLog:(id)sender;

@end
