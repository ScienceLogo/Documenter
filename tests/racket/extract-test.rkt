#lang racket/base
;; The documentation model of the example workflow.

(require json racket/runtime-path racket/string rackunit
         "../../src/sciencelogo_documenter/racket/extract.rkt"
         "../../src/sciencelogo_documenter/racket/structure.rkt")

(define-runtime-path example "../../examples/pendulum/workflow.rkt")
(define-runtime-path example-dir "../../examples/pendulum")

(define doc (extract-documentation example))

(define (names items) (map (lambda (i) (get i 'name)) items))

(test-case "the workflow's title and about"
  (check-equal? (get doc 'title) "Pendulum period")
  (check-true (string-prefix? (get doc 'about) "Does a pendulum's period change")))

(test-case "stages in method order, with their performers"
  (check-equal? (names (get doc 'stages)) '("Prepare" "Observe" "Compare" "Revise"))
  (check-equal? (map (lambda (s) (get s 'performer)) (get doc 'stages))
                '("assistant" "assistant" "researcher" #f)))

(test-case "phases group the stages, and the outline follows them"
  (check-equal? (names (get doc 'phases)) '("Measurement" "Analysis"))
  (check-equal? (map (lambda (m) (get m 'name)) (get (car (get doc 'phases)) 'members)) '("Prepare" "Observe"))
  (check-equal? (map (lambda (s) (get s 'phase)) (get doc 'stages))
                '("Measurement" "Measurement" "Analysis" "Analysis"))
  (check-equal? (for/list ([n (in-list (get doc 'outline))])
                  (cons (get n 'name) (map (lambda (c) (get c 'name)) (get n 'children))))
                '(("Measurement" "Prepare" "Observe") ("Analysis" "Compare" "Revise")))
  (check-true (string-prefix? (get (car (get doc 'phases)) 'verbose) "phase Measurement")))

(test-case "procedures, their inputs and who calls them"
  (define calc (find-named (get doc 'procedures) "calculate-period"))
  (check-equal? (get calc 'inputs) '("elapsed" "swings"))
  (check-equal? (get calc 'stage) "Observe")
  (check-equal? (get (find-named (get doc 'stages) "Observe") 'procedures) '("calculate-period"))
  (check-equal? (length (get (find-named (get doc 'stages) "Observe") 'calls)) 2))

(test-case "a call maps inputs from state locations"
  (define call (car (get (find-named (get doc 'stages) "Compare") 'calls)))
  (check-equal? (get call 'procedure) "compare-periods")
  (check-equal? (get call 'into) "information.difference")
  (check-equal? (map (lambda (i) (get i 'location)) (get call 'inputs))
                '("information.large-period" "information.small-period")))

(test-case "performers, propositions, requirements and record types"
  (check-equal? (names (get doc 'performers)) '("assistant" "researcher"))
  (check-equal? (map (lambda (p) (get p 'kind)) (get doc 'propositions))
                '("hypothesis" "assumption" "conclusion"))
  (check-equal? (get (car (get doc 'requirements)) 'targets) '("Prepare" "Observe" "Compare" "Revise"))
  (check-equal? (names (get doc 'record_types)) '("Timing"))
  (check-equal? (names (get (car (get doc 'record_types)) 'fields)) '("elapsed" "swing-count" "unit")))

(test-case "values keep units and uncertainty"
  (define entry (get (find-named (get doc 'stages) "Prepare") 'entry))
  (check-true (string-contains? (jsexpr->string entry) "\"unit\":\"m\""))
  (define observe (jsexpr->string (get (find-named (get doc 'stages) "Observe") 'entry)))
  (check-true (string-contains? observe "\"kind\":\"uncertain\""))
  (check-true (string-contains? observe "reaction-time")))

(test-case "each item has its own verbose text"
  (define observe (get (find-named (get doc 'stages) "Observe") 'verbose))
  (check-true (string-prefix? observe "start stage Observe"))
  (check-true (string-suffix? observe "]"))
  (check-true (string-prefix? (get (find-named (get doc 'procedures) "calculate-period") 'verbose)
                              "to calculate-period")))

(test-case "the model holds no file paths or include statements"
  (define text (jsexpr->string doc))
  (check-false (string-contains? text (path->string (simplify-path example-dir))))
  (check-false (string-contains? text ".rkt"))
  (check-false (string-contains? text "include")))
