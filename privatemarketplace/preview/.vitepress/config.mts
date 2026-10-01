import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Private Marketplace',
  description: 'Set up a Private Marketplace and connect VS Code and Visual Studio clients.',

  themeConfig: {
    nav: [
      { text: 'Quickstart', link: '/quickstart/' },
      { text: 'Guide', link: '/guide/' },
      { text: 'Full reference', link: '/README' },
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Guide',
          items: [
            { text: 'Overview', link: '/guide/' },
            { text: 'Set up the marketplace', link: '/README#recommended-setup' },
            { text: 'Configure VS Code', link: '/README#51-connecting-vs-code-to-the-private-marketplace' },
            { text: 'Configure Visual Studio', link: '/README#52-connecting-visual-studio-2026-to-the-private-marketplace' },
          ],
        },
        {
          text: 'Quickstarts',
          items: [
            { text: 'Choose a quickstart', link: '/quickstart/' },
            { text: 'VS Code', link: '/quickstart/vscode/README' },
            { text: 'Visual Studio', link: '/quickstart/vs/README' },
          ],
        },
      ],
      '/quickstart/': [
        {
          text: 'Quickstarts',
          items: [
            { text: 'Choose a quickstart', link: '/quickstart/' },
            { text: 'VS Code', link: '/quickstart/vscode/README' },
            { text: 'Visual Studio', link: '/quickstart/vs/README' },
          ],
        },
      ],
      '/README': [
        {
          text: 'Marketplace setup',
          items: [
            { text: 'Recommended setup', link: '/README#recommended-setup' },
            { text: 'Deploy the container', link: '/README#2-deploy-the-container-to-your-desired-container-host' },
            { text: 'Configure the container', link: '/README#3-configure-the-container' },
            { text: 'Publish extensions', link: '/README#4-publish-extensions-to-the-container' },
            { text: 'Monitor the container', link: '/README#6-monitor-the-running-container' },
          ],
        },
        {
          text: 'Configure clients',
          items: [
            { text: 'VS Code', link: '/README#51-connecting-vs-code-to-the-private-marketplace' },
            { text: 'Visual Studio', link: '/README#52-connecting-visual-studio-2026-to-the-private-marketplace' },
          ],
        },
        {
          text: 'Quickstarts',
          items: [
            { text: 'VS Code', link: '/quickstart/vscode/README' },
            { text: 'Visual Studio', link: '/quickstart/vs/README' },
          ],
        },
      ],
    },

    search: {
      provider: 'local',
    },

    footer: {
      message: 'Released under the <a href="https://github.com/microsoft/vsmarketplace/blob/main/LICENSE">MIT License</a>.',
      copyright: 'Copyright © Microsoft Corporation',
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/microsoft/vsmarketplace/tree/main/privatemarketplace/preview' },
    ],
  },
})
