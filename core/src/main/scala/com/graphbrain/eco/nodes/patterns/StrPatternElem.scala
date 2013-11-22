package com.graphbrain.eco.nodes.patterns

class StrPatternElem(val str: String)
  extends PatternElem {

  override protected def onSetSentence() = {
    if (prevElem == null) {
      startMin = 0
      startMax = 0
    }
    else {
      startMin = prevElem.endMin + 1
      startMax = prevElem.endMax + 1
    }

    endMin = startMin
    endMax = startMax
  }

  private def step: Boolean = if (start < 0) {
    start = Math.min(curStartMax, curEndMin)
    true
  }
  else {
    start += 1
    start > curEndMax
  }

  override def onNext(): Boolean = {
    // check if gap to fill is larger than one word
    if (curStartMax < curEndMin)
      return false

    var found = false

    while(!found) {
      if (!step)
        return false

      if (sentence.words(start).word == str)
        found = true
    }

    end = start
    true
  }

  override def toString =
    "\"" + str + "\"" + " = '" + sentence.slice(start, end) + "'"
}