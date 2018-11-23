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
import LiveKnob

// MARK: - Data Types

enum StepPropertyType {
  case pitch
  case velocity
  case modulation
  case pitchBend

  static let all: [StepPropertyType] = [.pitch, .velocity, .modulation, .pitchBend]

  var range: ClosedRange<Int> {
    switch self {
    case .pitchBend: return 0...16383
    default: return 0...127
    }
  }

  func knobValue(for index: Int) -> Float {
    return convert(
      value: Float(index),
      inRange: Float(range.min() ?? 0)...Float(range.max() ?? 0),
      toRange: 0.0...1.0)
  }

  func itemValue(for knobValue: Float) -> Int {
    let value = convert(
      value: knobValue,
      inRange: 0.0...1.0,
      toRange: Float(range.min() ?? 0)...Float(range.max() ?? 0))
    return Int(value)
  }
}

enum SequencerArpeggioType: Int {
  case up
  case down
  case updown
  case random

  static let all: [SequencerArpeggioType] = [.up, .down, .updown, .random]
}

enum SequencerRateType: Int {
  case whole
  case half
  case quarter
  case eighth

  static let all: [SequencerRateType] = [.whole, .half, .quarter, .eighth]

  var rate: NoteValue {
    switch self {
    case .whole: return NoteValue(type: .whole, modifier: .default)
    case .half: return NoteValue(type: .half, modifier: .default)
    case .quarter: return NoteValue(type: .quarter, modifier: .default)
    case .eighth: return NoteValue(type: .eighth, modifier: .default)
    }
  }
}

struct SequencerData {
  var steps = [SequencerStepData]()
  var rate = SequencerRateType.quarter
  var arpeggioType = SequencerArpeggioType.up

  func update(audioUnit: AUv3AudioUnit) {
    audioUnit.sequencer?.update(withContentsOf: steps)
    audioUnit.beatRateIndex.objectValue = NSNumber(value: rate.rawValue)
    audioUnit.arpeggiatorTypeIndex.objectValue = NSNumber(value: arpeggioType.rawValue)
  }
}

protocol StepPropertyManagerDelegate: class {
  func stepPropertyManager(_ stepPropertyManager: StepPropertyManager, didSelect button: StepPropertyButton, at index: Int)
}

class StepPropertyManager {
  var buttons: [StepPropertyButton]
  var selectedButtonIndex: Int
  weak var delegate: StepPropertyManagerDelegate?

  init(buttons: [StepPropertyButton], selectedButtonIndex: Int) {
    self.buttons = buttons
    self.selectedButtonIndex = selectedButtonIndex

    for (index, button) in buttons.enumerated() {
      button.isSelected = index == selectedButtonIndex
      button.addTarget(self, action: #selector(didPressButton(sender:)), for: .touchUpInside)
    }
  }

  @objc func didPressButton(sender: StepPropertyButton) {
    for (index, button) in buttons.enumerated() {
      if button == sender {
        selectedButtonIndex = index
        button.isSelected = true
      } else {
        button.isSelected = false
      }
    }
    delegate?.stepPropertyManager(self, didSelect: sender, at: selectedButtonIndex)
  }
}

// MARK: - Views

class StepPropertyButton: UIButton { }

@IBDesignable class LedView: UIView {
  @IBInspectable var onColor: UIColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
  @IBInspectable var offColor: UIColor = #colorLiteral(red: 0.3176470697, green: 0.07450980693, blue: 0.02745098062, alpha: 1)

  var isOn = false {
    didSet {
      backgroundColor = isOn ? onColor : offColor
    }
  }
}

protocol SequencerStepCellDelegate: class {
  func sequencerStepCellDidToggle(_ sequencerStepCell: SequencerStepCell)
  func sequencerStepCell(_ sequencerStepCell: SequencerStepCell, didChange value: Double)
  func sequencerStepCellLabel(_ sequencerStepCell: SequencerStepCell, for value: Double) -> String
}

@IBDesignable class SequencerStepCell: UICollectionViewCell {
  static let cellReuseIdentifier = "sequencerStepCell"
  weak var delegate: SequencerStepCellDelegate?

  @IBOutlet var stepView: UIView?
  @IBOutlet var ledView: LedView?
  @IBOutlet var valueLabel: UILabel?
  @IBOutlet var knob: LiveKnob?

  @IBInspectable var enabledColor: UIColor = #colorLiteral(red: 0.9166453481, green: 0.8375994563, blue: 0.02345943265, alpha: 1)
  @IBInspectable var disabledColor: UIColor = #colorLiteral(red: 0.5058823824, green: 0.3372549117, blue: 0.06666667014, alpha: 1)

