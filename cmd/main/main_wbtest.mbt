///|
/// The pollutant a flag names, as text, so a test reads as the flag does.
fn flag_name(flag : String) -> String {
  match pollutant_of(flag) {
    Some(pollutant) => pollutant.name()
    None => "(none)"
  }
}

///|
test "the flags name the pollutants" {
  inspect(flag_name("--pm25"), content="PM2.5")
  inspect(flag_name("--pm10"), content="PM10")
  inspect(flag_name("--so2"), content="SO2")
  inspect(flag_name("--no2"), content="NO2")
  inspect(flag_name("--co"), content="CO")
  inspect(flag_name("--o3"), content="O3")
  inspect(flag_name("--bogus"), content="(none)")
}

///|
test "a concentration is read as a decimal" {
  inspect(parse_decimal("115").unwrap().to_int().to_string(), content="115")
  inspect(parse_decimal("4.5").unwrap().to_int().to_string(), content="4")
  inspect(parse_decimal("0").unwrap().to_int().to_string(), content="0")
  @debug.debug_inspect(parse_decimal("abc") is None, content="true")
  @debug.debug_inspect(parse_decimal("") is None, content="true")
  @debug.debug_inspect(parse_decimal("1.2.3") is None, content="true")
  @debug.debug_inspect(parse_decimal(".") is None, content="true")
  @debug.debug_inspect(parse_decimal("-5") is None, content="true")
}

///|
test "overrides replace the default readings" {
  let readings = readings_from(["--pm25", "150"], @moonaqi.Daily).unwrap()
  let air = @moonaqi.aqi(readings).unwrap()
  inspect(air.index().to_string(), content="200")
  inspect(air.dominant()[0].name(), content="PM2.5")
}

///|
test "the default readings are the ones the demo prints" {
  let readings = readings_from([], @moonaqi.Daily).unwrap()
  let air = @moonaqi.aqi(readings).unwrap()
  inspect(air.index().to_string(), content="150")
  inspect(air.category().name(), content="Lightly polluted")
  inspect(air.dominant().length().to_string(), content="1")
  inspect(air.non_attainment().length().to_string(), content="1")
}

///|
test "an argument that is not understood gives nothing back" {
  @debug.debug_inspect(
    readings_from(["--bogus"], @moonaqi.Daily) is None,
    content="true",
  )
  @debug.debug_inspect(
    readings_from(["--pm25"], @moonaqi.Daily) is None,
    content="true",
  )
  @debug.debug_inspect(
    readings_from(["--pm25", "x"], @moonaqi.Daily) is None,
    content="true",
  )
}

///|
test "padding lines a column up" {
  inspect(pad_right("ab", 5), content="ab   ")
  inspect(pad_right("abcde", 3), content="abcde")
}

///|
test "the report comes out as json" {
  let readings = readings_from(["--json"], @moonaqi.Daily).unwrap()
  let air = @moonaqi.aqi(readings).unwrap()
  let json = report_json(air, readings, @moonaqi.Daily)
  inspect(json.has_prefix("{"), content="true")
  inspect(json.has_suffix("}"), content="true")
  inspect(json.contains("\"report\": \"daily\""), content="true")
  inspect(json.contains("\"aqi\": 150"), content="true")
  inspect(json.contains("\"colour\": \"Orange\""), content="true")
  inspect(json.contains("\"colour_rgb\": [255, 126, 0]"), content="true")
  inspect(json.contains("\"pollutant\": \"PM2.5\""), content="true")
  inspect(json.contains("\"primary_pollutants\": [\"PM2.5\"]"), content="true")
  inspect(json.contains("\"non_attainment\": [\"PM2.5\"]"), content="true")
  inspect(json.contains("轻度污染"), content="true")
}

///|
test "a realtime report says so in its json" {
  let readings = readings_from(["--realtime", "--json"], @moonaqi.RealTime).unwrap()
  let air = @moonaqi.aqi(readings).unwrap()
  let json = report_json(air, readings, @moonaqi.RealTime)
  inspect(json.contains("\"report\": \"realtime\""), content="true")
}

///|
/// A series as the command line writes it, in a form a test can compare.
fn series_text(text : String) -> String {
  match parse_series(text) {
    Some(hours) => {
      let out = StringBuilder(size_hint=32)
      for hour in hours {
        out.write_string(
          match hour {
            Some(value) => "\{value} "
            None => "- "
          },
        )
      }
      out.to_string()
    }
    None => "(unreadable)"
  }
}

///|
test "a series repeats a value" {
  inspect(series_text("35x3"), content="35 35 35 ")
  inspect(series_text("35"), content="35 ")
  inspect(series_text("100x2,160x2"), content="100 100 160 160 ")
}

///|
/// A leading comma is an hour with no reading, which is how a day with a gap
/// is written on the command line.
test "an empty element is a missing hour" {
  inspect(series_text(",40x2"), content="- 40 40 ")
  inspect(series_text("35x2,"), content="35 35 - ")
}

///|
test "a series that cannot be read is refused rather than guessed at" {
  inspect(series_text("35x"), content="(unreadable)")
  inspect(series_text("35xabc"), content="(unreadable)")
  inspect(series_text("x3"), content="(unreadable)")
}

///|
test "the pollutants are named as the tables spell them" {
  inspect(pollutant_named("PM2.5").unwrap().name(), content="PM2.5")
  inspect(pollutant_named("O3").unwrap().name(), content="O3")
  inspect(pollutant_named("pm2.5") is None, content="true")
  inspect(pollutant_named("XX") is None, content="true")
}

///|
test "whole numbers" {
  @debug.debug_inspect(whole_number("24"), content="Some(24)")
  @debug.debug_inspect(whole_number("0"), content="Some(0)")
  @debug.debug_inspect(whole_number("1.5") is None, content="true")
  @debug.debug_inspect(whole_number("abc") is None, content="true")
  @debug.debug_inspect(whole_number("") is None, content="true")
}
