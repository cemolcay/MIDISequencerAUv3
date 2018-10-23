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

  @IBOutlet var containerView: GestureSlider?
  @IBOutlet var ledView: LedView?
  @IBOutlet var valueLabel: UILabel?

  @IBInspectable var enabledColor: UIColor = #colorLiteral(red: 0.9166453481, green: 0.8375994563, blue: 0.02345943265, alpha: 1)
  @IBInspectable var disabledColor: UIColor = #colorLiteral(red: 0.5058823824, green: 0.3372549117, blue: 0.06666667014, alpha: 1)

  override func prepareForReuse() {
    isEnabled = true
    ledView?.isOn = false
    valueLabel?.text = ""
    containerView?.tapGesture.addTarget(self, action: #selector(didTap(gestureRecognizer:)))
    containerView?.controlType = .vertical

    layer.cornerRadius = 8
    ledView?.layer.cornerRadius = (ledView?.frame.size.width ?? 2) / 2.0
  }

  var isEnabled = true {
    didSet {
      containerView?.backgroundColor = isEnabled ? enabledColor : disabledColor
    }
  }

  @objc func didTap(gestureRecognizer: UITapGestureRecognizer) {
    isEnabled = !isEnabled
    delegate?.sequencerStepCellDidToggle(self)
  }

  @IBAction func valueChange(sender: GestureSlider) {
    valueLabel?.text = delegate?.sequencerStepCellLabel(self, for: sender.value) ?? ""
    delegate?.sequencerStepCell(self, didChange: sender.value)
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

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, AddRemoveStepCellDelegate, SequencerStepCellDelegate {
  var audioUnit: AUAudioUnit?
  var parameterObserverToken: AUParameterObserverToken?
  var sequencerDataSource = [SequencerStepData]()

  @IBOutlet weak var noteValueSegment: UISegmentedControl?
  @IBOutlet weak var stepCollectionView: UICollectionView?

  // MARK: Lifecycle

  public override func viewDidLoad() {
    super.viewDidLoad()
    stepCollectionView?.delaysContentTouches = false

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
    cell.delegate = self
    return cell
  }

  // MARK: UICollectionViewDelegateFlowLayout

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let height = min(collectionView.frame.size.height, 150)
    let width: CGFloat = height * 125 / 200
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

  }

  func sequencerStepCell(_ sequencerStepCell: SequencerStepCell, didChange value: Double) {
    guard let index = stepCollectionView?.indexPath(for: sequencerStepCell) else { return }
    print("index: \(index), value: \(value)")
  }

  func sequencerStepCellLabel(_ sequencerStepCell: SequencerStepCell, for value: Double) -> String {
    return ""
  }
}
