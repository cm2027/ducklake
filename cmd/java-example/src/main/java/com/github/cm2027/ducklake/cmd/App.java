package com.github.cm2027.ducklake.cmd;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

public class App {

  // Dev defaults for the postgres+S3 lake. They match compose.yaml, seed.sql and
  // the garage-init scripts, so --lake pg works out of the box. If you changed
  // the credentials, edit them here.
  static final String PG_HOST = "127.0.0.1";
  static final String PG_PORT = "5432";
  static final String PG_DB = "ducklake_catalog";
  static final String PG_USER = "ducklake";
  static final String PG_PASSWORD = "ducklake";
  static final String S3_ENDPOINT = "127.0.0.1:3900";
  static final String S3_REGION = "garage";
  static final String S3_KEY = "GK0123456789abcdef01234567";
  static final String S3_SECRET = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
  static final String DATA_PATH = "s3://ducklake-data/data/";

  /** Which lake to use + where the local lake lives. */
  record Config(String lake, String localPath) {
  }

  /** Parse --key value / --key=value args (unknown args fail fast). */
  static Config parseArgs(String[] args) {
    String lake = "local";
    String localPath = "lakes/local/data/my_ducklake.ducklake";
    for (int i = 0; i < args.length; i++) {
      String[] kv = args[i].split("=", 2);
      String key = kv[0];
      String value = kv.length > 1 ? kv[1] : (i + 1 < args.length ? args[++i] : null);
      if (value == null) {
        throw new IllegalArgumentException("Missing value for " + key);
      }
      switch (key) {
        case "--lake":
          lake = value;
          break;
        case "--local-path":
          localPath = value;
          break;
        default:
          throw new IllegalArgumentException("Unknown argument: " + key);
      }
    }
    if (!lake.equals("local") && !lake.equals("pg")) {
      throw new IllegalArgumentException("--lake must be 'local' or 'pg'");
    }
    return new Config(lake, localPath);
  }

  static String q(String s) {
    return "'" + s.replace("'", "''") + "'";
  }

  static void printRows(Statement st, String sql) throws Exception {
    try (ResultSet rs = st.executeQuery(sql)) {
      ResultSetMetaData md = rs.getMetaData();
      int n = md.getColumnCount();
      while (rs.next()) {
        StringBuilder row = new StringBuilder(" (");
        for (int i = 1; i <= n; i++) {
          if (i > 1) {
            row.append(", ");
          }
          String v = rs.getString(i);
          row.append(rs.wasNull() ? "NULL" : v);
        }
        row.append(")");
        System.out.println(row);
      }
    }
  }

  static String shortMessage(Exception e) {
    String m = e.getMessage();
    if (m == null) {
      return e.toString();
    }
    for (String line : m.split("\n")) {
      String t = line.trim();
      if (t.startsWith("Error: ")) {
        return t.substring("Error: ".length()).trim();
      }
    }
    return m.trim();
  }

  public static void main(String[] args) throws Exception {
    Config c = parseArgs(args);
    try (Connection conn = DriverManager.getConnection("jdbc:duckdb:");
        Statement stmt = conn.createStatement()) {
      stmt.execute("INSTALL ducklake");
      stmt.execute("INSTALL postgres");
      stmt.execute("INSTALL httpfs");
      stmt.execute("LOAD ducklake");
      stmt.execute("LOAD postgres");
      stmt.execute("LOAD httpfs");

      if (c.lake().equals("local")) {
        // The lake was seeded inside docker, where its stored data_path is
        // /data/.... From the host, override it with the host-side path
        // (see lakes/local/README.md).
        String p = c.localPath().replace("'", "''");
        stmt.execute("ATTACH 'ducklake:" + p + "' AS lake "
            + "(DATA_PATH '" + p + ".files/', OVERRIDE_DATA_PATH true)");
      } else {
        // S3-compatible object store (Garage: path style, plain HTTP).
        stmt.execute("CREATE OR REPLACE SECRET s3_sec (TYPE S3, PROVIDER config, "
            + "KEY_ID " + q(S3_KEY) + ", SECRET " + q(S3_SECRET)
            + ", ENDPOINT " + q(S3_ENDPOINT) + ", URL_STYLE 'path', USE_SSL false, "
            + "REGION " + q(S3_REGION) + ")");
        // Postgres catalog.
        stmt.execute("CREATE OR REPLACE SECRET pg_sec (TYPE postgres, "
            + "HOST " + q(PG_HOST) + ", PORT " + PG_PORT
            + ", DATABASE " + q(PG_DB) + ", USER " + q(PG_USER)
            + ", PASSWORD " + q(PG_PASSWORD) + ")");
        // DuckLake binding the two together.
        stmt.execute("CREATE OR REPLACE SECRET lake_sec (TYPE ducklake, METADATA_PATH '', "
            + "DATA_PATH " + q(DATA_PATH) + ", "
            + "METADATA_PARAMETERS MAP {'TYPE': 'postgres', 'SECRET': 'pg_sec'})");
        stmt.execute("ATTACH 'ducklake:lake_sec' AS lake");
      }
      stmt.execute("USE lake");

      // Write a row...
      stmt.execute("CREATE SCHEMA IF NOT EXISTS clinic");
      stmt.execute("CREATE TABLE IF NOT EXISTS clinic.checkins (id INTEGER, note VARCHAR)");
      stmt.execute("INSERT INTO clinic.checkins "
          + "SELECT coalesce(max(id), -1) + 1, 'check-in from java' FROM clinic.checkins");

      // ...read it back...
      System.out.println("checkins:");
      printRows(stmt, "SELECT * FROM clinic.checkins ORDER BY id");

      // ...and look at the lake metadata.
      System.out.println("settings:");
      printRows(stmt, "FROM lake.settings()");

      List<Long> ids = new ArrayList<>();
      List<String> changes = new ArrayList<>();
      try (ResultSet rs = stmt.executeQuery("FROM lake.snapshots()")) {
        while (rs.next()) {
          ids.add(rs.getLong(1));
          changes.add(rs.getString(4));
        }
      }
      System.out.println("snapshots (" + ids.size() + ", last 3):");
      for (int i = Math.max(0, ids.size() - 3); i < ids.size(); i++) {
        System.out.println("  (" + ids.get(i) + ", " + changes.get(i) + ")");
      }

      // Time travel to the first snapshot holding table data. Our checkins table
      // may be younger than that snapshot, hence the try/catch.
      long target = ids.get(ids.size() - 1);
      for (int i = 0; i < ids.size(); i++) {
        if (changes.get(i) != null && changes.get(i).contains("tables_inserted_into")) {
          target = ids.get(i);
          break;
        }
      }
      System.out.println("time travel to VERSION => " + target + ":");
      try {
        printRows(stmt, "SELECT * FROM clinic.checkins AT (VERSION => " + target + ") ORDER BY id");
      } catch (Exception e) {
        System.out.println("  (unavailable at that version: " + shortMessage(e) + ")");
      }
    }
  }
}
