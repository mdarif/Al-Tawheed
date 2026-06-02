# Git Workflow Guide

## Pre-commit Hooks (Optional but Recommended)

Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Pre-commit hook for Flutter project

echo "Running pre-commit checks..."

# Run linter
echo "Running flutter analyze..."
flutter analyze
if [ $? -ne 0 ]; then
  echo "✗ Linter found issues. Fix them before committing."
  exit 1
fi

# Format code
echo "Formatting code..."
flutter format .

# Run tests
echo "Running tests..."
flutter test
if [ $? -ne 0 ]; then
  echo "✗ Tests failed. Fix them before committing."
  exit 1
fi

echo "✓ All checks passed!"
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Git Configuration

### Setup Your Name and Email
```bash
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Or globally
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Configure Git Aliases
```bash
# Add these to ~/.gitconfig or run these commands
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'
git config --global alias.visual 'log --graph --oneline --all'
```

## Branching Strategy

### Branch Naming Convention
```
feature/feature-name           # New features
bugfix/bug-name               # Bug fixes
hotfix/critical-issue         # Critical production fixes
docs/documentation-update     # Documentation changes
refactor/refactoring-name     # Code refactoring
```

### Feature Development Workflow
```bash
# 1. Create feature branch from main/master
git checkout -b feature/new-feature

# 2. Make changes and commits
git add .
git commit -m "feat: add new feature"

# 3. Push branch
git push origin feature/new-feature

# 4. Create pull request on GitHub

# 5. After merge, clean up
git checkout main
git pull origin main
git branch -d feature/new-feature
git push origin --delete feature/new-feature
```

## Commit Message Format

### Conventional Commits
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that don't affect code meaning (formatting, whitespace)
- **refactor**: Code change that neither fixes bugs nor adds features
- **perf**: Code change that improves performance
- **test**: Adding or updating tests
- **chore**: Changes to build process or dependencies

### Examples
```bash
git commit -m "feat: add video download functionality"
git commit -m "fix: resolve crash on app startup"
git commit -m "docs: update setup guide"
git commit -m "refactor: simplify API service"
git commit -m "perf: optimize video loading"
```

## .gitignore

Ensure these are in your `.gitignore`:

```
# Flutter
.packages
pubspec.lock
.dart_tool/
build/

# iOS
ios/Pods/
ios/Podfile.lock
ios/.symlinks/
ios/Flutter/GeneratedPluginRegistrant.m

# Android
android/.gradle
android/local.properties
android/app/release/
android/.idea

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Environment
.env
.env.local

# Testing
.coverage
coverage/

# Generated
*.iml
*.class

# Build artifacts
*.apk
*.aar
*.aab
```

## Common Git Commands

```bash
# Status
git status
git diff

# Staging
git add .
git add path/to/file
git reset path/to/file

# Commits
git commit -m "message"
git commit --amend
git log --oneline -10

# Branches
git branch                    # List branches
git branch -a                 # List all branches
git branch feature/name       # Create branch
git checkout feature/name     # Switch branch
git checkout -b feature/name  # Create and switch

# Remote
git push origin branch-name
git pull origin main
git fetch

# Undo
git reset --soft HEAD~1      # Undo last commit (keep changes)
git reset --hard HEAD~1      # Undo last commit (discard changes)
git revert HEAD               # Create new commit that undoes last one

# Stash
git stash                    # Temporarily save changes
git stash list               # List stashed changes
git stash pop                # Apply latest stash
```

## Pull Request Checklist

Before creating a PR:
- [ ] Branch name follows convention
- [ ] All changes are committed
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes all tests
- [ ] Code is formatted: `flutter format .`
- [ ] No merge conflicts
- [ ] Meaningful commit messages
- [ ] Updated documentation if needed

## Code Review Tips

When reviewing code:
1. Check for code quality and style consistency
2. Verify tests are included and passing
3. Ensure documentation is updated
4. Look for performance issues
5. Check for security concerns
6. Verify error handling
7. Test the feature locally if possible

## CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/test.yml`:
```yaml
name: Flutter Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

## Collaboration Best Practices

1. **Keep branches short-lived** - Merge within 1-2 days
2. **Write clear PR descriptions** - Help reviewers understand changes
3. **Review others' code** - Share knowledge and catch issues
4. **Communicate early** - Discuss large changes before coding
5. **Use issues for tracking** - Create issues for bugs and features
6. **Document decisions** - Add comments explaining "why" not just "what"

## Release Process

### Semantic Versioning
Format: `MAJOR.MINOR.PATCH` (e.g., 1.2.3)

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

### Release Checklist
```bash
# 1. Update version in pubspec.yaml
# 2. Update CHANGELOG.md
# 3. Run full test suite
flutter test --coverage

# 4. Create release commit
git commit -m "chore: release v1.2.0"

# 5. Create release tag
git tag v1.2.0

# 6. Push release
git push origin master
git push origin v1.2.0

# 7. Build for release
make release-android
make release-ios

# 8. Submit to stores
```

## Troubleshooting Git Issues

### Undo Published Commit
```bash
git revert <commit-hash>
```

### Recover Deleted Branch
```bash
git reflog
git checkout <branch-name>
```

### Merge Conflicts
```bash
# During merge, resolve conflicts manually
# Mark as resolved
git add .
git commit -m "fix: resolve merge conflicts"
```

### Force Update (Use Carefully!)
```bash
git push --force-with-lease origin branch-name
```

---

**Remember**: Always communicate with your team before using force push or rewriting history!
