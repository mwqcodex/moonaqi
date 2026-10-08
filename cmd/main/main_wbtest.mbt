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
