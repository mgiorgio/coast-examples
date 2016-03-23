#lang racket/base

(require
  Island/include/base
)

(define CERTIFICATE/SECRET "./certificates/secret/")
(define ALICE/SECRET/PATH (string-append CERTIFICATE/SECRET "alice_secret"))
(define BOB/SECRET/PATH   (string-append CERTIFICATE/SECRET "bob_secret"))

(define ALICE/CURVE/SECRET (path-to-curve ALICE/SECRET/PATH))
(define BOB/CURVE/SECRET   (path-to-curve BOB/SECRET/PATH))

(define (islet/hello)
  (display (format "Hi, I am ~a" (island/nickname (this/island)))))

(define alice (island/new 'alice ALICE/CURVE/SECRET islet/hello))
(define bob   (island/new 'bob   BOB/CURVE/SECRET   islet/hello))