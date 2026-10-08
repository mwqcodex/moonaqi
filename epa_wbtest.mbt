///|
/// A concentration scaled to an integer, so that a test can compare a double
/// without depending on how it prints.
fn scaled(value : Double) -> String {
  (value * 10000.0 + 0.5).to_int().to_string()
}

///|
/// A NowCast scaled to an integer, for the same reason.
fn nowcast_milli(hourly : Array[Double?]) -> String {
  match nowcast_pm25(hourly) {
    Some(value) => (value * 1000.0 + 0.5).to_int().to_string()
    None => "(none)"
  }
}

///|
/// A table, unwrapped.
fn epa_table(pollutant : Pollutant, averaging : Averaging) -> Array[Breakpoint] {
  match epa(pollutant, averaging) {
    Some(table) => table
    None => abort("the EPA publishes this table")
  }
}

///|
/// The 2024 revision tightened the PM2.5 steps: the index reaches 50 at
/// 9.0 ug/m3 rather than 12.0.
test "the PM2.5 column is the revised one" {
  let table = epa_table(Pm25, Daily)
  @debug.debug_inspect(iaqi_with(table, 0.0, Nearest), content="Some(0)")
  @debug.debug_inspect(iaqi_with(table, 9.0, Nearest), content="Some(50)")
  @debug.debug_inspect(iaqi_with(table, 35.4, Nearest), content="Some(100)")
  @debug.debug_inspect(iaqi_with(table, 55.4, Nearest), content="Some(150)")
  @debug.debug_inspect(iaqi_with(table, 125.4, Nearest), content="Some(200)")
  @debug.debug_inspect(iaqi_with(table, 225.4, Nearest), content="Some(300)")
  @debug.debug_inspect(iaqi_with(table, 325.4, Nearest), content="Some(500)")
}

///|
test "the other EPA columns reach 50 and 100 where the EPA says" {
  @debug.debug_inspect(
    iaqi_with(epa_table(Pm10, Daily), 54.0, Nearest),
    content="Some(50)",
  )
  @debug.debug_inspect(
    iaqi_with(epa_table(Pm10, Daily), 154.0, Nearest),
    content="Some(100)",
  )
  @debug.debug_inspect(
    iaqi_with(epa_table(O3, EightHour), 0.054, Nearest),
    content="Some(50)",
  )
  @debug.debug_inspect(
    iaqi_with(epa_table(O3, EightHour), 0.07, Nearest),
    content="Some(100)",
  )
  @debug.debug_inspect(
    iaqi_with(epa_table(Co, EightHour), 4.4, Nearest),
    content="Some(50)",
  )
  @debug.debug_inspect(
    iaqi_with(epa_table(So2, OneHour), 35.0, Nearest),
    content="Some(50)",
  )
  @debug.debug_inspect(
    iaqi_with(epa_table(No2, OneHour), 53.0, Nearest),
    content="Some(50)",
  )
  @debug.debug_inspect(
    iaqi_with(epa_table(No2, OneHour), 100.0, Nearest),
    content="Some(100)",
  )
}

///|
/// The EPA's ozone one-hour column only starts at 101 and its sulphur
/// dioxide daily column only at 201, because that is where those columns are
/// used from.
test "the EPA columns that start partway up" {
  @debug.debug_inspect(epa_table(O3, OneHour)[0].index_low(), content="101")
  @debug.debug_inspect(
    iaqi_with(epa_table(O3, OneHour), 0.05, Nearest) is None,
    content="true",
  )
  @debug.debug_inspect(
    iaqi_with(epa_table(O3, OneHour), 0.125, Nearest),
    content="Some(101)",
  )
  @debug.debug_inspect(epa_table(So2, Daily)[0].index_low(), content="201")
  @debug.debug_inspect(
    iaqi_with(epa_table(So2, Daily), 100.0, Nearest) is None,
    content="true",
  )
  @debug.debug_inspect(
    iaqi_with(epa_table(So2, Daily), 305.0, Nearest),
    content="Some(201)",
  )
}

