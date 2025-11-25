# Extensions Directory

Place your `.vsix` extension files in this directory.

## How to get .vsix files

### Option 1: Download from VS Code
1. Open VS Code
2. Go to Extensions view (`Ctrl+Shift+X`)
3. Find an extension
4. Click the gear icon ⚙️
5. Download the VSIX file

### Option 2: Download from Marketplace website
Visit https://marketplace.visualstudio.com/ and download extensions directly

### Option 3: Package your own extension
```bash
cd your-extension-directory
vsce package
```

## Directory structure

After adding extensions, this directory should look like:
```
extensions/
├── publisher.extension-name-1.0.0.vsix
├── another-publisher.another-extension-2.0.0.vsix
└── README.md (this file)
```

## Notes

- Extension files must have the `.vsix` extension
- The container reads this directory at startup
- To add new extensions after starting the container, restart it:
  ```bash
  docker-compose restart
  ```
- This directory is mounted as read-only in the container
