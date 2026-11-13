# Release Notes — Private Marketplace

**Release:** `1.1.323`

**Release date:** October 2026

**Container image:** `mcr.microsoft.com/vsmarketplace/vscode-private-marketplace`

## Release Summary

This release introduces opt-in cooldown controls for public extension updates and lets supported Azure App Configuration settings refresh without restarting the marketplace.

It reduces upstream requests through improved version-history caching, repairs existing private extension publication dates, fixes expired-token handling for Azure Artifacts, and includes dependency and container runtime security updates.

---

## New Features
- Administrators can delay offering newly updated public extensions by configuring an optional cooldown period, with exemptions for selected extensions.

## Improvements
- Repeated requests for permitted older extension versions reuse cached version history even when cooldown is disabled, reducing upstream requests.
- Supported settings in Azure App Configuration now update without restarting the marketplace, including extension policies, homepage content, logging, and request retry and timeout settings. Changes are picked up even when the marketplace is idle. Connection settings, storage locations, and source identities and credentials still require a restart.

## Bug Fixes
- Existing private extension publication dates are repaired automatically from retained version history, without rebuilding indexes or uploading extensions again.
- Azure Artifacts connections no longer reuse an expired access token when a token refresh fails.

## Security Updates
- Updated MessagePack dependencies to address **CVE-2026-92707**.
- Updated the .NET base container to runtime 10.0.14, including fixes for **CVE-2026-111497** and **CVE-2026-70197**.

## Upgrade Impact Summary

Upgrade to the latest release to receive these changes. Optional features remain opt-in.

### Azure Artifacts endpoint configuration

Before upgrading an Azure Artifacts deployment using managed identity, configure:

- `Marketplace__ArtifactsFeedsBaseUrl=https://feeds.dev.azure.com`
- `Marketplace__ArtifactsPackagesBaseUrl=https://pkgs.dev.azure.com`

Existing equivalent per-source settings also satisfy this requirement. Missing URLs prevent startup; changing only the image tag does not add them. Use environment-specific endpoints for sovereign/disconnected clouds. Connection-string sources retain their `EndPoint`; deployments without Azure Artifacts are unaffected.

## Previous Release Versions

<details>
<summary><strong>v1.1.261 — October 2026</strong></summary>

### New Features
- Administrators can use Azure App Configuration as an optional configuration source and choose separate Azure identities for configuration and Azure Artifacts access.
- An updated homepage provides extension browsing, connection guidance, service-health details, and accurate Visual Studio extension architecture information when enabled.

### Improvements
- Allow-list rules can now be configured under `Marketplace__AllowedExtensions__`. The root-level `AllowedExtensions` setting remains supported as a deprecated fallback.

### Bug Fixes
- Current Visual Studio clients can connect to the private marketplace without their requests being rejected.
- Visual Studio extension downloads work correctly when public extension assets are proxied through the private marketplace.
- The updated homepage's connection dialog has an accessible label.
- Publishing Visual Studio extensions to Azure Artifacts includes their assets correctly and reports publishing failures instead of appearing to succeed.

</details>

<details>
<summary><strong>v1.1.260 — September 2026</strong></summary>

### New Features
- Extension governance rules can allow selected extensions while denying individual versions with a `!`-prefixed version constraint.
- **Preview:** Private Marketplace can host, discover, and install Visual Studio extensions when Visual Studio extension support is enabled.

### Improvements
- Extensions blocked by organization policy are now identified correctly in Visual Studio, while blocked extensions retain their original display names in both Visual Studio and VS Code.
- Locally hosted Visual Studio extensions now use their declared language when applying locale filters.
- Extension queries remain responsive under concurrent demand by reducing duplicate upstream requests and improving metadata read performance.
- Public marketplace throttling is handled without retry amplification, allowing requests to recover according to the upstream retry window.
- Upstream extension queries and container startup are more reliable under concurrent load and normal cold-start conditions.
- Connections to external extension sources now use consistent timeouts, retries, and circuit breaking to recover more reliably from transient failures.

### Bug Fixes
- Azure Artifacts source refreshes finish correctly when there are no more package changes, allowing the marketplace to become ready to serve requests.
- Locally hosted Visual Studio extensions now appear correctly in the Visual Studio Extensions Manager Browse view.
- Category and tag filters are available again when searching for extensions.
- Failed public extension asset requests now preserve the upstream error instead of masking it with an unrelated formatting error.
- Removed extension versions remain deleted after a service restart.
- Visual Studio extension searches no longer fail when upstream metadata omits publisher information.
- Visual Studio extension lookup failures now preserve the upstream client error instead of returning an internal server error.
- Adding an extension version no longer changes the published and release dates of existing versions.
- Incomplete upstream search responses no longer cause marketplace queries to fail.
- Plain-text searches now find private extensions by publisher name.
- Service links now use the configured public base URL when the marketplace runs behind a reverse proxy that does not forward host information.
- Compressed responses from connected marketplaces are now decompressed correctly instead of causing extension queries to fail.

### Security Updates
- Updated the .NET SDK to address **CVE-2026-62900**.
- Updated gRPC dependencies to address **CVE-2026-48068** and **CVE-2026-48069**.
- Updated MessagePack dependencies to address **CVE-2026-48109**.
- Updated protobuf dependencies to address **CVE-2026-48712**.
- Updated OpenTelemetry dependencies to address **CVE-2026-54285**.
- Updated lodash dependencies to address **CVE-2026-4800**.
- Updated OpenTelemetry dependencies to address **CVE-2026-40182**, **CVE-2026-40891**, and **CVE-2026-40894**.
- Updated lodash dependencies to address **CVE-2025-13465**.

### Upgrade Impact Summary

Deploy a new immutable container tag to receive these changes. Existing VS Code deployments require no configuration changes. Visual Studio extension support is an opt-in preview enabled with `FeatureManagement__VSExtensionSupport=true`. No breaking changes are required for deployments that leave these preview features disabled.

#### Private extension publication dates

Loading an existing metadata snapshot repairs incorrect published and release dates using the earliest recorded timestamp among retained extension versions. The repair is persisted automatically; source indexes and extension packages do not need to be rebuilt or uploaded again. Extension and per-version last-updated timestamps are unchanged.

Earlier publication dates already recorded on the extension are preserved, even when the corresponding version has been deleted. Versions without a recorded timestamp cannot supply publication history. If the original version and its timestamp are no longer retained, the original publication date cannot always be recovered.


</details>

<details>
<summary><strong>v1.0.57 — November 2025</strong></summary>

- **Self-host extensions** — host internal and downloaded extensions on your own container infrastructure (e.g., Azure or Kubernetes).
- **Stateless container** — deploy a single container with no external database required.
- **Flexible storage** — publish and manage extensions using either a file-system directory or Azure Artifacts storage.
- **Upstreaming (optional)** — automatically include public extensions from the Visual Studio Marketplace.
- **Rehosting (optional)** — download and host public extensions for additional governance and air-gapped environments.
- **Centralized rollout** — roll out to your team via centralized group policy on Windows, macOS, and Linux.
- **Install and automatic updates** — search and install extensions directly from VS Code and receive automatic updates for new versions.

</details>
