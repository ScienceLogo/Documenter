#lang sciencelogo
stage Prepare by assistant from state [
  information = [swing-count = 10]
  environment = [
    pendulum = [length = 1 unit = "m"]
    timer = "hand stopwatch"
  ]
  factors = [reaction-time = unknown]
]
  about "Set up a pendulum of fixed length and a hand stopwatch, and decide to
  time ten full swings in each trial."
end stage with state [
  information = [swing-count = 10]
  environment = [
    pendulum = [length = 1 unit = "m"]
    timer = "hand stopwatch"
  ]
  factors = [reaction-time = unknown]
]
