/// Result of building a Docker network name from a project directory name.
typedef DockerNetworkNameBuildResult = ({
  String networkName,
  bool wasSanitized,
  bool wasTruncated,
});

/// Sanitizes and validates Docker Compose network names for generated VPS files.
class DockerNetworkName {
  const DockerNetworkName._();

  /// Docker user-defined network names must start with a letter or digit and may
  /// only contain letters, digits, hyphens, underscores, and periods.
  static final RegExp _namePattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]*$');

  /// Docker Engine rejects names longer than 63 characters (`name must be 63
  /// characters or fewer`) because network names are used as DNS labels; see
  /// RFC 1035 section 2.3.4 and https://github.com/moby/moby/issues/36487
  static const int _maxLength = 63;
  static const String _suffix = '-network';
  static const String _fallbackPrefix = 'serverpod';

  /// Builds a Docker-compatible network name from a project directory name.
  static String fromProjectName(String projectName) {
    return buildFromProjectName(projectName).networkName;
  }

  /// Builds a Docker-compatible network name and reports whether it was adjusted.
  static DockerNetworkNameBuildResult buildFromProjectName(String projectName) {
    final sanitizedBaseName = _sanitizeBaseName(projectName);
    final wasSanitized = sanitizedBaseName != projectName;
    final networkNameBeforeTruncation = '$sanitizedBaseName$_suffix';
    final wasTruncated = networkNameBeforeTruncation.length > _maxLength;

    final networkName = wasTruncated
        ? _truncateNetworkName(sanitizedBaseName)
        : networkNameBeforeTruncation;

    return (
      networkName: networkName,
      wasSanitized: wasSanitized,
      wasTruncated: wasTruncated,
    );
  }

  /// Whether [networkName] is valid for Docker Compose `networks.<name>.name`.
  static bool isValid(String networkName) {
    if (networkName.isEmpty || networkName.length > _maxLength) {
      return false;
    }

    return _namePattern.hasMatch(networkName);
  }

  static String _truncateNetworkName(String sanitizedBaseName) {
    final maxBaseLength = _maxLength - _suffix.length;
    final truncatedBaseName = _trimSeparators(
      sanitizedBaseName.substring(0, maxBaseLength),
    );

    if (truncatedBaseName.isEmpty) {
      return '$_fallbackPrefix$_suffix';
    }

    return '$truncatedBaseName$_suffix';
  }

  static String _sanitizeBaseName(String projectName) {
    var sanitized = projectName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '-');
    sanitized = sanitized.replaceAll(RegExp(r'[-_.]{2,}'), '-');
    sanitized = _trimSeparators(sanitized);

    if (sanitized.isEmpty || !_startsWithAlphanumeric(sanitized)) {
      sanitized = _trimSeparators(
        '$_fallbackPrefix${sanitized.isEmpty ? '' : '-$sanitized'}',
      );
    }

    if (sanitized.isEmpty) {
      return _fallbackPrefix;
    }

    return sanitized;
  }

  static String _trimSeparators(String value) {
    return value.replaceAll(RegExp(r'^[-_.]+|[-_.]+$'), '');
  }

  static bool _startsWithAlphanumeric(String value) {
    return RegExp(r'^[a-zA-Z0-9]').hasMatch(value);
  }
}
