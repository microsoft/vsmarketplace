import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import { h } from 'vue'

import MarketplaceHero from './components/MarketplaceHero.vue'
import MarketplaceWalkthrough from './components/MarketplaceWalkthrough.vue'
import PreviewAnnouncement from './components/PreviewAnnouncement.vue'
import ReleaseChannel from './components/ReleaseChannel.vue'
import PreviewIndex from './components/ChannelQuickstarts.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  Layout: () => h(DefaultTheme.Layout, null, {
    'home-hero-before': () => h(PreviewAnnouncement),
    'home-hero-image': () => h(MarketplaceHero),
    'doc-before': () => h(ReleaseChannel),
  }),
  enhanceApp({ app }) {
    app.component('MarketplaceWalkthrough', MarketplaceWalkthrough)
    app.component('PreviewIndex', PreviewIndex)
  },
} satisfies Theme
