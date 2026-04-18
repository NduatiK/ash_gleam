mix hex.publish && 
    git tag -a "$TAG" -m "$TAG" &&
    git push origin "$TAG"