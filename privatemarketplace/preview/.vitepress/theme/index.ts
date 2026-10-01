import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import { h } from 'vue'

import MarketplaceHero from './components/MarketplaceHero.vue'
import MarketplaceWalkthrough from './components/MarketplaceWalkthrough.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  Layout: () => h(DefaultTheme.Layout, null, {
    'home-hero-image': () => h(MarketplaceHero),
  }),
  enhanceApp({ app }) {
    app.component('MarketplaceWalkthrough', MarketplaceWalkthrough)
  },
} satisfies Theme
