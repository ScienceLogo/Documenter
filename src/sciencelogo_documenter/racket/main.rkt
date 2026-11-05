#lang racket/base
;; Entry point of the bundled Racket program. The Python launcher runs it.

(provide run)

(define usage "usage: main.rkt <command> [argument ...]")

;; run : (listof string) -> exact-nonnegative-integer
;; Runs one command and returns the process exit code.
(define (run args)
  (cond
    [(null? args)
     (eprintf "~a\n" usage)
     2]
    [else
     (eprintf "unknown command: ~a\n~a\n" (car args) usage)
     2]))

(module+ main
  (exit (run (vector->list (current-command-line-arguments)))))
