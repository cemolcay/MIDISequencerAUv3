//
//  AUv3AudioUnit.h
//  AUv3
//
//  Created by Cem Olcay on 10.09.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "AEArray.h"
#import "AEManagedValue.h"

@interface AUv3AudioUnit : AUAudioUnit

@property (nonatomic, retain) AEArray *sequencer;
@property (nonatomic, retain) AEManagedValue *sequencerStepIndex;
@property (nonatomic, retain) AEManagedValue *beatRateIndex;
@property (nonatomic, retain) AEManagedValue *arpeggiatorTypeIndex;

@end
