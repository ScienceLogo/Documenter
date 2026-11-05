#lang sciencelogo
to calculate-period :elapsed :swings [
  about "Divide the elapsed time by the number of full swings."
  output :elapsed / :swings
]

to compare-periods :large :small [
  about "Subtract the period at a small swing from the period at a large swing."
  output :large - :small
]
