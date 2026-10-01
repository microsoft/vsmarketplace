<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'

import publishedExtensions from '../../../quickstart/vscode/images/published-extensions.png'
import groupPolicy from '../../../quickstart/vscode/images/gpedit-setting.png'
import visualStudioSettings from '../../../quickstart/vs/images/vs-options-extensions.png'

const root = ref<HTMLElement | null>(null)
let observer: IntersectionObserver | null = null

onMounted(() => {
  if (!root.value) return

  const stories = Array.from(root.value.querySelectorAll<HTMLElement>('.mp-story'))
  root.value.classList.add('mp-walkthrough-ready')

  if (
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
    || typeof IntersectionObserver === 'undefined'
  ) {
    stories.forEach((story) => story.classList.add('in-view'))
    return
  }

  observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add('in-view')
          observer?.unobserve(entry.target)
        }
      }
    },
    { threshold: 0.18, rootMargin: '0px 0px -8% 0px' },
  )

  stories.forEach((story) => observer?.observe(story))
})

onBeforeUnmount(() => {
  observer?.disconnect()
  observer = null
})
</script>

<template>
  <section ref="root" class="mp-walkthrough" aria-label="Private Marketplace value propositions">
    <article class="mp-story">
      <div class="mp-story-copy">
        <span class="mp-story-number">01</span>
        <span class="mp-story-kicker">Proxy public extensions</span>
        <h2>Bring public extension traffic through your marketplace.</h2>
        <p>
          Choose whether to proxy search alone or route search and extension downloads through
          Private Marketplace.
        </p>
      </div>

      <div class="mp-story-visual">
        <div class="mp-traffic-map" role="img" aria-label="Public Marketplace traffic passes through Private Marketplace to developer clients">
          <div class="mp-traffic-node">
            <span class="mp-traffic-label">Public extensions</span>
            <strong>Visual Studio Marketplace</strong>
          </div>
          <span class="mp-traffic-line" aria-hidden="true"></span>
          <div class="mp-traffic-node mp-traffic-node--hub">
            <span class="mp-traffic-label">Proxy and govern</span>
            <strong>Private Marketplace</strong>
            <span class="mp-traffic-note">Search or search + assets</span>
          </div>
          <span class="mp-traffic-line" aria-hidden="true"></span>
          <div class="mp-traffic-node">
            <span class="mp-traffic-label">Developer clients</span>
            <strong>VS Code<br>Visual Studio</strong>
          </div>
        </div>
      </div>
    </article>

    <article class="mp-story mp-story--reverse">
      <div class="mp-story-copy">
        <span class="mp-story-number">02</span>
        <span class="mp-story-kicker">Host private extensions</span>
        <h2>Keep internal extensions on infrastructure you control.</h2>
        <p>
          Host and distribute private VSIX extensions from on-premises or private cloud
          infrastructure using storage that fits your organization. Authentication support is
          coming soon.
        </p>
      </div>

      <div class="mp-story-visual">
        <figure class="mp-screen">
          <img
            :src="publishedExtensions"
            alt="Table of extensions published to Private Marketplace"
            loading="lazy"
          >
          <figcaption>Published extensions appear in the marketplace.</figcaption>
        </figure>
      </div>
    </article>

    <article class="mp-story">
      <div class="mp-story-copy">
        <span class="mp-story-number">03</span>
        <span class="mp-story-kicker">Allow-list what matters</span>
        <h2>Make only approved extensions available.</h2>
        <p>
          Filter marketplace results and downloads by publisher, extension, and version. Visual
          Studio also applies the published rules on the client.
        </p>
      </div>

      <div class="mp-story-visual">
        <div class="mp-policy-card">
          <div class="mp-policy-heading">
            <span class="mp-policy-dot"></span>
            <span>AllowedExtensions</span>
          </div>
          <pre><code>{
  "*": false,
  "microsoft": true,
  "ms-vscode.cpptools": false
}</code></pre>
          <p>Allow Microsoft extensions, except the C++ extension.</p>
        </div>
      </div>
    </article>

    <article class="mp-story mp-story--reverse">
      <div class="mp-story-copy">
        <span class="mp-story-number">04</span>
        <span class="mp-story-kicker">Configure clients centrally</span>
        <h2>Set marketplace behavior with policy.</h2>
        <p>
          Use Group Policy and supported client-management settings to configure marketplace access
          and extension behavior across your organization.
        </p>
      </div>

      <div class="mp-story-visual mp-client-screens">
        <figure class="mp-screen">
          <img
            :src="groupPolicy"
            alt="Windows Group Policy setting for the VS Code ExtensionGalleryServiceUrl"
            loading="lazy"
          >
          <figcaption>VS Code marketplace URL policy.</figcaption>
        </figure>
        <figure class="mp-screen">
          <img
            :src="visualStudioSettings"
            alt="Visual Studio Extensions options with Use private marketplace selected"
            loading="lazy"
          >
          <figcaption>Visual Studio marketplace settings.</figcaption>
        </figure>
      </div>
    </article>

    <div class="mp-walkthrough-cta">
      <a class="mp-cta-button mp-cta-button--brand" href="/quickstart/">
        Start with a quickstart
      </a>
      <a class="mp-cta-button mp-cta-button--alt" href="/guide/">
        Explore the guide
      </a>
    </div>
  </section>
