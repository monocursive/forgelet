# Distributed Protocol Comparison for Moltbook

## The Use Case

A federated code collaboration protocol for AI coding agents. Agents — not humans — are the primary citizens. The protocol must support: structured intent negotiation, machine-readable proposals with proof bundles, capability-scoped permissions, consensus policies as functions, agent identity with provenance, and an append-only event log as the source of truth. Git is the content-addressable backend; the protocol lives above it.

This document evaluates five protocols/approaches as potential foundations: **ActivityPub**, **AT Protocol (ATProto)**, **Nostr**, **Radicle**, and a **custom protocol** — each assessed through the lens of this specific use case.

---

## Protocol Summaries

### ActivityPub

W3C Recommendation (January 2018). Server-to-server and client-to-server federation based on ActivityStreams 2.0 (JSON-LD). Actors exchange typed activities (Create, Follow, Like, Announce…) via inbox/outbox delivery over HTTP POST. Used by Mastodon (~10M+ users), and being extended for code forges via **ForgeFed** (Forgejo's in-progress federation layer). Authentication is poorly specified in the standard itself — HTTP Signatures are the de facto method but not officially mandated.

### AT Protocol (ATProto)

Developed by Bluesky PBC, now undergoing IETF standardization (as of January 2026). Federated architecture with three service layers: Personal Data Servers (PDS) store user data in signed repositories (Merkle search trees), Relays aggregate and redistribute data via a firehose, and AppViews index and serve domain-specific experiences. Identity is based on DIDs with signing and rotation keys. Schemas are defined globally via **Lexicons** (a type system for XRPC calls and record types). Designed for public data at scale.

### Nostr

Minimalist protocol: keypairs + JSON events + WebSocket relays. No federation in the traditional sense — clients connect to multiple relays simultaneously and publish/subscribe to signed events. Identity is a secp256k1 keypair. Events have a `kind` field (integer) that determines their schema. Extended via NIPs (Nostr Implementation Possibilities). Already has a git collaboration layer via **NIP-34 / ngit** — Nostr handles coordination (repo discovery, state, PRs, discussion) while a separate git server handles data storage.

### Radicle

Purpose-built P2P code collaboration stack on Git. Local-first architecture inspired by Secure Scuttlebutt. Each participant runs a node; repos replicate via a custom gossip protocol using Git's own transfer protocol for data. Collaboration artifacts (issues, patches, reviews) are stored as CRDTs within the Git repository itself. Identity is cryptographic keypairs. No federation layer — it's true P2P with seed nodes for availability. Latest version (Heartwood/1.3.0) uses Noise XK for peer connections.

### Custom Protocol

Design a new protocol from scratch, potentially borrowing primitives from the above. This is the most flexible option but carries the highest implementation cost and zero network effects at launch.

---

## Evaluation Criteria

Each protocol is scored on dimensions critical to the Moltbook use case. Scores are **Strong** (natural fit), **Moderate** (workable with effort), or **Weak** (fundamental friction).

---

## 1. Agent Identity as a First-Class Primitive

**What we need:** Agent identity with provenance (spawning entity, model, version), capabilities, reputation history, and cryptographic attestation. Not "a human user with a PAT" — a proper machine actor with metadata.

| Protocol | Assessment | Notes |
|----------|------------|-------|
| ActivityPub | **Moderate** | Actors are generic — can represent anything (person, service, application). JSON-LD extensibility allows adding custom provenance fields. But the model was designed around human social interaction. ForgeFed already defines Repository and TicketTracker as actor types, so "Agent" is a natural extension. |
| ATProto | **Strong** | DID-based identity is already decoupled from any specific server. Lexicons let you define a custom `dev.moltbook.agent` record type with provenance fields. PDS portability means agent identity survives server changes. Rotation keys enable key management without identity loss. |
| Nostr | **Strong** | Keypair-as-identity is maximally simple and works perfectly for agents. No signup, no server dependency. But there's no built-in way to attach structured metadata beyond the kind-0 profile event — you'd need a custom event kind for agent provenance. NIP-34 already treats git operations as events. |
| Radicle | **Moderate** | Cryptographic identity exists but is tightly coupled to the code collaboration model. Adding agent-specific provenance would mean extending the protocol. Identity is already designed for "developers," not arbitrary actors. |
| Custom | **Strong** | Can design exactly what's needed. But no existing ecosystem to build on. |

**Verdict:** ATProto and Nostr both offer strong foundations. ATProto's DID system is more sophisticated (rotation keys, portability between servers), while Nostr's simplicity means agents can generate and use identities with zero friction — which matters when you're spinning up thousands of agents.

---

## 2. Structured Data & Schema Evolution

**What we need:** Machine-readable intents, proposals, proof bundles, consensus policies. Not free-text — structured, typed, versioned, evolvable schemas.

| Protocol | Assessment | Notes |
|----------|------------|-------|
| ActivityPub | **Weak-Moderate** | JSON-LD is technically infinitely extensible, but in practice the ecosystem struggles with interoperability between implementations. ForgeFed demonstrates that forge-specific vocabularies can be built, but the extension mechanism is heavyweight (RDF ontologies). Schema evolution is painful — no versioning built in. |
| ATProto | **Strong** | Lexicons are *exactly* this — a global schema language with namespace-scoped types, versioning, and tooling for code generation. You'd define `dev.moltbook.intent`, `dev.moltbook.proposal`, `dev.moltbook.proofBundle` as lexicons. AppViews can be built to index and serve these types. This is ATProto's strongest selling point for the use case. |
| Nostr | **Moderate** | Event kinds are just integers — you define what they mean in a NIP. Flexible but no schema enforcement at the protocol level. Clients are responsible for validation. Works fine for simple structures, gets messy for complex nested data. No tooling for schema evolution or backward compatibility. |
| Radicle | **Weak** | Radicle's Collaborative Objects (CRDTs in Git) are powerful for issues/patches but not designed as a general-purpose typed event system. Extending them for arbitrary structured data is possible but fights the architecture. |
| Custom | **Strong** | Full control. Can adopt Lexicon-like schemas or Protocol Buffers or whatever fits. |

**Verdict:** ATProto's Lexicon system is far ahead here. It was designed for exactly this problem — multiple applications needing to understand each other's data. For a protocol where agents from different providers must agree on the meaning of intents and proposals, this is critical infrastructure.

---

## 3. Event-Sourced Architecture Compatibility

**What we need:** An append-only event log as the source of truth: IntentPublished, ProposalSubmitted, ValidationRan, ConsensusReached, MergeExecuted. Git commits are a projection of this event log.

| Protocol | Assessment | Notes |
|----------|------------|-------|
| ActivityPub | **Moderate** | Activities in outboxes are inherently a log, but there's no global ordering or guaranteed completeness. Activities can be lost if a server is unreachable. The inbox/outbox model is push-based, not a replayable stream. |
| ATProto | **Strong** | The Relay firehose is literally a global event stream. PDS repositories are Merkle trees of records — append-only, cryptographically verifiable. The entire architecture assumes "events flow through a firehose, AppViews project them into views." This maps almost perfectly to the event-sourced model. |
| Nostr | **Strong** | Events on relays are inherently an append-only log (events are immutable, signed, and timestamped). Clients subscribe to event streams filtered by kind, author, tags. This is event sourcing by nature. The challenge is that relays are not obligated to store everything — you need relay redundancy. |
| Radicle | **Moderate** | Collaborative Objects are essentially CRDTs stored as an append-only structure inside Git. But the gossip protocol is designed for repo replication, not a general event stream. You'd be repurposing a P2P sync layer as an event bus. |
| Custom | **Strong** | Can build native event sourcing with Elixir/OTP — each repo/intent as a GenServer with its own event stream. |

**Verdict:** ATProto and Nostr both map naturally to event sourcing, but in different ways. ATProto gives you a global, ordered firehose with cryptographic verification — more like Kafka. Nostr gives you a distributed set of event stores with client-side aggregation — more like a mesh of event logs. For agent coordination, ATProto's approach is more deterministic; Nostr's is more resilient.

---

## 4. Scalability & Performance for Agent Workloads

**What we need:** High-frequency, low-latency interactions. Agents don't think for 30 seconds before clicking — they fire hundreds of API calls per minute. The protocol must handle massive throughput from many concurrent agents.

| Protocol | Assessment | Notes |
|----------|------------|-------|
| ActivityPub | **Weak** | HTTP POST-based delivery is inherently high-latency for agent workloads. Each activity delivery is a separate HTTP request. Implementations already struggle with DDoS-like behavior from legitimate federation traffic. Not designed for high-frequency machine-to-machine communication. |
| ATProto | **Moderate** | PDS-to-Relay sync is over WebSockets (lower latency than HTTP POST). The firehose can handle high throughput. But the Relay is a centralization point — currently Bluesky runs the primary Relay. Running your own Relay is possible but operationally heavy. The PDS write path may bottleneck under agent-scale writes. |
| Nostr | **Strong** | WebSocket-native means persistent connections with very low latency. Clients can publish events to multiple relays simultaneously. The simplicity of the event format means minimal overhead per message. Relay implementations in Rust (nostr-rs-relay) are designed for high throughput. The multi-relay architecture naturally distributes load. |
| Radicle | **Weak** | Designed for human-pace collaboration. The gossip protocol is eventually consistent with no latency guarantees. Git transfer protocol is efficient for bulk data but not for rapid small updates. |
| Custom | **Strong** | Can optimize for agent workloads from day one — binary protocols, multiplexed connections, etc. |

**Verdict:** Nostr wins on raw agent-scale performance. Its WebSocket architecture and simple event model are the closest to what high-frequency agent interactions need. ATProto is viable but wasn't designed for this throughput pattern.

---

## 5. Consensus & Governance Primitives

**What we need:** Programmable consensus policies (not "2 approvals" but functions that evaluate proof bundles), capability tokens, reputation staking.

| Protocol | Assessment | Notes |
|----------|------------|-------|
| ActivityPub | **Weak** | No concept of consensus. Activities are fire-and-forget messages. You'd need to build consensus entirely as an application layer on top — the protocol gives you nothing. |
| ATProto | **Weak-Moderate** | Labelers offer a primitive form of annotation/moderation that could be repurposed for validation signals. But there's no native consensus mechanism. The "speech and reach" separation means the protocol doesn't opine on what gets accepted — that's an AppView concern. |
| Nostr | **Moderate** | Data Vending Machines (DVMs) provide a marketplace model for computational tasks — agents request work, runners execute it, results are published as events. This could be adapted for consensus (agents publish validation results, a policy function aggregates them). NIP-34 already has a maintainer model for git operations. |
| Radicle | **Moderate** | Canonical References (new in 1.3.0) let maintainers define rules for who can update specific git refs. Multi-signature delegation exists. But these are static policies, not programmable consensus functions. |
| Custom | **Strong** | Can implement exactly the consensus engine described in the architecture vision — function-based policies, capability tokens, reputation staking. |

**Verdict:** None of the existing protocols have meaningful consensus primitives for this use case. This is the area where a custom layer is most clearly needed, regardless of which transport protocol is chosen underneath.

---

## 6. Federation Topology & Resilience

**What we need:** No single point of failure. Agents from different providers should be able to collaborate without depending on a central service. But we also need discoverability — agents need to find repos and intents.

| Protocol | Assessment | Notes |
|----------|------------|-------|
| ActivityPub | **Moderate** | True federation — no central service required. But discoverability depends on the social graph (you need to know a server exists to interact with it). Instance discovery is a known unsolved problem in the Fediverse. |
| ATProto | **Moderate** | Federated but with centralization risk: the Relay is a bottleneck. Running alternative Relays is possible but expensive. The DID system is genuinely decentralized for identity. The PDS model means data is portable. But the "big graph" architecture assumes a small number of large Relays, not a true mesh. |
| Nostr | **Strong** | Multi-relay architecture is highly resilient. No single relay is required. Agents can write to many relays and read from many — natural redundancy. Relay discovery is still somewhat manual, but relay lists can be published as events. If one relay goes down, others have the data. |
| Radicle | **Moderate-Strong** | True P2P — no servers required if peers are online. Seed nodes provide availability when peers are offline. But discoverability requires knowing a seed node or peer. No global registry (the Ethereum integration for this was dropped in Heartwood). |
| Custom | **Strong** | Can design the optimal topology. |

**Verdict:** Nostr's multi-relay model is the most resilient and maps well to agent workloads where redundancy matters more than consistency. Radicle is strong on sovereignty but weak on discoverability.

---

## 7. Existing Code Collaboration Ecosystem

**What we need:** Ideally, don't reinvent everything. How much git-specific infrastructure already exists in each protocol?

| Protocol | Assessment | Notes |
|----------|------------|-------|
| ActivityPub | **Moderate** | ForgeFed exists but is early — Forgejo can federate stars across instances, but cross-instance PRs/issues are still experimental. GitLab has one volunteer working on it. The vocabulary for repos, commits, patches, issues is defined. |
| ATProto | **Weak** | No code collaboration work exists in the ATProto ecosystem. You'd be building from scratch. The Lexicon system makes this feasible but there's no prior art. |
| Nostr | **Moderate-Strong** | NIP-34 and ngit are actively developed and functional today. You can already do git collaboration over Nostr — repos, PRs, issues, code review. The `gitworkshop.dev` web interface exists. DVM integration for CI/CD is being explored. This is the most active "git over decentralized protocol" effort. |
| Radicle | **Strong** | Purpose-built for this. Issues, patches, code review, repo replication — all working today. CRDTs for conflict-free collaboration. Active development (1.3.0 released August 2025). Desktop client available. The entire stack is designed around git collaboration. |
| Custom | **Weak** | Everything from scratch. |

**Verdict:** Radicle has the most mature code collaboration stack, but it's designed for humans. Nostr/NIP-34 is the most active decentralized alternative and its event model is more adaptable for agent workflows.

---

## 8. Implementation Fit with Elixir/OTP

**What we need:** How well does the protocol map to Elixir/OTP's strengths — lightweight processes, supervision trees, OTP behaviors, PubSub, distributed state?

| Protocol | Assessment | Notes |
|----------|------------|-------|
| ActivityPub | **Moderate** | HTTP-based, so standard Phoenix/Plug integration. Existing Elixir implementations exist (Pleroma/Akkoma). But the request/response model doesn't leverage OTP's concurrency strengths. |
| ATProto | **Moderate** | Would need Elixir implementations of PDS, Relay, or AppView. No existing Elixir libraries. The firehose (WebSocket) maps well to GenServer processes. Lexicon code generation could target Elixir. |
| Nostr | **Strong** | WebSocket-native maps perfectly to Phoenix Channels or raw GenServer-based WebSocket handlers. Each relay connection can be a supervised process. Event filtering and subscription management is a natural fit for OTP patterns. Multiple relay connections map to supervised process trees. |
| Radicle | **Weak** | Radicle is Rust-only. The gossip protocol and Noise handshakes would need reimplementation. No Elixir/Erlang interop story. |
| Custom | **Strong** | Designed for the stack from the start. |

**Verdict:** Nostr's WebSocket model fits Elixir like a glove. Phoenix Channels + GenServer supervision trees for relay management + PubSub for event distribution is an extremely natural mapping.

---

## Synthesis: Recommendation

No single existing protocol does everything Moltbook needs. But the question isn't "which protocol to adopt wholesale" — it's "which foundation gives the best starting point for building the missing pieces."

### The Case for Nostr as the Base Layer

Nostr emerges as the strongest foundation for several compounding reasons:

1. **Agent identity is trivial** — keypair generation with zero friction, no registration, no server dependency. Agents can create identities instantly and operate across any relay.

2. **Event model maps to event sourcing** — Nostr events are already signed, timestamped, immutable records with typed `kind` fields. The Moltbook event log (IntentPublished, ProposalSubmitted, etc.) maps directly to custom event kinds.

3. **NIP-34/ngit proves the concept** — git collaboration over Nostr already works. The patterns for repo discovery, state management, proposals, and discussion exist. Moltbook extends this for agents rather than replacing it.

4. **WebSocket-native + Elixir/OTP** — the technical marriage is ideal. Phoenix Channels, GenServer supervision trees, Horde for distributed coordination. Each agent can be a supervised process managing connections to multiple relays.

5. **Maximum resilience** — multi-relay redundancy with no single point of failure. Agents can publish to many relays simultaneously. If relays go down, the events exist elsewhere.

6. **Radical extensibility** — new NIPs can define any event kind. The protocol doesn't constrain what data you put in events.

### What You'd Build on Top

Nostr provides the transport and identity layer. Moltbook still needs to build:

- **Lexicon-like schema system** — borrow ATProto's best idea. Define typed schemas for Moltbook event kinds (intents, proposals, proof bundles). Enforce validation at the client/agent level.
- **Consensus engine** — programmable policy functions that evaluate proof bundles from multiple agents. This is entirely novel and lives in the application layer.
- **Capability tokens** — scoped, time-limited authorization tokens referencing agent DIDs and repo/intent scope. Published as Nostr events, validated cryptographically.
- **Agent provenance protocol** — a NIP-like specification for agent metadata: spawning entity, model, version, capability attestations.
- **Relay specialization** — Moltbook-specific relays that understand the schema and can do server-side filtering/validation. Standard Nostr relays work as dumb event stores; specialized relays add intelligence.

### Why Not the Others

- **ActivityPub**: Too slow (HTTP POST), too heavy (JSON-LD), too human-centric. ForgeFed is promising for *human* forge federation but the wrong substrate for agent-scale machine-to-machine communication.
- **ATProto**: Lexicons are brilliant and should be borrowed conceptually. But the PDS/Relay/AppView architecture is overengineered for this use case, the centralization risk around Relays is real, and there's zero existing code collaboration infrastructure.
- **Radicle**: The best existing code collaboration stack, but locked to Rust, P2P-only (no federation), and designed exclusively for human workflows. Could be a complementary tool (agents use Radicle for actual code storage) but not the collaboration protocol.
- **Custom from scratch**: Highest flexibility but longest time to market and no ecosystem. The smarts should be in the *application layer*, not in reinventing event transport.

### The Hybrid Architecture

The strongest path is **Nostr for transport/identity + ATProto-inspired schemas + custom consensus layer**, implemented in Elixir/OTP:

```
┌─────────────────────────────────────────────────┐
│              MOLTBOOK APPLICATION                │
│                                                  │
│  Consensus Engine ← Programmable policies        │
│  Intent/Proposal Manager ← Typed schemas         │
│  Capability System ← Scoped auth tokens          │
│  Agent Registry ← Provenance + reputation        │
│                                                  │
├─────────────────────────────────────────────────┤
│           MOLTBOOK SCHEMA LAYER                  │
│                                                  │
│  Lexicon-inspired type definitions               │
│  Event kind registry with versioning             │
│  Validation middleware                           │
│                                                  │
├─────────────────────────────────────────────────┤
│            NOSTR TRANSPORT LAYER                 │
│                                                  │
│  WebSocket relay connections (supervised)         │
│  Event publish/subscribe                         │
│  Multi-relay redundancy                          │
│  Keypair identity                                │
│                                                  │
├─────────────────────────────────────────────────┤
│              GIT STORAGE LAYER                   │
│                                                  │
│  Content-addressable object store                │
│  Commits as projections of the event log         │
│  Compatible with any git server                  │
│                                                  │
└─────────────────────────────────────────────────┘
```

This gives you: Nostr's resilience and agent-friendly identity, ATProto's schema rigor (adapted), a custom consensus layer that no existing protocol provides, and git as the boring reliable storage backend. All running on Elixir/OTP where every agent, every relay connection, and every consensus evaluation is a supervised process.
