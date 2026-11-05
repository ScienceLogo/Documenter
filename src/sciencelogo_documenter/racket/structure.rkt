#lang racket/base
;; The reading order of the method, shared by the website and the booklet:
;; the overview, each stage followed by the procedures only it uses, the
;; procedures used by several stages, and the reference.

(require racket/list)

(provide get
         code-names
         stage-procedures
         shared-procedures
         find-named)

;; get : hash symbol -> any
;; Reads a field of the documentation model; JSON null reads as #f.
(define (get h key)
  (define v (hash-ref h key 'null))
  (if (eq? v 'null) #f v))

;; code-names : doc -> (hash/c string symbol)
;; The names that the method text marks with their category.
(define (code-names doc)
  (make-immutable-hash
   (append (map (lambda (s) (cons (get s 'name) 'stage)) (get doc 'stages))
           (map (lambda (p) (cons (get p 'name) 'procedure)) (get doc 'procedures))
           (map (lambda (p) (cons (get p 'name) 'performer)) (get doc 'performers)))))

(define (find-named items name)
  (findf (lambda (i) (equal? (get i 'name) name)) items))

;; stage-procedures : doc stage -> (listof procedure)
(define (stage-procedures doc stage)
  (filter values (map (lambda (n) (find-named (get doc 'procedures) n)) (get stage 'procedures))))

;; shared-procedures : doc -> (listof procedure)
;; Procedures from libraries are documented by the libraries themselves.
(define (shared-procedures doc)
  (filter (lambda (p) (and (not (get p 'stage)) (not (get p 'library)))) (get doc 'procedures)))