</template>

<style scoped>
.mp-walkthrough {
  --mp-accent: var(--vp-c-brand-1);
  max-width: 1152px;
  margin: 0 auto;
  padding: 12px 24px 56px;
}

.mp-story {
  display: grid;
  grid-template-areas: "copy visual";
  grid-template-columns: minmax(0, 0.9fr) minmax(0, 1.1fr);
  gap: 52px;
  align-items: center;
  padding: 44px 0;
  border-bottom: 1px solid var(--vp-c-divider);
  transition:
    opacity 650ms cubic-bezier(0.16, 1, 0.3, 1),
    transform 650ms cubic-bezier(0.16, 1, 0.3, 1);
}

.mp-story:last-child {
  border-bottom: 0;
}

.mp-story--reverse {
  grid-template-areas: "visual copy";
  grid-template-columns: minmax(0, 1.1fr) minmax(0, 0.9fr);
}

.mp-story-copy {
  grid-area: copy;
}

.mp-story-visual {
  grid-area: visual;
  min-width: 0;
}

.mp-story-number {
  display: block;
  color: var(--vp-c-text-3);
  font-family: var(--vp-font-family-mono);
  font-size: 0.8rem;
  letter-spacing: 0.1em;
}

.mp-story-kicker {
  display: block;
  margin-top: 10px;
  color: var(--mp-accent);
  font-family: var(--vp-font-family-mono);
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.mp-story-copy h2 {
  margin: 12px 0;
  border: 0;
  color: var(--vp-c-text-1);
  font-size: clamp(1.35rem, 2.5vw, 1.8rem);
  line-height: 1.25;
}

.mp-story-copy p {
  margin: 0;
  color: var(--vp-c-text-2);
  font-size: 1rem;
  line-height: 1.65;
}

.mp-walkthrough-ready .mp-story:not(.in-view) {
  opacity: 0;
  transform: translateY(24px);
}

.mp-story.in-view {
  opacity: 1;
  transform: none;
}

.mp-story:nth-child(2) {
  transition-delay: 80ms;
}

.mp-story:nth-child(3) {
  transition-delay: 160ms;
}

.mp-story:nth-child(4) {
  transition-delay: 240ms;
}

.mp-walkthrough-cta {
  display: flex;
  justify-content: center;
  flex-wrap: wrap;
  gap: 14px;
  padding: 28px 0 20px;
}

.mp-cta-button {
  display: inline-block;
  border: 1px solid transparent;
  border-radius: 22px;
  padding: 0 22px;
  font-size: 0.9rem;
  font-weight: 600;
  line-height: 42px;
  text-align: center;
  text-decoration: none;
  transition: background-color 180ms ease, border-color 180ms ease;
}

.mp-cta-button--brand {
  border-color: var(--vp-button-brand-border);
  color: var(--vp-button-brand-text);
  background: var(--vp-button-brand-bg);
}

.mp-cta-button--brand:hover {
  border-color: var(--vp-button-brand-hover-border);
  color: var(--vp-button-brand-hover-text);
  background: var(--vp-button-brand-hover-bg);
}

.mp-cta-button--alt {
  border-color: var(--vp-button-alt-border);
  color: var(--vp-button-alt-text);
  background: var(--vp-button-alt-bg);
}

.mp-cta-button--alt:hover {
  border-color: var(--vp-button-alt-hover-border);
  color: var(--vp-button-alt-hover-text);
  background: var(--vp-button-alt-hover-bg);
}

.mp-traffic-map {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 34px minmax(0, 1.1fr) 34px minmax(0, 1fr);
  align-items: center;
}

.mp-traffic-node {
  display: flex;
  min-height: 136px;
  flex-direction: column;
  justify-content: center;
  gap: 9px;
  padding: 16px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  background: var(--vp-c-bg-soft);
  color: var(--vp-c-text-2);
  text-align: center;
}

.mp-traffic-node strong {
  color: var(--vp-c-text-1);
  font-size: 0.95rem;
}

.mp-traffic-label {
  color: var(--mp-accent);
  font-family: var(--vp-font-family-mono);
  font-size: 0.65rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.mp-traffic-note {
  font-size: 0.75rem;
}

.mp-traffic-node--hub {
  border-color: color-mix(in srgb, var(--mp-accent) 48%, var(--vp-c-divider));
  background: color-mix(in srgb, var(--mp-accent) 8%, var(--vp-c-bg-soft));
  box-shadow: 0 10px 28px color-mix(in srgb, var(--mp-accent) 12%, transparent);
}

.mp-traffic-line {
  height: 2px;
  background-image: repeating-linear-gradient(90deg, var(--mp-accent) 0 5px, transparent 5px 13px);
  background-size: 13px 2px;
  animation: mp-traffic-dash 900ms linear infinite;
}

.mp-screen {
  overflow: hidden;
  margin: 0;
  border: 1px solid var(--vp-c-divider);
  border-radius: 10px;
  background: var(--vp-c-bg-soft);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.1);
}

.mp-screen img {
  display: block;
  width: 100%;
  height: auto;
}

.mp-screen figcaption {
  padding: 9px 12px;
  color: var(--vp-c-text-2);
  font-size: 0.78rem;
}

.mp-client-screens {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.mp-policy-card {
  overflow: hidden;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  background: var(--vp-c-bg-soft);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.1);
}

.mp-policy-heading {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--vp-c-divider);
  color: var(--vp-c-text-2);
  font-family: var(--vp-font-family-mono);
  font-size: 0.8rem;
}

