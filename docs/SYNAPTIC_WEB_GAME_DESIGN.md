# The Synaptic Web: Multiplayer Game Design Document

> *What if your team's knowledge graph was alive — and you had to keep it that way?*

---

## The Core Metaphor

The knowledge graph is reimagined as a **synaptic web** — a living neural network glowing in the dark. Concepts are **synapses**. Team members are **neurons**. When the team reviews and masters concepts, the network pulses with life — edges glow, nodes brighten, particles of light flow along connections like electrical impulses. When the team neglects it, the network doesn't just fade — it **fractures**.

This isn't a leaderboard bolted onto flashcards. It's a shared organism that the team tends together. The joy comes from watching it thrive, and the drama comes from watching it break — and rebuilding it together.

---

## The Four Tiers of Catastrophe

Network health is a composite score from 0.0 to 1.0, computed from team mastery coverage, concept freshness, and critical path analysis. As it drops, the visual and mechanical consequences escalate through four tiers. Each tier is designed to feel **dramatic but never punitive** — every catastrophe creates an opportunity for a heroic comeback.

### Tier 1 — Brownout (health < 70%)

**The lights are flickering.**

- Fading nodes flicker like dying lightbulbs — their opacity pulses irregularly, a subtle but unsettling visual rhythm
- Edges develop visual static: slight jitter in their rendered positions, like a bad signal
- A subtle pulse notification warns the team: *"Your network is dimming. 12 concepts need attention."*
- The ambient particle flow along healthy edges slows down, becoming sparse

**Recovery:** Review the flickering concepts. Each one reviewed triggers a satisfying **"power restored" surge animation** — the node snaps to full brightness and a pulse of light ripples outward along its edges to neighboring nodes, like electricity being restored to a grid. The team watches the network light back up in real time.

---

### Tier 2 — Cascade Warning (health < 50%)

**The network is distorting.**

- The force-directed graph **physically distorts**. Fading nodes lose their cohesion force in the simulation — they drift outward, creating visible gaps and stretched edges. The graph that was once a tight, beautiful web starts looking ragged and hollow.
- Red **"fracture lines"** appear: jagged dashed lines rendered over endangered edges, pulsing like warning lights. These are the edges most likely to break — the ones connecting concepts where both endpoints have low freshness.
- A countdown timer appears on the most vulnerable cluster: *"The CI/CD cluster fractures in 4h 22m."* This isn't a guess — it's computed from the current decay rate of the concepts in that cluster.
- **Push notification to the entire team.** This is the "rally the troops" moment.
- The particle system shifts from calm flowing light to agitated, erratic movement — sparks instead of smooth pulses

**Recovery:** Review concepts in the endangered cluster to push health back above 50%. The fracture lines fade, drifting nodes are pulled back into cohesion by restored spring forces, and the countdown disappears. The team just averted disaster.

---

### Tier 3 — Network Fracture (health < 30%)

**THE BIG ONE.**

This is the centerpiece event — the moment the game creates genuine shared drama.

- A bright **crack propagates** along the weakest edges. Not instant — it's animated, a jagged line of light racing from one fracture point to the next over 2-3 seconds, accompanied by a sharp visual flash at each breaking point.
- **Screen shakes.** On mobile, haptic feedback fires. On desktop, the canvas does a brief, sharp displacement. This should feel like something just *broke*.
- **The graph splits into drifting islands.** The force-directed simulation is modified: severed edges are removed, and without the attractive forces holding them together, the disconnected subgraphs drift apart. The gap between them grows slowly, inevitably.
- **Disconnected teammate avatars float into the void** between the islands. If a team member's mastered concepts span both sides of the fracture, their avatar node loses its anchor and drifts into the dark space between. A visual representation of being caught in the middle.
- A dramatic **"NETWORK FRACTURE"** overlay appears — recording the moment with a timestamp. This goes into the team's event history. *"February 10, 2026 — The Infrastructure-DevOps bridge fractured."*

**Consequences (the good kind):**
- Fractured concepts give **1.5x mastery credit** when reviewed. The game is saying: *"We know this is hard. Your effort counts more right now."*
- A **Repair Mission** auto-generates. It identifies the specific concepts that need to be reviewed to reconnect the islands, assigns them priority ordering, and creates a shared progress bar visible on everyone's dashboard.
- **The reconnection animation** is the payoff: as each fractured concept is reviewed, its edges re-form with an **electrical arc animation** — a bright, crackling line that snaps into place between the islands. With each reconnection, the islands drift slightly closer. When enough edges are restored, the force-directed simulation re-engages its attractive forces and the islands sweep back together in a satisfying convergence. The team just performed emergency surgery on their knowledge graph.

