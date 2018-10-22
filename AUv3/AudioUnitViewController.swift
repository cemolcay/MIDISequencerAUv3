//
//  AudioUnitViewController.swift
//  AUv3
//
//  Created by Cem Olcay on 10.09.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import CoreAudioKit
import MusicTheorySwift
import MIDIEventKit

struct SequencerStepData {
  enum NoteData {
    case rest
    case pitch(Pitch)
    case chord(Chord)
  }

  var note = NoteData.pitch("c4")
  var rate = NoteValue(type: .quarter)
  var gate = 1.0
  var pitch = 0.0
  var mod = 0.0
}

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
  var audioUnit: AUAudioUnit?
  var parameterObserverToken: AUParameterObserverToken?

  var sequencerData = [SequencerStepData]()
  @IBOutlet weak var noteValueSegment: UISegmentedControl?

  public override func viewDidLoad() {
    super.viewDidLoad()

    if audioUnit == nil {
      return
    }
  }

  @IBAction func noteValueSegmentDidChange(sender: UISegmentedControl) {
    guard let audioUnit = audioUnit as? AUv3AudioUnit else { return }
    audioUnit.beatRateIndex.objectValue = NSNumber(value: sender.selectedSegmentIndex)
  }

  public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    audioUnit = try AUv3AudioUnit(componentDescription: componentDescription, options: [])
    guard let audioUnit = audioUnit as? AUv3AudioUnit else { return self.audioUnit! }

    return audioUnit
  }
}
