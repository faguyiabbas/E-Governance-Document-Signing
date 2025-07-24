(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-signer (err u103))
(define-constant err-already-signed (err u104))
(define-constant err-not-authorized (err u105))
(define-constant err-invalid-status (err u106))
(define-constant err-document-sealed (err u107))

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

(define-map document-history
    {
        document-id: uint,
        sequence: uint,
    }
    {
        action: (string-ascii 30),
        actor: principal,
        timestamp: uint,
        details: (string-ascii 100),
    }
)

(define-data-var history-counter uint u0)

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

(define-private (log-document-action
        (document-id uint)
        (action (string-ascii 30))
        (details (string-ascii 100))
    )
    (let ((sequence (+ (var-get history-counter) u1)))
        (var-set history-counter sequence)
        (map-set document-history {
            document-id: document-id,
            sequence: sequence,
        } {
            action: action,
            actor: tx-sender,
            timestamp: stacks-block-height,
            details: details,
        })
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
        })
        (map-set document-access {
            document-id: document-id,
            accessor: tx-sender,
        } {
            access-level: "full",
            granted-at: stacks-block-height,
        })
        (log-document-action document-id "created"
            "Document created successfully"
        )
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
        (log-document-action document-id "access-granted"
            "Document access granted"
        )
        (ok true)
    )
)

(define-public (sign-document
        (document-id uint)
        (signature-hash (buff 32))
        (metadata (string-ascii 200))
    )
    (let (
            (document (unwrap! (map-get? documents { document-id: document-id })
                err-not-found
            ))
            (access (map-get? document-access {
                document-id: document-id,
                accessor: tx-sender,
            }))
        )
        (asserts! (not (get sealed document)) err-document-sealed)
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
                    status: (if (>= new-signature-count
                            (get required-signatures document)
                        )
                        "complete"
                        "pending"
                    ),
                })
            )
            (log-document-action document-id "signed"
                "Document signed by authority"
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
        (log-document-action document-id "sealed" "Document permanently sealed")
        (ok true)
    )
)

(define-public (revoke-signature (document-id uint))
    (let ((document (unwrap! (map-get? documents { document-id: document-id }) err-not-found)))
        (asserts! (not (get sealed document)) err-document-sealed)
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
                    status: (if (>= new-signature-count
                            (get required-signatures document)
                        )
                        "complete"
                        "pending"
                    ),
                })
            )
            (log-document-action document-id "signature-revoked"
                "Signature revoked by signer"
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

(define-read-only (get-document-history
        (document-id uint)
        (sequence uint)
    )
    (map-get? document-history {
        document-id: document-id,
        sequence: sequence,
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
        })
        err-not-found
    )
)
