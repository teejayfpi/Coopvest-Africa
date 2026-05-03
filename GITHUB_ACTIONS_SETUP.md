# GitHub Actions Setup Guide

This guide explains how to configure GitHub Actions to build the Coopvest Africa APK.

## Workflow File

The workflow is at `.github/workflows/build-apk.yml`. It:
- Triggers on push to `main`, `master`, `devin/**` branches
- Triggers on pull requests to `main`/`master`
- Can be triggered manually from the GitHub Actions tab (choose `debug` or `release`)
- Automatically creates a GitHub Release when you push a tag like `v1.0.0`

## Required GitHub Secrets

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these 4 secrets:

| Secret name | Value |
|-------------|-------|
| `KEYSTORE_BASE64` | Base64-encoded release keystore (see below) |
| `KEY_STORE_PASSWORD` | Your keystore store password |
| `KEY_ALIAS` | Your key alias |
| `KEY_PASSWORD` | Your key password |

### Getting the KEYSTORE_BASE64 value

Run this command on your local machine (or use the value already generated):

```bash
base64 -i android/keystore/release-keystore.jks | pbcopy   # macOS
base64 android/keystore/release-keystore.jks | xclip        # Linux
```

Then paste the result as the `KEYSTORE_BASE64` secret value.

## How to Trigger a Build Manually

1. Go to your GitHub repo
2. Click **Actions** tab
3. Select **Build Flutter APK** workflow
4. Click **Run workflow**
5. Choose `release` or `debug`
6. Click **Run workflow** button

## Downloading the APK

After the workflow completes:
1. Click on the completed workflow run
2. Scroll down to **Artifacts**
3. Download the `.apk` file

## Creating a Release with APK

Push a version tag to automatically create a GitHub Release with the APK attached:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Security Notes

⚠️ The following files contain sensitive data and should be added to `.gitignore`:
- `android/key.properties` — contains keystore passwords
- `android/keystore/release-keystore.jks` — the signing keystore
- `backend/.env` — contains API keys and secrets

These are currently committed to the repository. Consider rotating your credentials.
