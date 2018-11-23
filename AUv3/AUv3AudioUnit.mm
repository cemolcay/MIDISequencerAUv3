//
//  AUv3AudioUnit.m
//  AUv3
//
//  Created by Cem Olcay on 10.09.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

#import "AUv3AudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import "SequencerStepData.h"
#include "vector"

#define PLAYING_NOTE_CAPACITY 100

typedef struct PlayingNote {
  uint8_t midiNote;
  double stopingBeatPosition;
}PlayingNote;

@interface AUv3AudioUnit ()
@property (nonatomic, readwrite) AUParameterTree *parameterTree;
@property AUAudioUnitBus *inputBus;
@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;
@end

@implementation AUv3AudioUnit {
  AUAudioUnitPreset *_currentPreset;
  NSInteger _currentFactoryPresetIndex;
  NSArray<AUAudioUnitPreset *> *_presets;

  bool isPlaying;
  double nextBeatPosition;

  std::vector<PlayingNote> playingNotes;
  std::vector<PlayingNote> stopingNotes;
}

@synthesize factoryPresets = _presets;
@synthesize parameterTree = _parameterTree;
@synthesize inputBus = _inputBus;
@synthesize outputBus = _outputBus;
@synthesize inputBusArray = _inputBusArray;
@synthesize outputBusArray = _outputBusArray;

AudioStreamBasicDescription asbd;
AUHostMusicalContextBlock _musicalContext;
AUMIDIOutputEventBlock _outputEventBlock;
AUHostTransportStateBlock _transportStateBlock;
AUScheduleMIDIEventBlock _scheduleMIDIEventBlock;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
  self = [super initWithComponentDescription:componentDescription options:options error:outError];

  if (self == nil) {
    return nil;
  }

  isPlaying = false;
  nextBeatPosition = 0;

  self.sequencer = [[AEArray alloc] init];
  [self.sequencer updateWithContentsOfArray:@[
    [[SequencerStepData alloc] initWithMidiNote:60],
    [[SequencerStepData alloc] initWithMidiNote:64],
    [[SequencerStepData alloc] initWithMidiNote:67],
    [[SequencerStepData alloc] initWithMidiNote:70],
  ]];

  self.sequencerStepIndex = [[AEManagedValue alloc] init];
  self.sequencerStepIndex.objectValue = @0;

  self.beatRateIndex = [[AEManagedValue alloc] init];
  self.beatRateIndex.objectValue = @0;

  playingNotes.reserve(PLAYING_NOTE_CAPACITY);
  stopingNotes.reserve(PLAYING_NOTE_CAPACITY);

  [self createParameterTree];
  [self createBusses];
  return self;
}

- (void)createBusses {
  AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
  asbd = *defaultFormat.streamDescription;

  _inputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
  _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];

  // Create the input and output bus arrays.
  _inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses: @[_inputBus]];
  _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];

  self.maximumFramesToRender = 512;
}

- (void)createParameterTree {
  _parameterTree = [AUParameterTree createTreeWithChildren:@[]];

  // A function to provide string representations of parameter values.
  _parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
    switch (param.address) {
      default:
        return @"?";
    }
  };
}

#pragma mark - AUAudioUnit Overrides

// If an audio unit has input, an audio unit's audio input connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)inputBusses {
  return _inputBusArray;
}

// An audio unit's audio output connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)outputBusses {
  return _outputBusArray;
}

// Allocate resources required to render.
// Subclassers should call the superclass implementation.
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
  if (![super allocateRenderResourcesAndReturnError:outError]) {
    return NO;
  }

  if (self.musicalContextBlock) {
    _musicalContext = self.musicalContextBlock;
  }

  if (self.MIDIOutputEventBlock) {
    _outputEventBlock = self.MIDIOutputEventBlock;
  }

  if (self.transportStateBlock) {
    _transportStateBlock = self.transportStateBlock;
  }

  if (self.scheduleMIDIEventBlock) {
    _scheduleMIDIEventBlock = self.scheduleMIDIEventBlock;
  }

  return YES;
}

// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources {
  // Deallocate your resources.
  [super deallocateRenderResources];
  _transportStateBlock = nil;
  _outputEventBlock = nil;
  _musicalContext = nil;
  _scheduleMIDIEventBlock = nil;
}

- (NSArray<NSString *>*)MIDIOutputNames {
  return @[@"BasicSequencer MIDI Out"];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)


/**
 Calculates the beat rate according the index of the beat rate array.

 @param index Index number of the beat rate in beat rate array.
 @return Beat rate value in double.
 */
double getBeatRate(int index) {
  switch (index) {
    case 0:
      return 1.0 * 4.0;
    case 1:
      return 1.0/2.0 * 4.0;
    case 2:
      return 1.0/4.0 * 4.0;
    case 3:
      return 1.0/8.0 * 4.0;
    case 4:
      return 1.0/16.0 * 4.0;
    default:
      return 1.0 * 4.0;
  }
}

