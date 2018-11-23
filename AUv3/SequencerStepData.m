//
//  SequencerStepData.m
//  AUv3
//
//  Created by Cem Olcay on 23.10.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

#import "SequencerStepData.h"

@implementation SequencerStepData

- (instancetype)init {
  return [self initWithMidiNote:60
                       velocity:90
                     modulation:0
                      picthBend:8192
                      isEnabled:true];
}

- (instancetype)initWithMidiNote:(uint8_t)midiNote {
  return [self initWithMidiNote:midiNote
                       velocity:90
                     modulation:0
                      picthBend:8192
                      isEnabled:true];
}

- (instancetype)initWithMidiNote:(uint8_t)midiNote velocity:(uint8_t)velocity modulation:(uint8_t)modulation picthBend:(uint16_t)pitchBend isEnabled:(bool)isEnabled {
  if ((self = [super init])) {
    self.midiNote = midiNote;
    self.velocity = velocity;
    self.modulation = modulation;
    self.pitchBend = pitchBend;
    self.isEnabled = isEnabled;
  }

  return self;
}

@end
