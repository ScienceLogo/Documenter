#lang sciencelogo
stage Observe by assistant from state [
  information = [
    large-swing = [
      elapsed = 20.1 u [
        declared = [reaction-time = [type = "epistemic" estimate = 0.2 unit = "s"]]
      ]
      swing-count = 10
      unit = "s"
    ]
    small-swing = [
      elapsed = 20.0 u [
        declared = [reaction-time = [type = "epistemic" estimate = 0.2 unit = "s"]]
      ]
      swing-count = 10
      unit = "s"
    ]
  ]
  environment = [
    pendulum = [length = 1 unit = "m"]
    timer = "hand stopwatch"
  ]
  factors = [reaction-time = unknown]
]
  about "Time ten full swings at a large and at a small swing, and derive the
  period of each."
  do calculate-period with [
    elapsed at information.large-swing.elapsed
    swings at information.large-swing.swing-count
  ] into information.large-swing.period
  do calculate-period with [
    elapsed at information.small-swing.elapsed
    swings at information.small-swing.swing-count
  ] into information.small-swing.period
end stage with state [
  information = [
    large-swing = [
      elapsed = 20.1 u [
        declared = [reaction-time = [type = "epistemic" estimate = 0.2 unit = "s"]]
      ]
      swing-count = 10
      unit = "s"
      period = unknown
    ]
    small-swing = [
      elapsed = 20.0 u [
        declared = [reaction-time = [type = "epistemic" estimate = 0.2 unit = "s"]]
      ]
      swing-count = 10
      unit = "s"
      period = unknown
    ]
  ]
  environment = [
    pendulum = [length = 1 unit = "m"]
    timer = "hand stopwatch"
  ]
  factors = [reaction-time = unknown]
]