---

### Tier 4 — Total Collapse (health < 10%)

**Everything breaks. But one spark remains.**

This should happen rarely — maybe once in a team's lifetime. It's designed to be the most memorable moment in the game, not because it's punishing, but because the recovery is transcendent.

- Edges snap **one by one** like guitar strings. Each one makes a distinct visual "ping" — a flash of light along the edge before it disappears. The sound design (if we ever add audio) would be a descending series of plucked notes.
- Nodes scatter outward, repelling each other without any attractive edge forces. The beautiful web dissolves into a cloud of dim, disconnected points.
- **The canvas goes dark.** All nodes dim to near-invisibility. The background, which normally has subtle depth, becomes pure black.
- **Except one glowing node.** The most recently reviewed concept remains lit — a single point of light in the darkness. Text appears:

  > *"The network has collapsed. But one spark remains."*

**The Rekindling:**

This is not a punishment screen. This is the beginning of the best part.

- Each review **relights an adjacent node**. The reviewed concept brightens, and then — after a beat — light spreads along its edges to neighboring nodes, which glow faintly. The effect is like lighting a candle in a dark room and watching the light find the walls.
- The spread is organic and outward, like fire catching on kindling. Each review pushes the frontier of light further. Nodes that are two hops away get a faint hint of illumination, creating anticipation.
- At **50% relit**, the force-directed layout **re-engages**. The scattered nodes, now half-illuminated, are pulled back toward each other by their restored edges. The web reforms — not instantly, but over several seconds of animation, nodes sweeping inward and finding their places.
- This is the **phoenix-from-the-ashes moment**. The team watches their knowledge graph reassemble itself from scattered embers into a living network. The first time this happens, it should give you chills.

---

## The Guardian System

Concept clusters are detected automatically via **label propagation** on the relationship graph — a simple community detection algorithm that finds natural groupings (the "Infrastructure" cluster, the "Frontend" cluster, the "CI/CD" cluster). These clusters are the regions of the graph that the Guardian system operates on.

### How It Works

- Any team member can **volunteer as Guardian** of a concept cluster. This is an explicit opt-in — you're saying "I'll take responsibility for this region of our knowledge."
- Guardians get **priority notifications** when concepts in their cluster start fading. They're the first line of defense before a Brownout even begins.
- On the graph, a Guardian's avatar node has a **visual glow** connecting it to their cluster — a faint, warm tether that says "this person is watching over this region."
- Guardians earn **Guardian Points** for keeping their cluster's health above 80%. These accumulate over time and are displayed on the Glory Board.

### After a Fracture

When a fracture hits a cluster, the accountability dashboard doesn't shame — it rallies:

> *"The Infrastructure cluster needs a new guardian. Sarah is the nearest expert — rally her!"*

"Nearest expert" is computed from mastery overlap — who has reviewed the most concepts in that cluster? The game suggests, but never assigns. Guardianship is always voluntary.

### Guardian Badges

On the knowledge graph, a Guardian's connection to their cluster is rendered with a distinctive visual badge — a small shield icon or a glowing ring at the point where their avatar connects to the cluster. When the cluster is healthy (>80%), the badge pulses gently with green light. When it's endangered, the badge shifts to amber, then red.

---

## Cooperative Missions

### Team Goals

Time-boxed, team-wide objectives that anyone can create:

- *"Master all CI/CD concepts by Friday"* — computed from aggregate mastery across the team
- *"Keep health above 80% for 7 days"* — a maintenance challenge, requiring consistent daily engagement
- *"Light up the entire Infrastructure cluster"* — every concept in the cluster reaches mastered state

Progress is tracked from aggregate mastery. A progress bar appears on everyone's dashboard, updating in real time as team members complete reviews. When the goal is achieved, a celebratory animation plays — the relevant section of the graph pulses with golden light.

### Relay Challenges

A chain of concepts forms a relay race:

**Docker → Kubernetes → Helm → ArgoCD**

Each team member claims one **leg** of the relay. They have **24 hours** to master their assigned concept(s). When they complete their leg, the baton passes to the next person — visualized as a pulse of light traveling along the concept chain from the completed node to the next one.

The drama: if someone misses their 24-hour window, the relay doesn't fail — it stalls. The chain shows a gap, and the team can see exactly where the holdup is. Gentle social pressure, not punishment. The stalled person gets a nudge notification:

> *"The relay is waiting on you! Alex finished Kubernetes 6 hours ago."*

