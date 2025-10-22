
import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

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
        [Cl.uint(1)],
        address1
      );
      expect(result).toBeOk(Cl.bool(true));
    });

    it("checks subscription status correctly", () => {
      // Subscribe first
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(2)],
        address1
      );

      // Check subscription status
      const { result } = simnet.callReadOnlyFn(
        "E-Governance-Document-Signing",
        "is-subscribed",
        [Cl.uint(2), Cl.principal(address1)],
        address1
      );
      expect(result).toBeBool(true);
    });

    it("allows users to unsubscribe from notifications", () => {
      // Subscribe first
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(3)],
        address1
      );

      // Then unsubscribe
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "unsubscribe",
        [Cl.uint(3)],
        address1
      );
      expect(result).toBeOk(Cl.bool(true));
    });

    it("prevents duplicate subscriptions", () => {
      // First subscription
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(4)],
        address1
      );

      // Duplicate subscription should fail
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(4)],
        address1
      );
      expect(result).toBeErr(Cl.uint(1001)); // ERR-ALREADY-SUBSCRIBED
    });
  });

  describe("Notification Preferences", () => {
    it("allows users to set notification preferences", () => {
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "set-notification-preferences",
        [Cl.bool(true), Cl.bool(false), Cl.bool(true), Cl.bool(true), Cl.uint(2)],
        address1
      );
      expect(result).toBeOk(Cl.bool(true));
    });

    it("returns default preferences for users without explicit settings", () => {
      const { result } = simnet.callReadOnlyFn(
        "E-Governance-Document-Signing",
        "get-preferences-or-default",
        [Cl.principal(address2)],
        address2
      );
      expect(result).toBeTuple({
        "email-alerts": Cl.bool(true),
        "status-updates": Cl.bool(true),
        "expiry-warnings": Cl.bool(true),
        "allow-external": Cl.bool(false),
        "min-gap": Cl.uint(0)
      });
    });
  });

  describe("Notification Events", () => {
    it("allows sending notifications to subscribed users with default preferences", () => {
      // Subscribe user
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(5)],
        address1
      );

      // Send notification
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [Cl.principal(address1), Cl.uint(5), Cl.uint(1)], // EMAIL type
        address1
      );
      expect(result).toBeOk(Cl.uint(1)); // First notification ID
    });

    it("prevents sending notifications to unsubscribed users", () => {
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [Cl.principal(address2), Cl.uint(6), Cl.uint(1)], // EMAIL type
        address1
      );
      expect(result).toBeErr(Cl.uint(1002)); // ERR-NOT-SUBSCRIBED
    });

    it("respects user opt-out preferences", () => {
      // Subscribe and set preferences to disable status updates
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(7)],
        address2
      );
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "set-notification-preferences",
        [Cl.bool(true), Cl.bool(false), Cl.bool(true), Cl.bool(true), Cl.uint(0)], // status-updates disabled
        address2
      );

      // Try to send status notification (should fail)
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [Cl.principal(address2), Cl.uint(7), Cl.uint(2)], // STATUS type
        address1
      );
      expect(result).toBeErr(Cl.uint(1004)); // ERR-OPTED-OUT
    });

    it("enforces external sender restrictions", () => {
      // Subscribe with default preferences (allow-external = false)
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(8)],
        address2
      );

      // Try to send from different address (should fail)
      const { result } = simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [Cl.principal(address2), Cl.uint(8), Cl.uint(1)], // EMAIL type
        address1
      );
      expect(result).toBeErr(Cl.uint(1401)); // ERR-UNAUTHORIZED
    });
  });

  describe("Read-Only Functions", () => {
    it("returns correct subscriber count for documents", () => {
      // Multiple users subscribe to same document
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(9)],
        address1
      );
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(9)],
        address2
      );

      // Check subscriber count
      const { result } = simnet.callReadOnlyFn(
        "E-Governance-Document-Signing",
        "get-subs-count-for-doc",
        [Cl.uint(9)],
        address1
      );
      expect(result).toBeUint(2);
    });

    it("returns correct event count for document-recipient pairs", () => {
      // Subscribe and send multiple notifications
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "subscribe",
        [Cl.uint(10)],
        address1
      );
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [Cl.principal(address1), Cl.uint(10), Cl.uint(1)], // EMAIL type
        address1
      );
      simnet.callPublicFn(
        "E-Governance-Document-Signing",
        "send-notification",
        [Cl.principal(address1), Cl.uint(10), Cl.uint(3)], // EXPIRY type
        address1
      );

      // Check event count
      const { result } = simnet.callReadOnlyFn(
        "E-Governance-Document-Signing",
        "get-event-count",
        [Cl.uint(10), Cl.principal(address1)],
        address1
      );
      expect(result).toBeUint(2);
    });
  });
});
