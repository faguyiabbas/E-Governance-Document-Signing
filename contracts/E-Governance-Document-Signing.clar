;; title: E-Governance-Document-Signing
;; version: 1.0.0
;; summary: A comprehensive e-governance document signing system with notifications
;; description: Enables secure document creation, multi-signature workflows, authority management, and notification system

;; Constants for existing document system
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-signer (err u103))
(define-constant err-already-signed (err u104))
(define-constant err-not-authorized (err u105))
(define-constant err-invalid-status (err u106))
(define-constant err-document-sealed (err u107))
(define-constant err-document-expired (err u108))

(define-data-var document-counter uint u0)
(define-data-var authority-counter uint u0)

(define-map documents
  { document-id: uint }
  {
    title: (string-ascii 100),
    hash: (buff 32),
    creator: principal,
    created-at: uint,
    status: (string-ascii 20),
    required-signatures: uint,
    signature-count: uint,
    sealed: bool,
    expires-at: (optional uint),
  }
)

(define-map document-signers
  {
    document-id: uint,
    signer: principal,
  }
  {
    signed-at: uint,
    signature-hash: (buff 32),
    metadata: (string-ascii 200),
  }
)

(define-map authorized-authorities
  { authority-id: uint }
  {
    principal: principal,
    name: (string-ascii 50),
    department: (string-ascii 50),
    authorized-by: principal,
    created-at: uint,
    active: bool,
  }
)

(define-map authority-permissions
  {
    authority: principal,
    document-type: (string-ascii 30),
  }
  {
    can-sign: bool,
    can-create: bool,
  }
)

(define-map document-access
  {
    document-id: uint,
    accessor: principal,
  }
  {
    access-level: (string-ascii 10),
    granted-at: uint,
  }
)

(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (get-next-document-id)
  (begin
    (var-set document-counter (+ (var-get document-counter) u1))
    (var-get document-counter)
  )
)

(define-private (get-next-authority-id)
  (begin
    (var-set authority-counter (+ (var-get authority-counter) u1))
    (var-get authority-counter)
  )
)

(define-private (is-document-expired (document-id uint))
  (match (map-get? documents { document-id: document-id })
    document (match (get expires-at document)
      expiry-height (>= stacks-block-height expiry-height)
      false
    )
    false
  )
)

(define-public (authorize-authority
    (authority principal)
    (name (string-ascii 50))
    (department (string-ascii 50))
  )
  (let ((authority-id (get-next-authority-id)))
    (asserts! (is-contract-owner) err-owner-only)
    (map-set authorized-authorities { authority-id: authority-id } {
      principal: authority,
      name: name,
      department: department,
      authorized-by: tx-sender,
      created-at: stacks-block-height,
      active: true,
    })
    (ok authority-id)
  )
)

(define-public (set-authority-permissions
    (authority principal)
    (document-type (string-ascii 30))
    (can-sign bool)
    (can-create bool)
  )
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (map-set authority-permissions {
      authority: authority,
      document-type: document-type,
    } {
      can-sign: can-sign,
      can-create: can-create,
    })
    (ok true)
  )
)

(define-public (create-document
    (title (string-ascii 100))
    (hash (buff 32))
    (required-signatures uint)
  )
  (let ((document-id (get-next-document-id)))
    (map-set documents { document-id: document-id } {
      title: title,
      hash: hash,
      creator: tx-sender,
      created-at: stacks-block-height,
      status: "pending",
      required-signatures: required-signatures,
      signature-count: u0,
      sealed: false,
      expires-at: none,
    })
    (map-set document-access {
      document-id: document-id,
      accessor: tx-sender,
    } {
      access-level: "full",
      granted-at: stacks-block-height,
    })
    (ok document-id)
  )
)

(define-public (create-document-with-expiry
    (title (string-ascii 100))
    (hash (buff 32))
    (required-signatures uint)
    (expires-at uint)
  )
  (let ((document-id (get-next-document-id)))
    (asserts! (> expires-at stacks-block-height) err-invalid-status)
    (map-set documents { document-id: document-id } {
      title: title,
      hash: hash,
      creator: tx-sender,
      created-at: stacks-block-height,
      status: "pending",
      required-signatures: required-signatures,
      signature-count: u0,
      sealed: false,
      expires-at: (some expires-at),
    })
    (map-set document-access {
      document-id: document-id,
      accessor: tx-sender,
    } {
      access-level: "full",
      granted-at: stacks-block-height,
    })
    (ok document-id)
  )
)