.mp-policy-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--mp-accent);
}

.mp-policy-card pre {
  margin: 0;
  padding: 22px;
  overflow-x: auto;
  background: var(--vp-c-bg-soft);
  color: var(--vp-c-text-1);
  font-size: 0.9rem;
  line-height: 1.65;
}

.mp-policy-card p {
  margin: 0;
  padding: 0 22px 18px;
  color: var(--vp-c-text-2);
  font-size: 0.8rem;
}

@keyframes mp-traffic-dash {
  to {
    background-position: 13px 0;
  }
}

@media (max-width: 900px) {
  .mp-story,
  .mp-story--reverse {
    grid-template-areas:
      "copy"
      "visual";
    grid-template-columns: minmax(0, 1fr);
    gap: 24px;
    padding: 36px 0;
  }
}

@media (max-width: 640px) {
  .mp-walkthrough {
    padding: 8px 16px 36px;
  }

  .mp-traffic-map {
    grid-template-columns: 1fr;
    gap: 0;
  }

  .mp-traffic-node {
    min-height: 100px;
  }

  .mp-traffic-line {
    width: 2px;
    height: 24px;
    justify-self: center;
    background-image: repeating-linear-gradient(180deg, var(--mp-accent) 0 5px, transparent 5px 13px);
    background-size: 2px 13px;
  }

  .mp-client-screens {
    grid-template-columns: 1fr;
  }

}

@media (prefers-reduced-motion: reduce) {
  .mp-story {
    transition: none;
  }

  .mp-cta-button {
    transition: none;
  }

  .mp-traffic-line {
    animation: none;
  }
}
</style>
