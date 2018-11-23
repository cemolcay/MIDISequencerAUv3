//
//  SequencerStepData.h
//  AUv3
//
//  Created by Cem Olcay on 23.10.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SequencerStepData : NSObject
@property (nonatomic, assign) uint8_t midiNote;
@property (nonatomic, assign) uint8_t velocity;
@property (nonatomic, assign) uint8_t modulation;
@property (nonatomic, assign) uint16_t pitchBend;
@property (nonatomic, assign) bool isEnabled;

- (instancetype)init;
- (instancetype)initWithMidiNote:(uint8_t)midiNote;
- (instancetype)initWithMidiNote:(uint8_t)midiNote velocity:(uint8_t)velocity modulation:(uint8_t)modulation picthBend:(uint16_t)pitchBend isEnabled:(bool)isEnabled;

@end

NS_ASSUME_NONNULL_END