  override func prepareForReuse() {
    isEnabled = true
    ledView?.isOn = false
    valueLabel?.text = ""

    layer.cornerRadius = 8
    ledView?.layer.cornerRadius = (ledView?.frame.size.width ?? 2) / 2.0
  }

  var isEnabled = true {
    didSet {
      stepView?.backgroundColor = isEnabled ? enabledColor : disabledColor
    }
  }

  @objc func didTap(gestureRecognizer: UITapGestureRecognizer) {
    isEnabled = !isEnabled
    delegate?.sequencerStepCellDidToggle(self)
  }

  @IBAction func valueChange(sender: LiveKnob) {
    valueLabel?.text = delegate?.sequencerStepCellLabel(self, for: Double(sender.value)) ?? ""
    delegate?.sequencerStepCell(self, didChange: Double(sender.value))
  }

  // Something between 0.0 - 1.0
  func updateCell(for value: Float) {
    valueLabel?.text = delegate?.sequencerStepCellLabel(self, for: Double(value)) ?? ""
    knob?.value = value
  }
}

protocol AddRemoveStepCellDelegate: class {
  func addRemoveStepCellDidPressAddButton(_ addRemoveStepCell: AddRemoveStepCell)
  func addRemoveStepCellDidPressRemoveButton(_ addRemoveStepCell: AddRemoveStepCell)
}

class AddRemoveStepCell: UICollectionViewCell {
  static let cellReuseIdentifier = "addRemoveStepCell"
  weak var delegate: AddRemoveStepCellDelegate?

  @IBAction func addButtonPressed(sender: UIButton) {
    delegate?.addRemoveStepCellDidPressAddButton(self)
  }

  @IBAction func removeButtonPressed(sender: UIButton) {
    delegate?.addRemoveStepCellDidPressRemoveButton(self)
  }
}

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, AddRemoveStepCellDelegate, SequencerStepCellDelegate, StepPropertyManagerDelegate {
  var audioUnit: AUAudioUnit?
  var parameterObserverToken: AUParameterObserverToken?

  @IBOutlet weak var noteValueSegment: UISegmentedControl?
  @IBOutlet weak var stepCollectionView: UICollectionView?

  @IBOutlet weak var pitchStepPropertyButton: StepPropertyButton?
  @IBOutlet weak var volumeStepPropertyButton: StepPropertyButton?
  @IBOutlet weak var modulationStepPropertyButton: StepPropertyButton?
  @IBOutlet weak var pitchBendStepPropertyButton: StepPropertyButton?
  var stepPropertyManager: StepPropertyManager!

  var sequencerDataSource: [SequencerStepData] {
    get {
      return (audioUnit as? AUv3AudioUnit)?.sequencer.allValues as? [SequencerStepData] ?? []
    } set {
      (audioUnit as? AUv3AudioUnit)?.sequencer.update(withContentsOf: newValue)
    }
  }

  // MARK: Lifecycle

  public override func viewDidLoad() {
    super.viewDidLoad()
    stepCollectionView?.delaysContentTouches = false
    stepPropertyManager = StepPropertyManager(
      buttons: [
        pitchStepPropertyButton,
        volumeStepPropertyButton,
        modulationStepPropertyButton,
        pitchBendStepPropertyButton,
      ].compactMap({ $0 }),
      selectedButtonIndex: 0)

    if audioUnit == nil {
      return
    }
  }

  public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    audioUnit = try AUv3AudioUnit(componentDescription: componentDescription, options: [])
    guard let audioUnit = audioUnit as? AUv3AudioUnit else { return self.audioUnit! }

    return audioUnit
  }

  // MARK: Actions

  @IBAction func noteValueSegmentDidChange(sender: UISegmentedControl) {
    guard let audioUnit = audioUnit as? AUv3AudioUnit else { return }
    audioUnit.beatRateIndex.objectValue = NSNumber(value: sender.selectedSegmentIndex)
  }

