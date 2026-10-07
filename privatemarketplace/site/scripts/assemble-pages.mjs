import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { marked } from 'marked'

const siteDirectory = fileURLToPath(new URL('../', import.meta.url))
const repositoryRoot = fileURLToPath(new URL('../../../', import.meta.url))
const distDirectory = path.join(siteDirectory, '.vitepress', 'dist')
const pagesDirectory = path.join(siteDirectory, '.vitepress', 'pages')

await rm(pagesDirectory, { recursive: true, force: true })
await mkdir(pagesDirectory, { recursive: true })
await cp(distDirectory, path.join(pagesDirectory, 'privatemarketplace'), { recursive: true })

const readme = await readFile(path.join(repositoryRoot, 'README.md'), 'utf8')
const content = await marked.parse(readme)
const stylesheet = await readFile(path.join(siteDirectory, 'scripts', 'repository-landing.css'), 'utf8')
const page = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Visual Studio Marketplace feedback and Private Marketplace documentation.">
    <title>vsmarketplace | Feedback and documentation</title>
    <style>${stylesheet}</style>
  </head>
  <body>
    <header class="site-header">
      <a class="brand" href="./">vsmarketplace</a>
      <nav aria-label="Main navigation">
        <a href="./privatemarketplace/">Private Marketplace</a>
        <a href="https://github.com/microsoft/vsmarketplace">GitHub repository</a>
      </nav>
    </header>
    <main>
      <article class="readme-content">${content}</article>
    </main>
  </body>
</html>
`

await writeFile(path.join(pagesDirectory, 'index.html'), page)
