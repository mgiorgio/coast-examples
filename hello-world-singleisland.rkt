#lang racket/base

;; Basic requires to work with Island
(require
  Island/include/base)

;; Boilerplate to setup Alice's certificates. You will need them to create Alice island.
(define CERTIFICATE/SECRET "./certificates/secret/")
(define ALICE/SECRET/PATH (string-append CERTIFICATE/SECRET "alice_secret"))

;; Create Alice's CURVE cryptographic keys
(define ALICE/CURVE/SECRET (path-to-curve ALICE/SECRET/PATH))

;; The bootstrap computation for Alice island to say "Hello World!"
(define (alice/boot)
  (display "Hello World!"))

;; Instantiate Alice island
(define alice (island/new 'alice ALICE/CURVE/SECRET alice/boot))