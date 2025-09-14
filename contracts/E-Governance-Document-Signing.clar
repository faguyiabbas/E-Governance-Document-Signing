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

(define-map workflow-templates
    { template-id: uint }
    {
        name: (string-ascii 50),
        document-type: (string-ascii 30),
        creator: principal,
        created-at: uint,
        total-stages: uint,
        active: bool,
    }
)

(define-map template-stages
    {
        template-id: uint,
        stage-number: uint,
    }
    {
        name: (string-ascii 30),
        required-signers: uint,
        parallel-signing: bool,
        auto-advance: bool,
    }
)

(define-map template-stage-signers
    {
        template-id: uint,
        stage-number: uint,
        signer: principal,
    }
    { required: bool }
)

(define-map document-workflows
    { document-id: uint }
    {
        template-id: uint,
        current-stage: uint,
        workflow-status: (string-ascii 20),
        started-at: uint,
    }
)

(define-map workflow-stage-progress
    {
        document-id: uint,
        stage-number: uint,
    }
    {
        signatures-count: uint,
        completed: bool,
        completed-at: (optional uint),
    }
)

(define-data-var history-counter uint u0)
(define-data-var template-counter uint u0)

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

(define-private (get-next-template-id)
    (begin
        (var-set template-counter (+ (var-get template-counter) u1))
        (var-get template-counter)
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

(define-public (create-workflow-template
        (name (string-ascii 50))
        (document-type (string-ascii 30))
        (total-stages uint)
    )
    (let ((template-id (get-next-template-id)))
        (asserts! (is-contract-owner) err-owner-only)
        (asserts! (> total-stages u0) err-invalid-status)
        (map-set workflow-templates { template-id: template-id } {
            name: name,
            document-type: document-type,
            creator: tx-sender,
            created-at: stacks-block-height,
            total-stages: total-stages,
            active: true,
        })
        (ok template-id)
    )
)

(define-public (configure-template-stage
        (template-id uint)
        (stage-number uint)
        (stage-name (string-ascii 30))
        (required-signers uint)
        (parallel-signing bool)
        (auto-advance bool)
    )
    (let ((template (unwrap! (map-get? workflow-templates { template-id: template-id })
            err-not-found
        )))
        (asserts! (is-eq (get creator template) tx-sender) err-not-authorized)
        (asserts! (> stage-number u0) err-invalid-status)
        (asserts! (<= stage-number (get total-stages template))
            err-invalid-status
        )
        (asserts! (> required-signers u0) err-invalid-status)
        (map-set template-stages {
            template-id: template-id,
            stage-number: stage-number,
        } {
            name: stage-name,
            required-signers: required-signers,
            parallel-signing: parallel-signing,
            auto-advance: auto-advance,
        })
        (ok true)
    )
)

(define-public (assign-stage-signer
        (template-id uint)
        (stage-number uint)
        (signer principal)
        (required bool)
    )
    (let ((template (unwrap! (map-get? workflow-templates { template-id: template-id })
            err-not-found
        )))
        (asserts! (is-eq (get creator template) tx-sender) err-not-authorized)
        (asserts! (> stage-number u0) err-invalid-status)
        (asserts! (<= stage-number (get total-stages template))
            err-invalid-status
        )
        (map-set template-stage-signers {
            template-id: template-id,
            stage-number: stage-number,
            signer: signer,
        } { required: required }
        )
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
        (log-document-action document-id "created"
            "Document created successfully"
        )
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
        (log-document-action document-id "created" "Document created with expiry")
        (ok document-id)
    )
)

(define-public (create-workflow-document
        (title (string-ascii 100))
        (hash (buff 32))
        (template-id uint)
    )
    (let (
            (document-id (get-next-document-id))
            (template (unwrap! (map-get? workflow-templates { template-id: template-id })
                err-not-found
            ))
        )
        (asserts! (get active template) err-invalid-status)
        (map-set documents { document-id: document-id } {
            title: title,
            hash: hash,
            creator: tx-sender,
            created-at: stacks-block-height,
            status: "workflow",
            required-signatures: u0,
            signature-count: u0,
            sealed: false,
            expires-at: none,
        })
        (map-set document-workflows { document-id: document-id } {
            template-id: template-id,
            current-stage: u1,
            workflow-status: "active",
            started-at: stacks-block-height,
        })
        (map-set workflow-stage-progress {
            document-id: document-id,
            stage-number: u1,
        } {
            signatures-count: u0,
            completed: false,
            completed-at: none,
        })
        (map-set document-access {
            document-id: document-id,
            accessor: tx-sender,
        } {
            access-level: "full",
            granted-at: stacks-block-height,
        })
        (log-document-action document-id "workflow-started"
            "Workflow document created"
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

(define-public (sign-workflow-stage
        (document-id uint)
        (signature-hash (buff 32))
        (metadata (string-ascii 200))
    )
    (let (
            (document (unwrap! (map-get? documents { document-id: document-id })
                err-not-found
            ))
            (workflow (unwrap! (map-get? document-workflows { document-id: document-id })
                err-not-found
            ))
            (template (unwrap!
                (map-get? workflow-templates { template-id: (get template-id workflow) })
                err-not-found
            ))
            (current-stage (get current-stage workflow))
            (stage-config (unwrap!
                (map-get? template-stages {
                    template-id: (get template-id workflow),
                    stage-number: current-stage,
                })
                err-not-found
            ))
            (stage-progress (unwrap!
                (map-get? workflow-stage-progress {
                    document-id: document-id,
                    stage-number: current-stage,
                })
                err-not-found
            ))
            (signer-assignment (map-get? template-stage-signers {
                template-id: (get template-id workflow),
                stage-number: current-stage,
                signer: tx-sender,
            }))
        )
        (asserts! (not (get sealed document)) err-document-sealed)
        (asserts! (is-eq (get workflow-status workflow) "active")
            err-invalid-status
        )
        (asserts! (not (get completed stage-progress)) err-invalid-status)
        (asserts! (is-some signer-assignment) err-not-authorized)
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

        (let ((new-signatures (+ (get signatures-count stage-progress) u1)))
            (map-set workflow-stage-progress {
                document-id: document-id,
                stage-number: current-stage,
            }
                (merge stage-progress {
                    signatures-count: new-signatures,
                    completed: (>= new-signatures (get required-signers stage-config)),
                    completed-at: (if (>= new-signatures (get required-signers stage-config))
                        (some stacks-block-height)
                        none
                    ),
                })
            )
            (log-document-action document-id "workflow-signed"
                "Stage signed in workflow"
            )
            (if (and
                    (>= new-signatures (get required-signers stage-config))
                    (get auto-advance stage-config)
                )
                (advance-workflow-stage document-id)
                (ok true)
            )
        )
    )
)

(define-public (advance-workflow-stage (document-id uint))
    (let (
            (document (unwrap! (map-get? documents { document-id: document-id })
                err-not-found
            ))
            (workflow (unwrap! (map-get? document-workflows { document-id: document-id })
                err-not-found
            ))
            (template (unwrap!
                (map-get? workflow-templates { template-id: (get template-id workflow) })
                err-not-found
            ))
            (current-stage (get current-stage workflow))
            (stage-progress (unwrap!
                (map-get? workflow-stage-progress {
                    document-id: document-id,
                    stage-number: current-stage,
                })
                err-not-found
            ))
        )
        (asserts!
            (or (is-eq (get creator document) tx-sender) (is-contract-owner))
            err-not-authorized
        )
        (asserts! (is-eq (get workflow-status workflow) "active")
            err-invalid-status
        )
        (asserts! (get completed stage-progress) err-invalid-status)

        (if (< current-stage (get total-stages template))
            (let ((next-stage (+ current-stage u1)))
                (map-set document-workflows { document-id: document-id }
                    (merge workflow { current-stage: next-stage })
                )
                (map-set workflow-stage-progress {
                    document-id: document-id,
                    stage-number: next-stage,
                } {
                    signatures-count: u0,
                    completed: false,
                    completed-at: none,
                })
                (log-document-action document-id "stage-advanced"
                    "Workflow advanced to next stage"
                )
                (ok true)
            )
            (begin
                (map-set document-workflows { document-id: document-id }
                    (merge workflow { workflow-status: "completed" })
                )
                (map-set documents { document-id: document-id }
                    (merge document { status: "complete" })
                )
                (log-document-action document-id "workflow-completed"
                    "Workflow completed successfully"
                )
                (ok true)
            )
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
        (log-document-action document-id "expiry-extended"
            "Document expiry date extended"
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

(define-read-only (get-workflow-template (template-id uint))
    (map-get? workflow-templates { template-id: template-id })
)

(define-read-only (get-template-stage
        (template-id uint)
        (stage-number uint)
    )
    (map-get? template-stages {
        template-id: template-id,
        stage-number: stage-number,
    })
)

(define-read-only (get-document-workflow (document-id uint))
    (map-get? document-workflows { document-id: document-id })
)

(define-read-only (get-workflow-stage-progress
        (document-id uint)
        (stage-number uint)
    )
    (map-get? workflow-stage-progress {
        document-id: document-id,
        stage-number: stage-number,
    })
)

(define-read-only (is-stage-signer
        (template-id uint)
        (stage-number uint)
        (signer principal)
    )
    (is-some (map-get? template-stage-signers {
        template-id: template-id,
        stage-number: stage-number,
        signer: signer,
    }))
)

(define-read-only (get-total-templates)
    (var-get template-counter)
)

(define-read-only (get-workflow-status (document-id uint))
    (match (map-get? document-workflows { document-id: document-id })
        workflow (ok {
            template-id: (get template-id workflow),
            current-stage: (get current-stage workflow),
            status: (get workflow-status workflow),
            started-at: (get started-at workflow),
        })
        err-not-found
    )
)
