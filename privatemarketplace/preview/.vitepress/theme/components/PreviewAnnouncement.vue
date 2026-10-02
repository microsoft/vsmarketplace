<script setup lang="ts">
import { withBase } from 'vitepress'
import AnnouncementIcon from './AnnouncementIcon.vue'
</script>

<template>
  <aside class="mp-announcement mp-announcement--preview mp-preview-announcement">
    <AnnouncementIcon />
    <span>Visual Studio IDE support is currently in Preview.</span>
    <a :href="withBase('/preview/')">Explore preview docs</a>
  </aside>
</template>

<style scoped>
.mp-preview-announcement {
  justify-content: center;
  max-width: 1152px;
  margin: 20px auto 0;
  color: var(--vp-c-text-2);
}

.mp-preview-announcement a {
  flex-shrink: 0;
}
</style>
