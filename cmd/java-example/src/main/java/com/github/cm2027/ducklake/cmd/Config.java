package com.github.cm2027.ducklake.cmd;

import java.net.URISyntaxException;
import java.nio.file.Path;
import java.util.Optional;

public record Config(LakeType lake, Optional<String> localPath) {

  public static final String DEFAULT_LOCAL_PATH;
  static {
    Path appDir = null;

    try {
      appDir = Path.of(App.class.getProtectionDomain()
          .getCodeSource()
          .getLocation()
          .toURI()).resolve("../../").normalize();
    } catch (URISyntaxException e) {
      throw new RuntimeException("unable to get fs path for App class.", e);
    }

    DEFAULT_LOCAL_PATH = appDir.resolve("../../lakes/local/data/my_ducklake.ducklake").toString();
  }

  public enum LakeType {
    LOCAL,
    PG_S3,
  }

  public static Config parse(String... args) throws RuntimeException {
    var lake = LakeType.LOCAL;
    var localPath = Optional.of(DEFAULT_LOCAL_PATH);

    for (int i = 0; i < args.length; i++) {
      var arg = args[i];
      var kv = arg.split("=", 2);
      var key = kv[0];
      var value = kv.length > 1 ? kv[1] : (i + 1 < args.length ? args[++i] : null);
      if (value == null) {
        throw new IllegalArgumentException("Missing value for " + key);
      }

      switch (key) {
        case "--lake":
          if ("local".equalsIgnoreCase(value)) {
            lake = LakeType.LOCAL;
          } else if ("pg".equalsIgnoreCase(value)) {
            lake = LakeType.PG_S3;
          } else {
            throw new IllegalArgumentException("unknown lake type: " + value + ", expected one of \"pg\" or \"local\"");
          }
          break;
        case "--local-path":
          localPath = Optional.of(value);
          break;
        default:
          throw new IllegalArgumentException("unknown argument: " + key);
      }
    }

    return new Config(lake, localPath);
  }

}
