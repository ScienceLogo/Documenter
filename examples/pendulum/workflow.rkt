#lang sciencelogo
workflow "Pendulum period"
about "Does a pendulum's period change as its swing gets smaller? This method
times a pendulum at a large and at a small swing, compares the two periods,
and revises the starting hypothesis."

performer assistant [kind = "human" role = "laboratory assistant"]
performer researcher [kind = "human" role = "scientist"]

interface Timing [
  version "1"
  must [elapsed is number swing-count is number unit = "s"]
]

hypothesis shorter-swing [text = "A smaller swing has a shorter period."]
assumption hand-timing [text = "Hand timing is comparable across trials."]

must stages in order [Prepare Observe Compare Revise]

include "procedures.rkt"
include "stages/prepare.rkt"
include "stages/observe.rkt"
include "stages/compare.rkt"
include "stages/revise.rkt"

phase Measurement
  about "Set up the pendulum and time its swings at two amplitudes."
[Prepare Observe]

phase Analysis
  about "Compare the two periods and revise the starting hypothesis."
[Compare Revise]
