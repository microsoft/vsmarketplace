# Unpublish specific VS Code package version

## Overview

Publishers need a way to take back a certain version of their VS Code extension that has problems due to release pipeline issues or needs to be recalled because of serious security or legal issues. Right now on VS Marketplace (VSM) developers can only remove their whole extension, which makes it inaccessible to the public, and this can cause problems and confusion for both the developers and the users. The most upvoted [request on GitHub](https://github.com/microsoft/vsmarketplace/issues/235) from customers today is the ability to remove a certain version. This feature would let developers take out faulty versions of their extension from the VSM, while leaving the previous and next versions available. This way, developers can fix the problem and publish a new version, without affecting the users who are using the working versions of the extension. Users would benefit from this feature, as they would not see the broken version of the extension in the VSM, and they would be able to update to the newest version without any trouble.

## Top problem scenarios

- **Unable to rollback mistakes**: Published a package accidentally or to learn/test publishing. Examples are accidentally uploading a wrong build, a package not intended to be public, or a package with a wrong version number. Usually, the need is to unpublish the latest version. Currently, the workaround is to roll back by republishing an old version and forcing everyone to update to that new version even though it has no new features/fixes.
- **Partial releases**: Publishing failed during a multi-platform release, resulting in partial release/update which needs to be rolled back. A common scenario of failure reported by customers is that validation or signing randomly errors out and works on reupload.
- **Recalls**: A critical security or copyright issue has been discovered in a published version, so it needs to be removed immediately to prevent further harm further down the supply chain.
- **Renaming**: Need to rename an extension (The only way to DIY rename a package is to publish it under a new name)


## Feature change overview

The proposed solution is to enable publishers to unpublish any specific version of a VS Code package, using either the vsce command line tool or the Marketplace web UI. The unpublish action would have the following effects and limitations:

- Once a specific version is unpublished, it cannot be downloaded or installed from the Marketplace, but all other published versions remain available.
- When there are unpublished versions of a package, the highest published version becomes the default for the purpose of installing in VS Code, one-click install, and download from the extension details page on the web.
- Unpublishing a version does not remove any data including acquistion numbers, ratings, reviews and Q&A that may have been posted while the version was published.
- The unpublish action cannot be undone*. The same extension name and version combination can never be reused to publish*.
- If all versions of a package have been individually unpublished, the extension becomes unavailable on the Marketplace (not found by search or not accessible via a direct link to the details page). However:
  - The publisher still retains ownership of the extension name so they can continue to publish newer versions.
  - The extension data including acquisition numbers, ratings, reviews and Q&A are also preserved to benefit any future versions. 
- To prevent large-scale disruption to extension consumers, versions with over 1K installs will only be removable by emailing Marketplace customer support.

\* Consistent with [npm-unpublish](https://docs.npmjs.com/cli/v8/commands/npm-unpublish) behavior, which is a consideration given the familiarity of npm registry among Marketplace publishers.

Note: After initial feedback intake, in the next step we'll update this spec with details of experential changes to vscevand web UI.
