#lang racket/base

(require racket/port
         rackunit
         "../../src/sciencelogo_documenter/racket/main.rkt")

(define (run/quiet args)
  (parameterize ([current-error-port (open-output-nowhere)])
    (run args)))

(test-case "no command is a usage error"
  (check-equal? (run/quiet '()) 2))

(test-case "an unknown command is a usage error"
  (check-equal? (run/quiet '("no-such-command")) 2))
