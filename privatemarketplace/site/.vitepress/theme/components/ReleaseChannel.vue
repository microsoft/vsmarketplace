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
    <span v-if="preview">You're viewing the <strong>Preview docs</strong>. Features and instructions may change.</span>
    <span v-else>You're viewing the <strong>Stable docs</strong>. Looking for preview features?</span>
    <a :href="withBase(preview ? '/latest/README.html' : '/preview/')">
      {{ preview ? 'View Stable documentation →' : 'View Preview documentation →' }}
    </a>
  </div>
</template>