(define-public (grant-document-access
    (document-id uint)
    (accessor principal)
    (access-level (string-ascii 10))
  )
  (let ((document (unwrap! (map-get? documents { document-id: document-id }) err-not-found)))
    (asserts! (is-eq (get creator document) tx-sender) err-not-authorized)
    (map-set document-access {
      document-id: document-id,
      accessor: accessor,
    } {
      access-level: access-level,
      granted-at: stacks-block-height,
    })
    (ok true)
  )
)

(define-public (sign-document
    (document-id uint)
    (signature-hash (buff 32))
    (metadata (string-ascii 200))
  )
  (let (
      (document (unwrap! (map-get? documents { document-id: document-id }) err-not-found))
      (access (map-get? document-access {
        document-id: document-id,
        accessor: tx-sender,
      }))
    )
    (asserts! (not (get sealed document)) err-document-sealed)
    (asserts! (not (is-document-expired document-id)) err-document-expired)
    (asserts! (is-some access) err-not-authorized)
    (asserts!
      (is-none (map-get? document-signers {
        document-id: document-id,
        signer: tx-sender,
      }))
      err-already-signed
    )

    (map-set document-signers {
      document-id: document-id,
      signer: tx-sender,
    } {
      signed-at: stacks-block-height,
      signature-hash: signature-hash,
      metadata: metadata,
    })

    (let ((new-signature-count (+ (get signature-count document) u1)))
      (map-set documents { document-id: document-id }
        (merge document {
          signature-count: new-signature-count,
          status: (if (>= new-signature-count (get required-signatures document))
            "complete"
            "pending"
          ),
        })
      )
      (ok true)
    )
  )
)

(define-public (seal-document (document-id uint))
  (let ((document (unwrap! (map-get? documents { document-id: document-id }) err-not-found)))
    (asserts! (is-eq (get creator document) tx-sender) err-not-authorized)
    (asserts! (is-eq (get status document) "complete") err-invalid-status)
    (asserts! (not (get sealed document)) err-document-sealed)

    (map-set documents { document-id: document-id }
      (merge document { sealed: true })
    )
    (ok true)
  )
)

(define-public (revoke-signature (document-id uint))
  (let ((document (unwrap! (map-get? documents { document-id: document-id }) err-not-found)))
    (asserts! (not (get sealed document)) err-document-sealed)
    (asserts! (not (is-document-expired document-id)) err-document-expired)
    (asserts!
      (is-some (map-get? document-signers {
        document-id: document-id,
        signer: tx-sender,
      }))
      err-not-found
    )

    (map-delete document-signers {
      document-id: document-id,
      signer: tx-sender,
    })

    (let ((new-signature-count (- (get signature-count document) u1)))
      (map-set documents { document-id: document-id }
        (merge document {
          signature-count: new-signature-count,
          status: (if (>= new-signature-count (get required-signatures document))
            "complete"
            "pending"
          ),
        })
      )
      (ok true)
    )
  )
)

(define-read-only (get-document (document-id uint))
  (map-get? documents { document-id: document-id })
)

(define-read-only (get-document-signatures (document-id uint))
  (ok (map-get? document-signers {
    document-id: document-id,
    signer: tx-sender,
  }))
)

(define-read-only (get-authority-info (authority-id uint))
  (map-get? authorized-authorities { authority-id: authority-id })
)

(define-read-only (get-document-access-level
    (document-id uint)
    (accessor principal)
  )
  (map-get? document-access {
    document-id: document-id,
    accessor: accessor,
  })
)

(define-read-only (get-total-documents)
  (var-get document-counter)
)

(define-read-only (get-total-authorities)
  (var-get authority-counter)
)

(define-read-only (has-signed-document
    (document-id uint)
    (signer principal)
  )
  (is-some (map-get? document-signers {
    document-id: document-id,
    signer: signer,
  }))
)

