# Publishing this cleanup to GitHub

This folder is ready to be **reviewed for a Git commit**. It has not been pushed automatically.

## Safe workflow using GitHub Desktop (recommended)

1. Connect/sign in to your GitHub account in **GitHub Desktop**.
2. Open or clone the **existing Velora repository** (do not create a second repository unless that is your intention).
3. Create a branch such as `cleanup/app-store-prep` to preserve the current main branch.
4. Copy the contents of the cleaned **`Velora/` repository root** into your local cloned repository. Review the changed-file list; do not overwrite unrelated files in an established repository without checking them.
5. In GitHub Desktop, review the diff. There should be no unexpected changes to any application `.swift` file, assets or Xcode project configuration solely from cleanup.
6. Commit with a clear message such as `docs: prepare Velora for App Store release and consolidate project history`.
7. Choose **Push origin**. Review and merge the branch when ready.

## Command-line alternative

After cloning the correct repository and placing these files in it:

```bash
git status
git add -A
git diff --cached --stat
git commit -m "docs: clean project structure and document release"
git push -u origin cleanup/app-store-prep
```

Create/switch to the named branch **before** these commands. Never run `git init` in an existing clone or force-push without reviewing the remote history.

## Public repository check

- Verify you own the rights to included audio samples, screenshots, text and logos.
- Review any personal identifiers in project signing settings or code comments.
- Review the project's license choice separately. **No license was invented or added** during cleanup.
- `.gitignore` filters DerivedData, user-specific Xcode state, build artifacts and local machine files; it does not erase files already committed historically.
