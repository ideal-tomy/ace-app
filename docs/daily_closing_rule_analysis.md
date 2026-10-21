# Daily closing Firestore rule analysis

## Paths and operations

- `stores/{storeId}/checks/{checkId}`: read all checks for the admin sales page.
- `stores/{storeId}/daily_closings/{yyyy-MM-dd}`: admin read/create only.
- `stores/{storeId}/daily_closings/{yyyy-MM-dd}/checks/{checkId}`: admin read/create only.

## Daily closing schema

Required fields: `businessDate` (timestamp), `businessDateKey` (string), `status`
(`closed`), total/event/normal sales, check counts, guest counts (non-negative
integers), `closedAt` (server timestamp), `closedBy` (authenticated UID), and
`schemaVersion` (`1`). Totals and component counts must balance.

## Closing check snapshot schema

Required fields: `businessDateKey`, `checkId`, `customerName`, `billingMode`,
`peopleCount`, `finalAmount`, `taxAmount`, `closedAt`, `paymentMethod`
(`cash` / `card` / `other`), `eventAmount`, and `normalAmount`.
`eventAmount + normalAmount` must equal `finalAmount`. Documents are immutable.

## Security decisions

- Only store admins may read or create closings and snapshots.
- Clients cannot update or delete a closed day.
- Strict field lists, types, string lengths, numeric ranges, identity checks, and
  component-total checks are enforced.
- A snapshot create requires the parent closing to exist after the same atomic
  transaction via `getAfter()`.
- Existing application-wide administrator semantics remain unchanged and are a
  separate known risk from this feature.
