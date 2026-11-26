# Read-only MCP implementation

1. Verify the M365 candidate in the lab and keep the established Purview browser profile separate from M365 authentication.
2. Run one stdio server with separate PowerShell workers. Ship an explicit tool catalog with service-specific arguments and result schemas. Configuration belongs to the local operator. Listing tools or checking status starts no authentication.
3. Verify identity before releasing any tenant data. Detect session and tenant replacement during reads. Refresh can rebuild metadata on the same session, so verify the refreshed context before returning results. Stage reconnect in a separate worker and keep the previous worker if the candidate fails.
4. Keep Purview audit cursors in their owning worker. Expire them, cap their number, carry the original size, and consume them after a successful continuation. Expose only random handles to clients.
5. Bound worker traffic and execution time. Treat protocol failures as worker failures. Return fixed error codes and project explicit result fields.
6. Verify genuine MCP client calls over stdio, worker recovery, input validation, session drift, and audit capability lifetime. Run matching lab smoke checks against both providers.

Independent design review kept the shared host and isolated workers. It identified M365 metadata replacement during normal refresh, Purview verification expiry on refresh, tenant-scoped caches, and continuation counters that repeat in live responses. The verification and lifecycle tests cover those boundaries.
