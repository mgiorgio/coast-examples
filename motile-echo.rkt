#lang racket/base

(require
  Island/include/base
  Island/baseline
  Island/transport/gate
  Island/remote)

(define CERTIFICATE/PUBLIC "./certificates/public/")
(define CERTIFICATE/SECRET "./certificates/secret/")
(define ALICE/SECRET/PATH (string-append CERTIFICATE/SECRET "alice_secret"))
(define BOB/SECRET/PATH   (string-append CERTIFICATE/SECRET "bob_secret"))

(define ALICE/CURVE/SECRET (path-to-curve ALICE/SECRET/PATH))
(define BOB/CURVE/SECRET   (path-to-curve BOB/SECRET/PATH))

;; Alice's public key.
(define ALICE/KP/BASE64 #"wdvbN1svfhEAewhM76oSVPKj-4kzfbDhaiTFW61VdUc")

;; Create a Keystore to store the public certificates of other islands.
(define KEYSTORE (keystore/new))
;; Download all of the predefined public certificates.
(keystore/load KEYSTORE CERTIFICATE/PUBLIC)

;; The textual representation of the CURL for Alice's service.
(define/curl/inline ALICE/CURL/SPAWN
  #<<!!
SIGNATURE = #"GNzBZNi6r6WTBdASzv_R0GJjAiwaBYtHkZhiMlyKTD8E-S-mL-A7SMFR7_9IKNl8_JJcfzOIBQh4YDnP3JoWBw"
CURL
    id = 0dd4f4f5-72ce-40fe-996f-f80700c322f0
    origin = #"wdvbN1svfhEAewhM76oSVPKj-4kzfbDhaiTFW61VdUc"
    path = (service spawn)
    access/id = access:send.service.spawn
    created = "2014-05-30T14:47:58Z"
    metadata = #f

!!
  )

(define BOB/COMPUTATION
  (island/compile
   '(lambda (curl/response)
      (lambda ()
        (send curl/response "Hello World!")))
   ))

;; Bob's bootstrap function.
;; alice/curl is the CURL for Alice's service.
(define (bob/boot alice/curl)
  ; Wait until Bob sees Alice.
  (island/enter/wait ALICE/KP/BASE64)
  ; Send Bob's computation and wait for the response.
  (let* ([p (promise/new)]
         [response/curl (promise/resolver p)]
         [thunk (motile/call BOB/COMPUTATION environ/null response/curl)])
    (send alice/curl thunk)
    (let* ([m (promise/block p)]
           [result (murmur/payload m)])
      ; Show result.
      (display result))))

;; Bootstrap function for Alice.
(define (alice/boot)
  ; Define a (service/execute) function.
  (define (service/execute)
    ; Create a duplet to receive messages via Alice's CURL.
    ; Notice the use of (islet/curl/known/new). We use this function because it is a known CURL, we are not creating a brand new CURL.
    ; '(remote chirp) is the service path (it must be the same as the one in the textual representation)
    ; 'access:send:chirp is the access id (it must be the same as the one in the textual representation)
    (let ([server/duplet (islet/curl/known/new '(service spawn) 'access:send.service.spawn GATE/ALWAYS environ/null)])
      (let loop ([m (duplet/block server/duplet)])
        ; Create a worker (i.e. an islet) to solve the incoming computation.
        ; 'client-worker is the worker's nickname.
        ; BASELINE is the binding environment for the new islet.
        (let ([worker (islet/new (this/island) 'client-worker TRUST/LOW BASELINE/SPAWN environ/null)]
              [thunk (murmur/payload m)])
          ; Check that all parameters are correct.
          (when (procedure? thunk)
              ; Execute the computation and send the result back in no more than 10 seconds.
              (spawn worker thunk 10.0)))
        (loop (duplet/block server/duplet)))))
  
  (service/execute))

;; Create an in-memory CURL from the textual representation.
(define alice/curl/execute (curl/zpl/safe-to-curl ALICE/CURL/SPAWN KEYSTORE))

;; Instantiate Alice and Bob.
(define alice (island/new 'alice ALICE/CURVE/SECRET alice/boot))
(define bob (island/new 'bob BOB/CURVE/SECRET (lambda () (bob/boot alice/curl/execute))))

;; Set Alice' and Bob' keystore. Since both islands are in the same address space, they can share the keystore.
(island/keystore/set alice KEYSTORE)
(island/keystore/set bob   KEYSTORE)

(island/log/level/set 'warning)