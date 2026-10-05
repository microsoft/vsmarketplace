<script setup lang="ts">
import { withBase } from 'vitepress'
import AnnouncementIcon from './AnnouncementIcon.vue'

const hasPreviewContent = import.meta.env.VITE_HAS_PREVIEW_CONTENT
</script>

<template>
  <aside v-if="hasPreviewContent" class="mp-announcement mp-announcement--preview mp-preview-announcement">
    <AnnouncementIcon />
    <span>Visual Studio IDE support is currently in Preview.</span>
    <a :href="withBase('/preview/')">Explore preview docs</a>
  </aside>
</template>

<style scoped>
.mp-preview-announcement {
  position: relative;
  z-index: 1;
  justify-content: center;
  max-width: 1152px;
  margin: 20px auto 0;
  color: var(--vp-c-text-2);
}

.mp-preview-announcement a {
  flex-shrink: 0;
}
</style>