When the full relay completes, the entire chain lights up simultaneously with a cascading animation — each node firing in sequence like a string of lights.

### Repair Missions

Auto-generated after Network Fractures (Tier 3):

- The mission identifies the **specific concepts** that need review to reconnect the fractured islands
- Concepts are ordered by impact — reviewing the "bridge" concepts that connect the most disconnected nodes comes first
- **1.5x mastery scoring** applies to all mission concepts — the game rewards emergency response
- A **live progress bar** appears on everyone's dashboard: *"Repair Mission: 7/15 concepts reconnected"*
- As each concept is reviewed, the corresponding edge re-forms on everyone's graph with the electrical arc animation. The team watches the islands reconnect in real time.
- Mission completion triggers a "Network Restored" celebration — the graph snaps fully back together and a pulse of light radiates outward from the repair point

### Entropy Storms (Optional Weekly Events)

For teams that want an extra challenge:

- A scheduled event (opt-in, maybe every Wednesday) where **all freshness decays at 2x speed** for 48 hours
- Visually: storm particles sweep across the canvas — swirling, chaotic dots that replace the normal calm particle flow. The background shifts subtly darker. Edges flicker more aggressively. The whole graph feels like it's weathering a storm.
- The team's challenge: *"Can you maintain health above 70% during the storm?"*
- This creates a natural "rally day" where the team coordinates to review aggressively. It turns a solo activity (reviewing flashcards) into a shared event with stakes.
- Storm survival earns the team a badge and bonus Guardian Points for participants

---

## The Glory Board: "Who's Holding the Line"

This is explicitly **not a shame board**. It's a celebration board.

### What It Shows

- **Contribution scores** — how much each team member has contributed to network health this week/month
- **Guardian streaks** — consecutive days a Guardian has kept their cluster healthy
- **Repair hero** — who contributed most to the last Repair Mission
- **Storm survivor** — who reviewed the most during the last Entropy Storm
- **Most improved** — whose mastery growth rate is highest

### What It Doesn't Show

- No "worst performer" or "most neglected" categories
- No public display of overdue counts or decay rates
- The framing is always positive: who's doing great, not who's falling behind

### Visual Treatment

The top contributor gets a **glowing "Guardian" badge** rendered on their avatar node in the graph — a subtle golden aura that other team members can see. It rotates weekly, so the honor circulates. The badge isn't about competition; it's about recognition.

---

## Team Graph Overlay: Avatars as Neurons

Team members appear as **nodes in the graph itself**, not in a separate UI panel. Their profile photos are rendered as circular avatar nodes, composited directly onto the force-directed canvas.

### Visual Design

- Avatar nodes are larger than concept nodes (24px radius vs 18px)
- They're rendered with the team member's profile photo, clipped to a circle, with a **health ring** around the circumference
- The health ring color reflects their contribution level: green (active, high contribution) → amber (moderate) → red (many neglected concepts in their area)
- Avatar nodes have **weaker spring constants** in the force-directed simulation — they attract toward concepts they've mastered, but more gently, so they orbit the cluster periphery rather than crowding the center

### Connections

- Thin, translucent lines connect each avatar to the concepts they've mastered
- The lines pulse faintly with the team member's "activity color" — brighter if they've been active recently
- Guardian connections are rendered with the distinctive Guardian glow — thicker, warmer, more prominent

### Interaction

- Tapping an avatar shows a **friend card** with their mastery stats, Guardian assignments, recent activity, and current streak
- The card includes quick actions: Send Challenge, Send Nudge, View Mastery Overlap

---

## Network Health Scoring

The health score is a composite that captures both **breadth** (how many concepts are mastered) and **depth** (how fresh that mastery is):

```
score = 0.5 * (mastered / total)
      + 0.3 * (learning / total)
      + 0.2 * avg_freshness
      * (1.0 - 0.1 * at_risk_critical_paths / total_critical_paths)
```

### Components

- **Mastery coverage** (50% weight): What fraction of concepts have reached mastered state across the team?
- **Learning progress** (30% weight): What fraction are actively being learned? This rewards effort even before mastery is achieved.
- **Freshness** (20% weight): Average freshness across all concepts. This decays with time, creating the natural entropy that drives ongoing engagement.
- **Critical path penalty**: If concepts that are prerequisites for many others (high out-degree in the dependency graph) are at risk, the score takes a proportional hit. Losing a foundational concept is worse than losing a leaf.

### Ambient Visual Feedback

The health score isn't just a number — it's expressed through the entire visual atmosphere of the graph:

