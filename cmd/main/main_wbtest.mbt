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
