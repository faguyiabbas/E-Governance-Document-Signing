Document Notifications System

Overview
Adds an independent notification subsystem to the E-Governance contract enabling per-document subscriptions, user preferences, event logging, acknowledgements, and read-only queries.

Technical Implementation
- New constants: notification types, delivery statuses, error codes
- New state:
  - notification-preferences
  - notification-subscriptions
  - notification-events
  - events-by-doc-recipient-index
  - event-counters-by-doc-recipient
  - last-event-block
  - subs-count-by-doc, subs-by-doc-index
  - notification-counter data-var
- New public functions:
  - subscribe, unsubscribe
  - set-notification-preferences
  - send-notification, ack-notification
- New read-only functions:
  - is-subscribed, get-subscription
  - get-preferences, get-preferences-or-default
  - get-event, get-next-event-id
  - get-event-id-by-doc-recipient, get-event-count
  - get-subscriber-by-doc-and-seq, get-subs-count-for-doc
  - get-last-event-block
- No external contracts or traits; existing functionality unchanged.

Testing & Validation
- ✅ clarinet check passes locally
- ✅ Unit tests for subscribe/unsubscribe, preferences, send/ack, rate limiting, opt-out, indexes
- ✅ GitHub Actions CI added to run syntax check
- ✅ Clarity v3-compatible with comprehensive error handling