- **High health (>80%)**: Warm glow, smooth particle flow along edges, nodes at full brightness, gentle ambient pulse
- **Moderate health (50-80%)**: Cooler tones, slower particles, some nodes dimming, occasional flicker
- **Low health (30-50%)**: Visible distortion, red fracture lines, agitated particles, nodes drifting
- **Critical health (<30%)**: The catastrophe tiers take over

---

## Cluster Detection: Label Propagation

Communities in the concept graph are detected using **label propagation** — a simple algorithm (~60 lines) that works by:

1. Assign each node its own unique label
2. In each iteration, each node adopts the most common label among its neighbors
3. Repeat until labels stabilize
4. Nodes sharing the same label form a cluster

This naturally finds groups like "Infrastructure," "Frontend," "Security" without any manual tagging. The clusters are used for:

- Guardian assignments (guard a cluster, not individual concepts)
- Fracture visualization (fractures happen along cluster boundaries)
- Team Goals (target a specific cluster)
- Health sub-scoring (individual cluster health within overall health)

---

## The Emotional Arc

The game is designed around a specific emotional journey:

1. **Discovery** — "Oh cool, I can see my team's knowledge as a living graph"
2. **Pride** — "Look how bright our network is! We've mastered so much."
3. **Concern** — "Some nodes are flickering... we should review those"
4. **Urgency** — "The countdown says the CI/CD cluster fractures in 3 hours!"
5. **Drama** — "IT FRACTURED. The graph split in half. That was intense."
6. **Rally** — "Repair Mission activated. Let's reconnect this thing."
7. **Triumph** — "We did it! The islands snapped back together. That animation was incredible."
8. **Guardianship** — "I'm going to guard the Infrastructure cluster. It's not fracturing on my watch."

The cycle repeats. Each loop deepens the team's relationship with their knowledge graph and with each other. **Learning flashcards becomes tending a shared living thing.**

---

## Design Principles

### Never Punitive, Always Dramatic

Every catastrophe is designed to create **memorable shared moments**, not stress. The 1.5x scoring on fractured concepts, the Rekindling mechanic, the rally-not-shame framing — all of it says: "Something exciting happened. What will you do about it?"

### Visible to Everyone, Assigned to No One

Network health, fracture events, and repair missions are visible to the whole team. But the game never assigns blame or mandates action. Guardianship is voluntary. Relay legs are claimed, not assigned. The Glory Board celebrates, never shames.

### Beauty as Motivation

The visual payoff for keeping the network healthy should be genuinely beautiful — a glowing web of light with particles flowing along edges, nodes pulsing with warm color, avatars orbiting gracefully. People should *want* to keep it looking like that. The aesthetic itself is the reward.

### Solo Activity, Shared Stakes

Reviewing flashcards is inherently a solo activity. The game doesn't change that — you still sit down and review cards on your own. What it changes is the *context*. Your individual review session causes your node to brighten on everyone's graph. Your mastery of a relay concept passes the baton to your teammate. Your neglect causes visible flickering that your team can see. The solo act gains shared meaning.

---

## Future Possibilities (Undesigned)

These are ideas that emerged during design but aren't part of the current four phases. They're here so they don't get lost.

- **Network Archaeology**: After a Total Collapse and Rekindling, the graph could retain faint "scar lines" where the old fractures were — a visual history of past catastrophes that fades over weeks
- **Concept Champions**: Beyond Guardians, individual concepts could track who has the highest mastery of that specific concept. Their avatar gets a tiny crown icon on that node. Lightweight, fun.
- **Cross-Wiki Bridges**: If two teams on different wikis share overlapping concepts (detected by name similarity), their graphs could form a visible "bridge" between wiki-groups. Inter-team relay challenges across the bridge.
- **Seasonal Events**: Beyond Entropy Storms, seasonal themed events — "Knowledge Harvest" in autumn (bonus points for reviewing old concepts), "Spring Growth" (bonus for learning new concepts), etc.
- **Timelapse Mode**: A playback of the graph's evolution over weeks/months — watching it grow from a few nodes to a sprawling web, seeing fractures happen and heal, watching the team's collective knowledge literally take shape over time
- **Sound Design**: Each tier of catastrophe has a distinct audio signature. The Rekindling has music that builds as more nodes light up. The edge-snap during collapse sounds like plucked strings descending in pitch. The reconnection arc has a satisfying electrical crackle.
- **Feeding Mastery Back to Outline**: Once the team has strong mastery data, it could flow back into the wiki itself — annotating pages with team understanding levels, surfacing knowledge gaps ("Nobody on the team has mastered the Terraform section"), suggesting review assignments based on team coverage gaps.
