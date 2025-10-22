
import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;

describe("E-Governance Document Signing - Notification System", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  describe("Basic Subscription Management", () => {
    it("allows users to subscribe to document notifications", () => {
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [1],
        address1
      );
      expect(result).toBeOk();
      expect(result).toBeBool(true);
    });

    it("checks subscription status correctly", () => {
      // Subscribe first
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [2],
        address1
      );

      // Check subscription status
      const { result } = simnet.callReadOnlyFn(
        "E-Governance-Document-Signing",
        "is-subscribed",
        [2, address1],
        address1
      );
      expect(result).toBeBool(true);
    });

    it("allows users to unsubscribe from notifications", () => {
      // Subscribe first
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [3],
        address1
      );

      // Then unsubscribe
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "unsubscribe",
        [3],
        address1
      );
      expect(result).toBeOk();
      expect(result).toBeBool(true);
    });

    it("prevents duplicate subscriptions", () => {
      // First subscription
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [4],
        address1
      );

      // Duplicate subscription should fail
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [4],
        address1
      );
      expect(result).toBeErr();
      expect(result).toBeUint(1001); // ERR-ALREADY-SUBSCRIBED
    });
  });

  describe("Notification Preferences", () => {
    it("allows users to set notification preferences", () => {
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "set-notification-preferences",
        [true, false, true, true, 2],
        address1
      );
      expect(result).toBeOk();
      expect(result).toBeBool(true);
    });

    it("returns default preferences for users without explicit settings", () => {
      const { result } = simnet.callReadOnlyFn(
        "E-Governance-Document-Signing",
        "get-preferences-or-default",
        [address2],
        address2
      );
      expect(result).toBeTuple({
        "email-alerts": true,
        "status-updates": true,
        "expiry-warnings": true,
        "allow-external": false,
        "min-gap": 0
      });
    });
  });

  describe("Notification Events", () => {
    it("allows sending notifications to subscribed users with default preferences", () => {
      // Subscribe user
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [5],
        address1
      );

      // Send notification
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [address1, 5, 1], // EMAIL type
        address1
      );
      expect(result).toBeOk();
      expect(result).toBeUint(1); // First notification ID
    });

    it("prevents sending notifications to unsubscribed users", () => {
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [address2, 6, 1], // EMAIL type
        address1
      );
      expect(result).toBeErr();
      expect(result).toBeUint(1002); // ERR-NOT-SUBSCRIBED
    });

    it("respects user opt-out preferences", () => {
      // Subscribe and set preferences to disable status updates
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [7],
        address2
      );
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "set-notification-preferences",
        [true, false, true, true, 0], // status-updates disabled
        address2
      );

      // Try to send status notification (should fail)
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [address2, 7, 2], // STATUS type
        address1
      );
      expect(result).toBeErr();
      expect(result).toBeUint(1004); // ERR-OPTED-OUT
    });

    it("enforces external sender restrictions", () => {
      // Subscribe with default preferences (allow-external = false)
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [8],
        address2
      );

      // Try to send from different address (should fail)
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [address2, 8, 1], // EMAIL type
        address1
      );
      expect(result).toBeErr();
      expect(result).toBeUint(1401); // ERR-UNAUTHORIZED
    });
  });

  describe("Read-Only Functions", () => {
    it("returns correct subscriber count for documents", () => {
      // Multiple users subscribe to same document
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [9],
        address1
      );
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [9],
        address2
      );

      // Check subscriber count
      const { result } = simnet.callReadOnlyFn(
        "E-Governance-Document-Signing",
        "get-subs-count-for-doc",
        [9],
        address1
      );
      expect(result).toBeUint(2);
    });

    it("returns correct event count for document-recipient pairs", () => {
      // Subscribe and send multiple notifications
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [10],
        address1
      );
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [address1, 10, 1], // EMAIL type
        address1
      );
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [address1, 10, 3], // EXPIRY type
        address1
      );

      // Check event count
      const { result } = simnet.callReadOnlyFn(
        "E-Governance-Document-Signing",
        "get-event-count",
        [10, address1],
        address1
      );
      expect(result).toBeUint(2);
    });
  });
});