(define-read-only (can-sign-document
    (document-id uint)
    (signer principal)
  )
  (let ((document (map-get? documents { document-id: document-id })))
    (match document
      doc (and
        (not (get sealed doc))
        (not (is-document-expired document-id))
        (is-some (map-get? document-access {
          document-id: document-id,
          accessor: signer,
        }))
        (is-none (map-get? document-signers {
          document-id: document-id,
          signer: signer,
        }))
      )
      false
    )
  )
)

(define-read-only (get-document-status (document-id uint))
  (match (map-get? documents { document-id: document-id })
    document (ok {
      status: (get status document),
      signatures: (get signature-count document),
      required: (get required-signatures document),
      sealed: (get sealed document),
      expires-at: (get expires-at document),
    })
    err-not-found
  )
)

(define-public (extend-document-expiry
    (document-id uint)
    (new-expiry uint)
  )
  (let ((document (unwrap! (map-get? documents { document-id: document-id }) err-not-found)))
    (asserts! (is-eq (get creator document) tx-sender) err-not-authorized)
    (asserts! (not (get sealed document)) err-document-sealed)
    (asserts! (> new-expiry stacks-block-height) err-invalid-status)
    (map-set documents { document-id: document-id }
      (merge document { expires-at: (some new-expiry) })
    )
    (ok true)
  )
)

(define-read-only (is-expired (document-id uint))
  (is-document-expired document-id)
)

(define-read-only (get-document-expiry (document-id uint))
  (match (map-get? documents { document-id: document-id })
    document (get expires-at document)
    none
  )
)

;; ---------------------------------------------
;; Document Notifications System (independent)
;; ---------------------------------------------

(define-constant ERR-ALREADY-SUBSCRIBED u1001)
(define-constant ERR-NOT-SUBSCRIBED u1002)
(define-constant ERR-INVALID-NOTIF-TYPE u1003)
(define-constant ERR-OPTED-OUT u1004)
(define-constant ERR-UNAUTHORIZED u1401)
(define-constant ERR-NO-EVENT u1404)
(define-constant ERR-RATE-LIMIT u1429)

(define-constant NOTIF-TYPE-EMAIL u1)
(define-constant NOTIF-TYPE-STATUS u2)
(define-constant NOTIF-TYPE-EXPIRY u3)

(define-constant DELIVERY-RECORDED u1)
(define-constant DELIVERY-ACKNOWLEDGED u2)

(define-data-var notification-counter uint u0)

(define-map notification-preferences
  { user: principal }
  {
    email-alerts: bool,
    status-updates: bool,
    expiry-warnings: bool,
    allow-external: bool,
    min-gap: uint,
  }
)

(define-map notification-subscriptions
  {
    doc-id: uint,
    subscriber: principal,
  }
  {
    active: bool,
    created-at: uint,
    updated-at: uint,
  }
)

(define-map notification-events
  { id: uint }
  {
    doc-id: uint,
    recipient: principal,
    n-type: uint,
    status: uint,
    sender: principal,
    created-at: uint,
    ack-at: (optional uint),
  }
)

(define-map events-by-doc-recipient-index
  {
    doc-id: uint,
    recipient: principal,
    seq: uint,
  }
  { id: uint }
)

(define-map event-counters-by-doc-recipient
  {
    doc-id: uint,
    recipient: principal,
  }
  { count: uint }
)

(define-map last-event-block
  {
    doc-id: uint,
    recipient: principal,
    n-type: uint,
  }
  { height: uint }
)

(define-map subs-count-by-doc
  { doc-id: uint }
  { count: uint }
)

(define-map subs-by-doc-index
  {
    doc-id: uint,
    seq: uint,
  }
  { subscriber: principal }
)

(define-private (is-valid-type (t uint))
  (or
    (is-eq t NOTIF-TYPE-EMAIL)
    (or
      (is-eq t NOTIF-TYPE-STATUS)
      (is-eq t NOTIF-TYPE-EXPIRY)
    )
  )
)

(define-read-only (get-preferences-or-default (who principal))
  (match (map-get? notification-preferences { user: who })
    prefs
    prefs
    {
      email-alerts: true,
      status-updates: true,
      expiry-warnings: true,
      allow-external: false,
      min-gap: u0,
    }
  )
)

(define-read-only (is-subscribed
    (doc-id uint)
    (who principal)
  )
  (match (map-get? notification-subscriptions {
    doc-id: doc-id,
    subscriber: who,
  })
    s (get active s)
    false
  )
)

