# API and backend strategy

Run the service for real and hit it like a client would. Write outputs under `{run}/api/`.

## Start the service

Start it the way the project does (scripts, `docker compose`, Makefile), with dependencies it needs, logs redirected to `{run}/api/server.log`. Wait for a health check or the port. Seed data through the project's own seed path or through the API itself, and record what you seeded.

## Exercise each claim

Send real requests with `curl -sS -i` (or the project's client). Save each exchange as `{run}/api/{claim}-{nn}-{slug}.txt` holding the full request (method, URL, headers, body) and the full response (status, headers, body). The caption states what the exchange proves.

Assert on status, body shape and the values the claim promises. When a claim implies persistence or a side effect (a row written, a message published, a cache invalidated), check the side effect directly: query the database, read the queue, call the read endpoint.

Cover the error surface: invalid input, missing auth, wrong role, not found, conflict, and a dependency that is down or slow when the diff touches that call.

## Logs

After each claim, cut the matching slice of `server.log` into `{run}/api/{claim}-server.log`. Any stack trace or error-level line during a passing flow goes into `risks`.

## Compatibility

When the diff changes a response shape, a route, or a schema, list every field added, removed or retyped, and search the repo for consumers of the old shape. A breaking change with consumers in reach is a finding.
