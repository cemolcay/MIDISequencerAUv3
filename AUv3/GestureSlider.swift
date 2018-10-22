//
//  GestureSlider.swift
//  GestureSlider
//
//  Created by Cem Olcay on 3.06.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import UIKit
import LiveKnob

public class GestureSlider: UIControl {
  public var continuous: Bool = true
  public var controlType: LiveKnobControlType = .horizontalAndVertical

  private(set) var liveKnobGesture = LiveKnobGestureRecognizer()
  private(set) var tapGesture = UITapGestureRecognizer()
  private(set) var doubleTapGesture = UITapGestureRecognizer()

  var minimum: Double = 0.0 { didSet { value = (value - minimum) / (maximum - minimum) }}
  var maximum: Double = 1.0 { didSet { value = (value - minimum) / (maximum - minimum) }}
  var value: Double = 0.5 { didSet { value = min(maximum, max(minimum, value)) }}

  // MARK: Init

  public override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    isUserInteractionEnabled = true

    addGestureRecognizer(liveKnobGesture)
    addGestureRecognizer(tapGesture)
    addGestureRecognizer(doubleTapGesture)

    liveKnobGesture.addTarget(self, action: #selector(didValueChange(gesture:)))
    doubleTapGesture.numberOfTapsRequired = 2
    tapGesture.numberOfTapsRequired = 1
    tapGesture.require(toFail: doubleTapGesture)
  }

  // MARK: Gesture Recognizers

  @objc func didValueChange(gesture: LiveKnobGestureRecognizer) {
    switch controlType {
    case .horizontal:
      value += Double(gesture.diagonalChange.width) * (maximum - minimum)
    case .vertical:
      value -= Double(gesture.diagonalChange.height) * (maximum - minimum)
    case .horizontalAndVertical:
      value += Double(gesture.diagonalChange.width) * (maximum - minimum)
      value -= Double(gesture.diagonalChange.height) * (maximum - minimum)
    case .rotary:
      break
    }

    // Inform changes based on continuous behaviour of the knob.
    if continuous {
      sendActions(for: .valueChanged)
    } else {
      if gesture.state == .ended || gesture.state == .cancelled {
        sendActions(for: .valueChanged)
      }
    }
  }
}
