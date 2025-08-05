# GitOps Resource Management Workflow Diagram

This diagram shows the flow of the `resourceManagement.yml` GitOps configuration for automated issue management and triage.

```mermaid
flowchart TD
    A[New Issue Opened] --> B{Check Issue Body Content}
    
    B -->|Contains Type Bug| C[Add Type:Bug Label]
    B -->|Contains Type Feature Request| D[Add Type:Feature Label]
    B -->|No Type Pattern| E{Has Any Type Label?}
    
    C --> F[Issue Labeled]
    D --> F
    
    E -->|No Type Label| G[Add Comment: Team Please Add Type Label]
    E -->|Has Type Label| F
    G --> H[Add needs-typeLabel]
    H --> F
    
    F --> I[Ongoing Issue Management]
    
    %% Type Label Management
    I --> J{Type Label Added?}
    J -->|Yes| K{Has needs-typeLabel?}
    K -->|Yes| L[Remove needs-typeLabel]
    K -->|No| M[Continue Monitoring]
    J -->|No| M
    L --> M
    
    %% Scheduled Tasks
    M --> N[Hourly Scheduled Tasks]
    
    N --> O{Check Issue Status}
    
    %% Stale Issue Management
    O --> P{needs-info + 7 days inactive?}
    P -->|Yes + Has Stale Label| Q[Close Issue with Message]
    P -->|Yes + No Stale Label| R[Add Stale Warning + Label]
    P -->|No| S[Continue to Next Check]
    
    %% Long-term Cleanup
    S --> T{18 months inactive + Low Priority?}
    T -->|Yes| U[Close Old Low Priority Issue]
    T -->|No| V[Continue to Next Check]
    
    %% Type Label Enforcement
    V --> W{Missing Type Label?}
    W -->|Yes| X[Add needs-typeLabel + Comment]
    W -->|No| DD[End Cycle]
    
    Q --> DD
    R --> DD
    U --> DD
    X --> DD
    
    DD --> EE[Wait for Next Hour]
    EE --> N
    
    %% Styling
    style A fill:#e1f5fe
    style C fill:#ffebee
    style D fill:#f3e5f5
    style G fill:#fff3e0
    style Q fill:#ffcdd2
    style U fill:#ffcdd2
    style DD fill:#f0f0f0
```

## Configuration Summary

### Event Responders (Triggered on Issue Events):

1. **Auto-Type Detection**:
   - Detects "Type: Bug" in issue body → adds `Type:Bug` label
   - Detects "Type: Feature Request" in issue body → adds `Type:Feature` label

2. **Type Label Enforcement**:
   - Issues without type labels → adds comment requesting team to add type + `needs-typeLabel`
   - When type label is added → removes `needs-typeLabel`

### Scheduled Tasks (Run Hourly):

1. **Stale Issue Management**:
   - Issues with `needs-info` + 7 days inactive + `Stale` → **Close**
   - Issues with `needs-info` + 7 days inactive (no `Stale`) → **Warn + Add Stale label**

2. **Long-term Cleanup**:
   - Non-feature, low-priority issues inactive for 18+ months → **Auto-close**

3. **Type Label Maintenance**:
   - Issues missing type labels → **Add `needs-typeLabel` + comment**

### Safety Features:
- `DoNotClose` label prevents auto-closure
- Only affects issues without existing type labels
- Preserves high-priority issues (`Priority:0`, `Priority:1`)
- Maintains feature requests regardless of age
