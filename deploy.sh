CURRENT_BRANCH="$(git branch --show-current)"
SHORT_COMMIT="$(git rev-parse --short HEAD)"
TAG=$1

if ! command -v gh &> /dev/null; then
  echo "Github CLI is not installed!"
  echo "Please install: https://github.com/cli/cli";
  exit 1;
fi

gh auth status >/dev/null 2>&1 || gh auth login

if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo '[ERROR] You are not on main branch, aborting';
  exit 1;
fi

git fetch origin --tags --quiet

# check if origin/main is ahead of local main
git merge-base --is-ancestor origin/main HEAD || {
  echo '[WARN] Local main is behind origin/main. These are the commits:';
  echo
  git rev-list HEAD~1...origin/main --pretty=format:'  %Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%an, %cr)%Creset' --no-commit-header
  echo
  read -r -p "Do you want to continue? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      exit 1
      ;;
  esac
}

echo ""
echo "Creating tag: $TAG"
echo ""
git tag $TAG
git push origin $TAG

echo ""
echo "Generating release ..."
gh release create $TAG --generate-notes --verify-tag
