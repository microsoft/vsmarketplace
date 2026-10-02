<script setup lang="ts">
import { computed } from 'vue'
import { useData, withBase } from 'vitepress'
import AnnouncementIcon from './AnnouncementIcon.vue'

const { page } = useData()
const hasPreviewContent = import.meta.env.VITE_HAS_PREVIEW_CONTENT
const preview = computed(() => page.value.relativePath.startsWith('preview/'))
</script>

<template>
  <div v-if="hasPreviewContent" class="mp-announcement mp-release-channel" :class="{ 'mp-announcement--preview': preview }">
    <AnnouncementIcon v-if="preview" />
    <strong>{{ preview ? 'Preview' : 'Stable' }}</strong>
    <span v-if="preview">Features and instructions may change.</span>
    <a :href="withBase(preview ? '/latest/README.html' : '/preview/')">
      {{ preview ? 'Stable documentation' : 'Preview documentation' }}
    </a>
  </div>
</template>
