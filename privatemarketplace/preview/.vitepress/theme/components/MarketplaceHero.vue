<script setup lang="ts">
import marketplaceHome from '../../../quickstart/vscode/images/marketplace-home.png'
</script>

<template>
  <figure class="mp-hero-image">
    <img
      :src="marketplaceHome"
      alt="Private Marketplace home page with the Connect to Marketplace button and health information"
    >
  </figure>
</template>

<style scoped>
.mp-hero-image {
  overflow: hidden;
  margin: 0;
  border: 1px solid var(--vp-c-divider);
  border-radius: 14px;
  background: var(--vp-c-bg-soft);
  box-shadow: 0 24px 64px rgba(0, 0, 0, 0.14);
  transform: perspective(1200px) rotateY(-4deg);
}

.mp-hero-image img {
  display: block;
  width: 100%;
  height: auto;
}

@media (max-width: 960px) {
  .mp-hero-image {
    transform: none;
  }
}

@media (prefers-reduced-motion: reduce) {
  .mp-hero-image {
    transform: none;
  }
}
</style>