  // MARK: UICollectionViewDataSource

  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return sequencerDataSource.count + 1 // plus one for addRemoveStepCell
  }

  public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if indexPath.item == sequencerDataSource.count {
      guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddRemoveStepCell.cellReuseIdentifier, for: indexPath) as? AddRemoveStepCell else { fatalError() }
      cell.delegate = self
      return cell
    }

    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SequencerStepCell.cellReuseIdentifier, for: indexPath) as? SequencerStepCell else { fatalError() }
    cell.updateCell(for: knobValue(itemAt: indexPath.item))
    cell.delegate = self
    return cell
  }

  // MARK: UICollectionViewDelegateFlowLayout

  private func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let height = min(collectionView.frame.size.height, 150)
    let width: CGFloat = height * 90 / 200
    return CGSize(width: width, height: height)
  }

  // MARK: AddRemoveStepCellDelegate

  func addRemoveStepCellDidPressAddButton(_ addRemoveStepCell: AddRemoveStepCell) {
    let step = SequencerStepData()
    sequencerDataSource.append(step)
    stepCollectionView?.reloadData()
  }

  func addRemoveStepCellDidPressRemoveButton(_ addRemoveStepCell: AddRemoveStepCell) {
    guard sequencerDataSource.count > 1 else { return }
    sequencerDataSource.removeLast()
    stepCollectionView?.reloadData()
  }

  // MARK: SequencerStepCellDelegate

  func sequencerStepCellDidToggle(_ sequencerStepCell: SequencerStepCell) {
    guard let index = stepCollectionView?.indexPath(for: sequencerStepCell) else { return }
    sequencerDataSource[index.item].isEnabled = !sequencerDataSource[index.item].isEnabled
  }

  func sequencerStepCell(_ sequencerStepCell: SequencerStepCell, didChange value: Double) {
    guard let index = stepCollectionView?.indexPath(for: sequencerStepCell) else { return }
    let selectedProperty = StepPropertyType.all[stepPropertyManager.selectedButtonIndex]
    switch selectedProperty {
    case .pitch: sequencerDataSource[index.item].midiNote = UInt8(selectedProperty.itemValue(for: Float(value)))
    case .velocity: sequencerDataSource[index.item].velocity = UInt8(selectedProperty.itemValue(for: Float(value)))
    case .modulation: sequencerDataSource[index.item].modulation = UInt8(selectedProperty.itemValue(for: Float(value)))
    case .pitchBend: sequencerDataSource[index.item].pitchBend = UInt16(selectedProperty.itemValue(for: Float(value)))
    }
  }

  func sequencerStepCellLabel(_ sequencerStepCell: SequencerStepCell, for value: Double) -> String {
    guard let index = stepCollectionView?.indexPath(for: sequencerStepCell) else { return "" }
    let item = sequencerDataSource[index.item]
    let selectedProperty = StepPropertyType.all[stepPropertyManager.selectedButtonIndex]

    switch selectedProperty {
    case .pitch:
      return Pitch(midiNote: Int(item.midiNote)).description
    default:
      return "\(value)"
    }
  }

  // MARK: StepPropertyManager

  func stepPropertyManager(_ stepPropertyManager: StepPropertyManager, didSelect button: StepPropertyButton, at index: Int) {
    stepCollectionView?.visibleCells
      .filter({ $0 is SequencerStepCell })
      .compactMap({ $0 as? SequencerStepCell })
      .forEach({
        guard let indexPath = stepCollectionView?.indexPath(for: $0) else { return }
        $0.updateCell(for: knobValue(itemAt: indexPath.item))
      })
  }

  // MARK: Helpers

  func knobValue(itemAt index: Int) -> Float {
    let item = sequencerDataSource[index]
    let selectedProperty = StepPropertyType.all[stepPropertyManager.selectedButtonIndex]
    switch selectedProperty {
    case .pitch: return selectedProperty.knobValue(for: Int(item.midiNote))
    case .velocity: return selectedProperty.knobValue(for: Int(item.velocity))
    case .modulation: return selectedProperty.knobValue(for: Int(item.modulation))
    case .pitchBend: return selectedProperty.knobValue(for: Int(item.pitchBend))
    }
  }
}

// MARK: - Util

func convert<T: FloatingPoint>(value: T, inRange: ClosedRange<T>, toRange: ClosedRange<T>) -> T {
  let oldRange = inRange.upperBound - inRange.lowerBound
  let newRange = toRange.upperBound - toRange.lowerBound
  return (((value - inRange.lowerBound) * newRange) / oldRange) + toRange.lowerBound
}

func convert<T: SignedInteger>(value: T, inRange: ClosedRange<T>, toRange: ClosedRange<T>) -> T {
  let oldRange = inRange.upperBound - inRange.lowerBound
  let newRange = toRange.upperBound - toRange.lowerBound
  return (((value - inRange.lowerBound) * newRange) / oldRange) + toRange.lowerBound
}

func convert<T: FloatingPoint>(value: T, inRange: Range<T>, toRange: Range<T>) -> T {
  let oldRange = inRange.upperBound - inRange.lowerBound
  let newRange = toRange.upperBound - toRange.lowerBound
  return (((value - inRange.lowerBound) * newRange) / oldRange) + toRange.lowerBound
}

func convert<T: SignedInteger>(value: T, inRange: Range<T>, toRange: Range<T>) -> T {
  let oldRange = inRange.upperBound - inRange.lowerBound
  let newRange = toRange.upperBound - toRange.lowerBound
  return (((value - inRange.lowerBound) * newRange) / oldRange) + toRange.lowerBound
}