(define-public (subscribe (doc-id uint))
  (let (
      (key {
        doc-id: doc-id,
        subscriber: tx-sender,
      })
      (now stacks-block-height)
      (existing (map-get? notification-subscriptions key))
    )
    (match existing
      some-sub (if (get active some-sub)
        (err ERR-ALREADY-SUBSCRIBED)
        (begin
          (map-set notification-subscriptions key {
            active: true,
            created-at: (get created-at some-sub),
            updated-at: now,
          })
          (let (
              (sc (default-to { count: u0 }
                (map-get? subs-count-by-doc { doc-id: doc-id })
              ))
              (next (+ (get count sc) u1))
            )
            (map-set subs-count-by-doc { doc-id: doc-id } { count: next })
            (map-set subs-by-doc-index {
              doc-id: doc-id,
              seq: next,
            } { subscriber: tx-sender }
            )
          )
          (ok true)
        )
      )
      (begin
        (map-set notification-subscriptions key {
          active: true,
          created-at: now,
          updated-at: now,
        })
        (let (
            (sc (default-to { count: u0 }
              (map-get? subs-count-by-doc { doc-id: doc-id })
            ))
            (next (+ (get count sc) u1))
          )
          (map-set subs-count-by-doc { doc-id: doc-id } { count: next })
          (map-set subs-by-doc-index {
            doc-id: doc-id,
            seq: next,
          } { subscriber: tx-sender }
          )
        )
        (ok true)
      )
    )
  )
)

(define-public (unsubscribe (doc-id uint))
  (let (
      (key {
        doc-id: doc-id,
        subscriber: tx-sender,
      })
      (now stacks-block-height)
      (existing (map-get? notification-subscriptions key))
    )
    (match existing
      sub (if (not (get active sub))
        (err ERR-NOT-SUBSCRIBED)
        (begin
          (map-set notification-subscriptions key {
            active: false,
            created-at: (get created-at sub),
            updated-at: now,
          })
          (ok true)
        )
      )
      (err ERR-NOT-SUBSCRIBED)
    )
  )
)

(define-public (set-notification-preferences
    (email-alerts bool)
    (status-updates bool)
    (expiry-warnings bool)
    (allow-external bool)
    (min-gap uint)
  )
  (begin
    (map-set notification-preferences { user: tx-sender } {
      email-alerts: email-alerts,
      status-updates: status-updates,
      expiry-warnings: expiry-warnings,
      allow-external: allow-external,
      min-gap: min-gap,
    })
    (ok true)
  )
)

