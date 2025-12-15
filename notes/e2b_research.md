# E2B.dev Research : Orchestration & Management Layer

**Research Date:** 2025-11-21
**Question:** Does E2B have an orchestration & management layer like Kubernetes?

---

## TL;DR

**Yes, E2B has an orchestration & management layer, but NOT Kubernetes.**

They use **HashiCorp Nomad** for orchestration instead of Kubernetes, combined with a custom-built control plane architecture specifically designed for managing Firecracker microVMs at scale.

---

## Architecture Components

E2B's infrastructure consists of three primary layers:

### 1. **Control Plane** (E2B Cloud)
- Managed service providing cluster management
- Observability & monitoring
- Customer account management
- Does NOT handle sensitive data (in BYOC mode)

### 2. **Edge Controller**
- Routes traffic to sandboxes
- Exposes API for cluster management
- gRPC proxy for control plane ↔ orchestrator communication
- Acts as ingress layer

### 3. **Orchestrator**
- Core component managing sandbox lifecycle
- Responsible for starting, stopping, monitoring sandboxes
- Runs on each node in the cluster
- Optionally runs template builder component
- Uses **HashiCorp Nomad** for workload scheduling

---

## Key Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Orchestration** | HashiCorp Nomad | Workload scheduling & placement |
| **Isolation** | Firecracker microVMs | Secure sandbox execution |
| **Service Discovery** | Consul | Service coordination |
| **IaC** | Terraform | Infrastructure deployment |
| **Core Services** | Go (84.4% of codebase) | Backend APIs & control logic |

---

## Nomad vs Kubernetes

**Why Nomad instead of Kubernetes?**

E2B chose Nomad over Kubernetes likely because:

1. **Better microVM support** - Nomad handles non-container workloads more naturally
2. **Lighter weight** - Lower overhead for managing thousands of ephemeral VMs
3. **Flexible scheduling** - More suited for diverse workload types (containers + VMs)
4. **Simpler operations** - Easier to manage than K8s for their specific use case

**What this means:**
- E2B *does* have orchestration capabilities comparable to Kubernetes
- But uses a different technology stack optimized for microVMs
- Still provides cluster management, horizontal scaling, workload scheduling

---

## Orchestration Capabilities

### What E2B Provides:

✅ **Horizontal scaling** - Add more orchestrators & edge controllers
✅ **Lifecycle management** - Start, stop, monitor sandboxes
✅ **Resource scheduling** - Nomad places workloads on available nodes
✅ **Traffic routing** - Edge controller handles ingress
✅ **Service discovery** - Consul coordinates services
✅ **Health monitoring** - Control plane observability

### What E2B Does NOT Provide:

❌ **Direct orchestration API** - Users interact via SDKs, not orchestration APIs
❌ **Multi-tenancy control plane** - Control plane is E2B-managed (unless self-hosted)
❌ **Custom resource definitions** - No CRD-like extensibility
❌ **Native Kubernetes integration** - Different orchestration paradigm

---

## Deployment Models

### 1. **E2B Cloud (Managed)**
- E2B runs control plane
- Customer uses SDKs to create sandboxes
- Fully managed infrastructure

### 2. **BYOC (Bring Your Own Cloud)**
- Customer VPC deployment
- All sensitive traffic stays in customer cloud
- E2B control plane only for management
- Uses Terraform for deployment
- Supported: GCP (full), AWS (in progress)

### 3. **Self-Hosted**
- Full control over all components
- Deploy entire stack in your infrastructure
- Terraform-based deployment
- Requires managing control plane yourself

---

## Scale & Performance

**Production Stats:**
- Used by ~50% Fortune 500 companies
- 88% of Fortune 100 companies
- Millions of sandboxes created weekly
- Sandbox startup: ~150ms
- Session duration: Up to 24 hours
- 10x increase in avg sandbox runtime (2024→2025)

**Scaling Pattern:**
```
Control Plane (E2B Cloud)
    ↓ gRPC
Edge Controllers (Customer VPC) ← Horizontal scaling
    ↓ Traffic routing
Orchestrators (Customer VPC) ← Horizontal scaling
    ↓ Manages
Firecracker microVMs (Sandboxes) ← Dynamic scaling
```

---

## Comparison : E2B vs Kubernetes

| Feature | E2B (Nomad-based) | Kubernetes |
|---------|-------------------|------------|
| **Orchestration** | HashiCorp Nomad | K8s control plane |
| **Workload Type** | Firecracker microVMs | Containers (pods) |
| **Startup Time** | ~150ms | ~1-5 seconds |
| **Use Case** | AI code execution | General-purpose |
| **Extensibility** | SDK-based | CRD-based |
| **Complexity** | Lower | Higher |
| **Multi-cloud** | Terraform IaC | Cloud-specific |

---

## User Experience

**From Developer Perspective:**

Users **do NOT** interact with orchestration layer directly. Instead:

```python
# Python SDK example
from e2b import Sandbox

# SDK abstracts orchestration complexity
sandbox = Sandbox()  # Control plane → Orchestrator → VM
result = sandbox.run_code("print('hello')")
sandbox.close()
```

**Behind the scenes:**
1. SDK calls E2B API
2. Control plane routes to edge controller
3. Edge controller talks to orchestrator
4. Orchestrator uses Nomad to schedule microVM
5. Firecracker starts VM (~150ms)
6. Result returned to user

---

## Answer to Original Question

**Q: Does E2B have an orchestration & management layer like Kubernetes?**

**A: Yes, but with a different architecture:**

- **Orchestration:** HashiCorp Nomad (not K8s)
- **Management:** Custom control plane + edge controller
- **Scaling:** Horizontal (add nodes/controllers)
- **Abstraction:** SDK-based (users don't interact with orchestration directly)

**Key Difference from Kubernetes:**
- K8s users interact with control plane (kubectl, APIs, CRDs)
- E2B users interact with SDKs (orchestration is hidden implementation detail)

**Kubernetes-like capabilities E2B HAS:**
- ✅ Cluster management
- ✅ Workload scheduling
- ✅ Horizontal scaling
- ✅ Health monitoring
- ✅ Service discovery
- ✅ Traffic routing

**Kubernetes-like capabilities E2B LACKS:**
- ❌ Direct API for orchestration primitives
- ❌ Custom resource definitions
- ❌ Native container support (focused on microVMs)
- ❌ Declarative YAML manifests

---

## Strategic Implications

**If you're considering E2B:**

**Choose E2B if:**
- Need secure AI code execution sandboxes
- Want fast startup times (~150ms)
- Prefer managed service (don't want to run orchestration)
- Building AI agents that need isolated compute

**Consider alternatives if:**
- Need direct control over orchestration
- Want Kubernetes-native integration
- Need custom scheduling policies
- Building general-purpose compute platform

**Bottom Line:**
E2B has sophisticated orchestration (Nomad + custom control plane), but it's an **implementation detail**, not a user-facing feature. Users get sandbox-as-a-service, not orchestration-as-a-service.

---

## References

- E2B Architecture Docs: https://e2b.dev/docs/byoc
- E2B Infrastructure Repo: https://github.com/e2b-dev/infra
- E2B Main Repo: https://github.com/e2b-dev/E2B
- BYOC Architecture: https://e2b.dev/docs/byoc

---

**Summary for Product/Architecture Decisions:**

E2B's orchestration layer exists but is **opinionated & abstracted**. It uses Nomad (not K8s) & custom control plane. Good for AI sandboxes, but if you need general-purpose orchestration APIs or K8s integration, consider alternatives like running your own K8s cluster with Firecracker/Kata Containers.
