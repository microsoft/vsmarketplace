import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'
import { slug } from 'github-slugger'

const require = createRequire(import.meta.url)
const previewRoot = new URL('../../preview/', import.meta.url)

function quickstarts(directory: string, route: string, optional = false) {
  const root = new URL(directory, import.meta.url)
  if (!existsSync(root)) {
    if (optional) return []
    throw new Error(`Quickstart directory not found: ${fileURLToPath(root)}`)
  }

  return readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .flatMap((entry) => {
      const readme = new URL(`${entry.name}/README.md`, root)
      const files = readdirSync(new URL(`${entry.name}/`, root))
      if (!files.includes('README.md')) return []
      const title = readFileSync(readme, 'utf8').match(/^#\s+(.+)$/m)?.[1]
      if (!title) throw new Error(`Missing quickstart heading: ${fileURLToPath(readme)}`)
      return [{ text: title, link: `${route}/${entry.name}/README.html` }]
    })
}

const stable = [
  ...quickstarts('../../quickstart/', '/quickstart'),
  { text: 'Full reference', link: '/latest/README.html' },
]
const previewQuickstarts = quickstarts('../../preview/quickstart/', '/preview/quickstart', true)
const preview = [
  ...(existsSync(new URL('overview.md', previewRoot)) ? [{ text: 'Overview', link: '/preview/' }] : []),
  ...previewQuickstarts,
  ...(existsSync(new URL('README.md', previewRoot)) ? [{ text: 'Full reference', link: '/preview/README.html' }] : []),
]
const hasPreviewContent = preview.length > 0

export default withMermaid(defineConfig({
  srcDir: '..',
  srcExclude: ['preview/node_modules/**', 'site/node_modules/**', 'site/.vitepress/**', '**/data/**'],
  rewrites: existsSync(new URL('overview.md', previewRoot))
    ? { 'preview/overview.md': 'preview/index.md' }
    : {},
  base: '/vsmarketplace/privatemarketplace/',
  title: 'Private Marketplace',
  description: 'Host, distribute, and govern extensions with Private Marketplace.',
  vite: {
    define: {
      'import.meta.env.VITE_HAS_PREVIEW_CONTENT': JSON.stringify(hasPreviewContent),
    },
    resolve: {
      alias: [
        { find: 'vue/server-renderer', replacement: require.resolve('vue/server-renderer') },
        { find: /^vue$/, replacement: require.resolve('vue/dist/vue.runtime.esm-bundler.js') },
      ],
    },
  },
  markdown: {
    anchor: { slugify: slug },
  },
  transformPageData(page) {
    if (page.relativePath.startsWith('preview/')) {
      if (!page.title) page.title = 'Preview'
      else if (page.title !== 'Preview') page.title = `Preview: ${page.title}`
    }
  },
  themeConfig: {
    nav: [
      ...(hasPreviewContent
        ? [{ text: '<span class="mp-preview-nav-pill">Preview</span>', link: preview[0].link, activeMatch: '^/preview/' }]
        : []),
      { text: 'Quickstart', link: '/quickstart/', activeMatch: '^/quickstart/' },
      { text: 'Full reference', link: '/latest/README.html' },
    ],
    sidebar: {
      '/latest/': [{ text: 'Stable', items: stable }],
      '/quickstart/': [{ text: 'Stable', items: stable }],
      ...(hasPreviewContent ? { '/preview/': [{ text: 'Preview', items: preview }] } : {}),
    },
    outline: { level: [1, 3], label: 'On this page' },
    search: {
      provider: 'local',
      options: {
        _render(src, env, md) {
          const channel = env.relativePath.startsWith('preview/') ? 'Preview' : 'Stable'
          return md.render(src, env).replace(/(<h[1-6]\b[^>]*>)/g, `$1${channel}: `)
        },
      },
    },
    footer: {
      message: 'Released under the <a href="https://github.com/microsoft/vsmarketplace/blob/main/LICENSE">MIT License</a>.',
      copyright: 'Copyright © Microsoft Corporation',
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/microsoft/vsmarketplace/tree/main/privatemarketplace' },
    ],
  },
}))