(define-public (send-notification
    (recipient principal)
    (doc-id uint)
    (n-type uint)
  )
  (let (
      (now stacks-block-height)
      (prefs (get-preferences-or-default recipient))
    )
    (if (not (is-valid-type n-type))
      (err ERR-INVALID-NOTIF-TYPE)
      (if (not (is-subscribed doc-id recipient))
        (err ERR-NOT-SUBSCRIBED)
        (let (
            (allowed-type (if (is-eq n-type NOTIF-TYPE-EMAIL)
              (get email-alerts prefs)
              (if (is-eq n-type NOTIF-TYPE-STATUS)
                (get status-updates prefs)
                (get expiry-warnings prefs)
              )
            ))
            (allow-ext (get allow-external prefs))
            (min-gap (get min-gap prefs))
          )
          (if (not allowed-type)
            (err ERR-OPTED-OUT)
            (if (and (not (is-eq tx-sender recipient)) (not allow-ext))
              (err ERR-UNAUTHORIZED)
              (let ((last (map-get? last-event-block {
                  doc-id: doc-id,
                  recipient: recipient,
                  n-type: n-type,
                })))
                (if (and (is-some last) (< (- now (get height (unwrap-panic last))) min-gap))
                  (err ERR-RATE-LIMIT)
                  (let (
                      (next-id (+ (var-get notification-counter) u1))
                      (erc (default-to { count: u0 }
                        (map-get? event-counters-by-doc-recipient {
                          doc-id: doc-id,
                          recipient: recipient,
                        })
                      ))
                      (next-seq (+ (get count erc) u1))
                    )
                    (begin
                      (var-set notification-counter next-id)
                      (map-set notification-events { id: next-id } {
                        doc-id: doc-id,
                        recipient: recipient,
                        n-type: n-type,
                        status: DELIVERY-RECORDED,
                        sender: tx-sender,
                        created-at: now,
                        ack-at: none,
                      })
                      (map-set event-counters-by-doc-recipient {
                        doc-id: doc-id,
                        recipient: recipient,
                      } { count: next-seq }
                      )
                      (map-set events-by-doc-recipient-index {
                        doc-id: doc-id,
                        recipient: recipient,
                        seq: next-seq,
                      } { id: next-id }
                      )
                      (map-set last-event-block {
                        doc-id: doc-id,
                        recipient: recipient,
                        n-type: n-type,
                      } { height: now }
                      )
                      (ok next-id)
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-public (ack-notification (event-id uint))
  (let ((e (map-get? notification-events { id: event-id })))
    (match e
      ev (if (not (is-eq (get recipient ev) tx-sender))
        (err ERR-UNAUTHORIZED)
        (begin
          (map-set notification-events { id: event-id } {
            doc-id: (get doc-id ev),
            recipient: (get recipient ev),
            n-type: (get n-type ev),
            status: DELIVERY-ACKNOWLEDGED,
            sender: (get sender ev),
            created-at: (get created-at ev),
            ack-at: (some stacks-block-height),
          })
          (ok true)
        )
      )
      (err ERR-NO-EVENT)
    )
  )
)

(define-read-only (get-subscription
    (doc-id uint)
    (who principal)
  )
  (map-get? notification-subscriptions {
    doc-id: doc-id,
    subscriber: who,
  })
)

(define-read-only (get-preferences (who principal))
  (map-get? notification-preferences { user: who })
)

(define-read-only (get-event (event-id uint))
  (map-get? notification-events { id: event-id })
)

(define-read-only (get-event-id-by-doc-recipient
    (doc-id uint)
    (recipient principal)
    (seq uint)
  )
  (map-get? events-by-doc-recipient-index {
    doc-id: doc-id,
    recipient: recipient,
    seq: seq,
  })
)

(define-read-only (get-event-count
    (doc-id uint)
    (recipient principal)
  )
  (get count
    (default-to { count: u0 }
      (map-get? event-counters-by-doc-recipient {
        doc-id: doc-id,
        recipient: recipient,
      })
    ))
)

(define-read-only (get-subscriber-by-doc-and-seq
    (doc-id uint)
    (seq uint)
  )
  (map-get? subs-by-doc-index {
    doc-id: doc-id,
    seq: seq,
  })
)

(define-read-only (get-subs-count-for-doc (doc-id uint))
  (get count
    (default-to { count: u0 } (map-get? subs-count-by-doc { doc-id: doc-id }))
  )
)

(define-read-only (get-last-event-block
    (doc-id uint)
    (recipient principal)
    (n-type uint)
  )
  (map-get? last-event-block {
    doc-id: doc-id,
    recipient: recipient,
    n-type: n-type,
  })
)

(define-read-only (get-next-event-id)
  (+ (var-get notification-counter) u1)
)

(define-map document-metadata
  {
    document-id: uint,
    key: (string-ascii 50),
  }
  { value: (string-ascii 200) }
)

(define-public (set-document-metadata
    (document-id uint)
    (key (string-ascii 50))
    (value (string-ascii 200))
  )
  (let ((document (unwrap! (map-get? documents { document-id: document-id }) err-not-found)))
    (asserts! (is-eq (get creator document) tx-sender) err-not-authorized)
    (map-set document-metadata {
      document-id: document-id,
      key: key,
    } { value: value }
    )
    (ok true)
  )
)

(define-public (delete-document-metadata
    (document-id uint)
    (key (string-ascii 50))
  )
  (let (
      (document (unwrap! (map-get? documents { document-id: document-id }) err-not-found))
      (existing (map-get? document-metadata {
        document-id: document-id,
        key: key,
      }))
    )
    (asserts! (is-eq (get creator document) tx-sender) err-not-authorized)
    (asserts! (is-some existing) err-not-found)
    (map-delete document-metadata {
      document-id: document-id,
      key: key,
    })
    (ok true)
  )
)

(define-read-only (get-document-metadata
    (document-id uint)
    (key (string-ascii 50))
  )
  (map-get? document-metadata {
    document-id: document-id,
    key: key,
  })
)
