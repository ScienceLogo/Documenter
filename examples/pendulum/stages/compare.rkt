#lang sciencelogo
stage Compare by researcher from state [
  information = [large-period = 2.01 small-period = 2.00 unit = "s"]
]
  about "Compare the two periods. A difference within the timing uncertainty
  does not support the starting hypothesis."
  do compare-periods with [
    large at information.large-period
    small at information.small-period
  ] into information.difference
end stage with state [
  information = [
    large-period = 2.01
    small-period = 2.00
    unit = "s"
    difference = unknown
  ]
]
