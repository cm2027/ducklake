package com.github.cm2027.ducklake.cmd;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

public class AppTest {

  @Test
  public void quoteDoublesSingleQuotes() {
    assertEquals("'o''brien'", App.q("o'brien"));
    assertEquals("'plain'", App.q("plain"));
  }

  @Test
  public void argDefaultsAreLocalLake() {
    App.Config c = App.parseArgs(new String[] {});
    assertEquals("local", c.lake());
    assertEquals("lakes/local/data/my_ducklake.ducklake", c.localPath());
  }

  @Test
  public void argEqualsAndSpaceFormsBothWork() {
    App.Config c = App.parseArgs(new String[] { "--lake=pg", "--local-path", "x.ducklake" });
    assertEquals("pg", c.lake());
    assertEquals("x.ducklake", c.localPath());
  }

  @ParameterizedTest
  @ValueSource(strings = { "--bogus", "--lake" })
  public void badArgsFailFast(String arg) {
    assertThrows(IllegalArgumentException.class, () -> App.parseArgs(new String[] { arg }));
  }

  @Test
  public void badLakeNameFailsFast() {
    assertThrows(IllegalArgumentException.class, () -> App.parseArgs(new String[] { "--lake", "s3" }));
  }

  @Test
  public void shortMessageUnwrapsJdbcNoise() {
    Exception e = new RuntimeException(
        "Invalid Input Error: Attempting to execute closed result\nError: Catalog Error: nope");
    assertEquals("Catalog Error: nope", App.shortMessage(e));
    assertEquals("plain", App.shortMessage(new RuntimeException("plain")));
  }
}
