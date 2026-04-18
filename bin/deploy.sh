mix docs && 
    mix hex.publish package && 
    git tag -a "$TAG" -m "$TAG" &&
    git push origin "$TAG"