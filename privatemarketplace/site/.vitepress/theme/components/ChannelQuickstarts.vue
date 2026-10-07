<script setup lang="ts">
import { useData, withBase } from 'vitepress'

const props = withDefaults(defineProps<{ channel?: 'stable' | 'preview' }>(), {
  channel: 'preview',
})
const { theme } = useData()
const sidebarPath = props.channel === 'preview' ? '/preview/' : '/quickstart/'
const quickstartPrefix = props.channel === 'preview' ? '/preview/quickstart/' : '/quickstart/'
const referencePath = props.channel === 'preview' ? '/preview/README.html' : '/latest/README.html'
const items = theme.value.sidebar[sidebarPath][0].items
const quickstarts = items.filter((item) => item.link.startsWith(quickstartPrefix))
const reference = items.find((item) => item.link === referencePath)
const channelName = props.channel === 'preview' ? 'preview' : 'stable'
</script>

<template>
  <div class="preview-index">
    <section v-if="quickstarts.length" aria-labelledby="channel-quickstarts">
      <h2 id="channel-quickstarts">Quickstarts</h2>
      <div class="preview-cards">
        <a v-for="item in quickstarts" :key="item.link" class="preview-card" :href="withBase(item.link)">
          <h3>{{ item.text }}</h3>
          <span>Open quickstart <span aria-hidden="true">→</span></span>
        </a>
      </div>
    </section>

    <section v-if="reference" aria-labelledby="channel-reference">
      <h2 id="channel-reference">Full reference</h2>
      <a class="preview-card preview-card--reference" :href="withBase(reference.link)">
        <h3>{{ reference.text }}</h3>
        <span>Browse the complete {{ channelName }} documentation <span aria-hidden="true">→</span></span>
      </a>
    </section>
  </div>
</template>

<style scoped>
.preview-index {
  display: grid;
  gap: 36px;
  margin: 32px 0;
}

.preview-index h2 {
  margin: 0 0 16px;
  border: 0;
  font-size: 1.35rem;
}

.preview-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr));
  gap: 16px;
}

.preview-card {
  display: flex;
  min-height: 120px;
  flex-direction: column;
  justify-content: space-between;
  gap: 20px;
  padding: 20px 22px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 10px;
  background: var(--vp-c-bg-soft);
  color: inherit;
  text-decoration: none;
  transition: border-color 160ms ease, transform 160ms ease;
}

.preview-card:hover {
  transform: translateY(-2px);
  border-color: var(--vp-c-brand-1);
}

.preview-card h3 {
  margin: 0;
  border: 0;
  font-size: 1.05rem;
}

.preview-card > span {
  color: var(--vp-c-brand-1);
  font-size: 0.9rem;
  font-weight: 600;
}

.preview-card--reference {
  min-height: auto;
}

@media (prefers-reduced-motion: reduce) {
  .preview-card {
    transition: none;
  }

  .preview-card:hover {
    transform: none;
  }
}
</style>
