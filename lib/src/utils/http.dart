extension UriHelper on Uri {
  Iterable<String> pathSegmentsFollowedBy(String path) {
    return pathSegments.followedBy(path.split('/'));
  }

  String get requestTarget {
    return hasQuery ? '$path?$query' : path;
  }
}