/// Block which subclassers must provide to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
  // AU event block refs.
  __block AUHostMusicalContextBlock musicalContextCapture = self.musicalContextBlock;
  __block AUMIDIOutputEventBlock midiOutputCapture = self.MIDIOutputEventBlock;;
  __block AUHostTransportStateBlock transportStateCapture = self.transportStateBlock;

  // Sequencer refs.
  __block AEArray *_sequencer = self.sequencer;
  __block AEManagedValue *_sequencerStepIndex = self.sequencerStepIndex;
  __block AEManagedValue *_beatRateIndex = self.beatRateIndex;
  __block bool _isPlaying = isPlaying;
  __block double _nextBeatPosition = nextBeatPosition;

  // MIDI note refs.
  __block std::vector<PlayingNote> _playingNotes = playingNotes;
  __block std::vector<PlayingNote> _stopingNotes = stopingNotes;

  // DSP
  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList *outputData, const AURenderEvent *realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {

    // Check AUv3 support.
    if (midiOutputCapture == NULL || transportStateCapture == NULL || musicalContextCapture == NULL) {
      return noErr;
    }

    // Get the musical context.
    double currentTempo;
    double currentBeatPosition;
    NSInteger timeSignatureDenominator;
    if (musicalContextCapture(&currentTempo, NULL, &timeSignatureDenominator, &currentBeatPosition, NULL, NULL) == false) {
      return noErr;
    }

    // Check if it is playing.
    AUHostTransportStateFlags transportStateFlags;
    if (transportStateCapture(&transportStateFlags, NULL, NULL, NULL)) {
      // Check if transport moving.
      if ((transportStateFlags & AUHostTransportStateMoving) != AUHostTransportStateMoving) {
        // Stop sequencer.
        for (int i = 0; i < _playingNotes.size(); i++) {
          PlayingNote note = _playingNotes[i];
          uint8_t midi[3];
          midi[0] = 0x80;
          midi[1] = note.midiNote;
          midi[2] = 0;
          midiOutputCapture(AUEventSampleTimeImmediate, 0, 3, midi);
        }

        // Reset playing notes array.
        if (_playingNotes.size() > 0) {
          _playingNotes.clear();
        }

        if (_stopingNotes.size() > 0) {
          _stopingNotes.clear();
        }

        // Transport not moving, exit.
        _isPlaying = false;
        return noErr;
      } else { // Transport is moving.
        if (_isPlaying == false) {
          // Set next beat position.
          double beatRate = getBeatRate([(NSNumber *)_beatRateIndex.objectValue intValue]);
          _nextBeatPosition = currentBeatPosition == 0 ? 0 : currentBeatPosition + beatRate;
          _sequencerStepIndex.objectValue = [NSNumber numberWithInt:currentBeatPosition == 0 ? 0 : currentBeatPosition];
          _isPlaying = true;
        }
      }
    } else {
      return noErr;
    }

    // Check if any playing note needs to stopped.
    for (int i = 0; i < _playingNotes.size(); i++) {
      if (_playingNotes[i].stopingBeatPosition <= currentBeatPosition) {
        PlayingNote note = _playingNotes[i];
        _stopingNotes.push_back(note);
      }
    }

    // Check the stoping notes.
    if (_stopingNotes.size() > 0) {
      for (int i = 0; i < _stopingNotes.size(); i++) {
        // Stop the note.
        PlayingNote note = _stopingNotes[i];
        uint8_t noteOff[3];
        noteOff[0] = 0x80;
        noteOff[1] = note.midiNote;
        noteOff[2] = 0;
        midiOutputCapture(AUEventSampleTimeImmediate, 0, 3, noteOff);
        // Remove it from the playing notes array.
        int playingNoteIndex = -1;
        for (int i = 0; i < _playingNotes.size(); i++) {
          if (_playingNotes[i].midiNote == note.midiNote && _playingNotes[i].stopingBeatPosition == note.stopingBeatPosition) {
            playingNoteIndex = i;
            break;
          }
        }
        if (playingNoteIndex > -1) {
          _playingNotes.erase(_playingNotes.begin() + playingNoteIndex);
        }
      }

      // Clear stoping notes array after we stop each one.
      _stopingNotes.clear();
    }

    // Check if we hit the next playing beat.
    if (currentBeatPosition < _nextBeatPosition) {
      return noErr;
    }

    // Play the beat.
    int stepIndex = [(NSNumber *)_sequencerStepIndex.objectValue intValue];
    SequencerStepData *stepData = (__bridge  SequencerStepData*)AEArrayGetItem(AEArrayGetToken(_sequencer), stepIndex);

    // note on
    uint8_t noteOn[3];
    noteOn[0] = 0x90;
    noteOn[1] = stepData.midiNote;
    noteOn[2] = stepData.velocity;
    midiOutputCapture(AUEventSampleTimeImmediate, 0, 3, noteOn);

    // modulation
    uint8_t modulation[3];
    modulation[0] = 176; // CC
    modulation[1] = 1; // MOD Wheel
    modulation[2] = stepData.modulation; // MOD value
    midiOutputCapture(AUEventSampleTimeImmediate, 0, 3, modulation);

    // pitch bend
    uint8_t pitchBend[3];
    uint8_t lsb = (uint8_t)(stepData.pitchBend & 0xFF);
    uint8_t msb = (uint8_t)((stepData.pitchBend >> 8) & 0xFF);
    pitchBend[0] = 224;
    pitchBend[1] = lsb;
    pitchBend[2] = msb;
    midiOutputCapture(AUEventSampleTimeImmediate, 0, 3, pitchBend);

    // Step forward.
    double beatRate = getBeatRate([(NSNumber *)_beatRateIndex.objectValue intValue]);
    _nextBeatPosition = currentBeatPosition + beatRate;
    stepIndex++;
    if (stepIndex >= AEArrayGetCount(AEArrayGetToken(_sequencer))) {
      stepIndex = 0;
    }
    _sequencerStepIndex.objectValue = [NSNumber numberWithInt:stepIndex];

    // Craete playing note data.
    PlayingNote playingNote;
    playingNote.midiNote = stepData.midiNote;
    playingNote.stopingBeatPosition = _nextBeatPosition;
    _playingNotes.push_back(playingNote);

    return noErr;
  }; // end of the render block.
}

@end
