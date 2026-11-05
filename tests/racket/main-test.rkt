#lang racket/base

(require racket/port
         rackunit
         "../../src/sciencelogo_documenter/racket/main.rkt")

(define (run/quiet args)
  (parameterize ([current-error-port (open-output-nowhere)]
                 [current-output-port (open-output-nowhere)])
    (run args)))

(test-case "no command is a usage error"
  (check-equal? (run/quiet '()) 2))

(test-case "an unknown command is a usage error"
  (check-equal? (run/quiet '("no-such-command")) 2))

(test-case "a missing workflow is reported as a failure"
  (check-equal? (run/quiet '("extract" "no-such-file.rkt")) 1))