///|
test "the EPA carries no column for these pairs" {
  @debug.debug_inspect(epa(Pm25, OneHour) is None, content="true")
  @debug.debug_inspect(epa(Pm10, OneHour) is None, content="true")
  @debug.debug_inspect(epa(O3, Daily) is None, content="true")
  @debug.debug_inspect(epa(Co, Daily) is None, content="true")
  @debug.debug_inspect(epa(No2, Daily) is None, content="true")
}

///|
/// The EPA truncates before it looks a concentration up, so 35.45 ug/m3 of
/// PM2.5 is read as 35.4 and not as 35.5.
test "a concentration is truncated before the lookup" {
  inspect(scaled(epa_truncate(Pm25, 35.45)), content="354000")
  inspect(scaled(epa_truncate(Pm25, 9.09)), content="90000")
  inspect(scaled(epa_truncate(Pm10, 154.9)), content="1540000")
  inspect(scaled(epa_truncate(So2, 75.9)), content="750000")
  inspect(scaled(epa_truncate(O3, 0.0708)), content="700")
  inspect(scaled(epa_truncate(Co, 9.49)), content="94000")
}

///|
/// The two standards round the same value differently, and HJ 633's rule is
/// the one that reports the higher index.
test "the two standards round differently" {
  let table = [Breakpoint::new(50.0, 120.0, 50, 100)]
  // 53 ug/m3 of PM10 is 52.14 on the index axis.
  @debug.debug_inspect(iaqi_with(table, 53.0, CarryUp), content="Some(53)")
  @debug.debug_inspect(iaqi_with(table, 53.0, Nearest), content="Some(52)")
}

///|
test "an EPA report comes out of the same aqi as a Chinese one" {
  let readings = [
    Reading::new(Pm25, Daily, 20.0),
    Reading::new(O3, EightHour, 0.07),
  ]
  let air = aqi_with(Epa, readings).unwrap()
  @debug.debug_inspect(air.index(), content="100")
  inspect(air.category().name(), content="Good")
  inspect(air.dominant()[0].name(), content="O3")
  @debug.debug_inspect(air.sub_index(Pm25), content="Some(71)")
}

///|
test "a steady window is averaged evenly" {
  inspect(nowcast_milli([Some(10.0), Some(10.0), Some(10.0)]), content="10000")
  inspect(nowcast_milli([Some(0.0), Some(0.0)]), content="0")
}

///|
/// A window that is moving falls back on the half floor, which puts most of
/// the weight on the recent hours.
test "a moving window weights the recent hours" {
  // min 10, max 30, so the raw weight is a third and the floor lifts it to a
  // half: (30 + 20*0.5 + 10*0.25) / (1 + 0.5 + 0.25) = 24.2857.
  inspect(nowcast_milli([Some(30.0), Some(20.0), Some(10.0)]), content="24286")
}

///|
test "a hole is left out of both sums" {
  inspect(nowcast_milli([Some(5.0), None, Some(5.0)]), content="5000")
  inspect(nowcast_milli([Some(5.0), Some(5.0)]), content="5000")
}

///|
/// The EPA computes a NowCast only when at least two of the last three hours
/// have a measurement.
test "too few of the recent hours stops the NowCast" {
  inspect(nowcast_milli([Some(5.0), None, None]), content="(none)")
  inspect(nowcast_milli([Some(5.0)]), content="(none)")
  inspect(nowcast_milli([None, None, None]), content="(none)")
  inspect(nowcast_milli([]), content="(none)")
}

///|
test "a negative hour is not a measurement" {
  inspect(nowcast_milli([Some(-1.0), Some(5.0)]), content="(none)")
}

///|
test "only the last twelve hours are read" {
  let hourly : Array[Double?] = []
  for i = 0; i < 12; i = i + 1 {
    hourly.push(Some(1.0))
  }
  hourly.push(Some(999.0))
  inspect(nowcast_milli(hourly), content="1000")
}
