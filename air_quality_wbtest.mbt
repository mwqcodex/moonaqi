///|
/// A report's index is its worst sub-index, and the pollutant that set it is
/// the one the standard calls the primary pollutant.
test "the index is the worst sub-index" {
  let air = aqi([Reading::of(Pm25, Daily, 60.0), Reading::of(No2, Daily, 40.0)]).unwrap()
  @debug.debug_inspect(air.index(), content="100")
  @debug.debug_inspect(air.sub_index(Pm25), content="Some(100)")
  @debug.debug_inspect(air.sub_index(No2), content="Some(50)")
  @debug.debug_inspect(air.sub_index(Co), content="None")
  inspect(air.category().name(), content="Good")
  @debug.debug_inspect(air.dominant().length(), content="1")
  inspect(air.dominant()[0].name(), content="PM2.5")
}

///|
/// The standard allows two pollutants to be named together when their
/// sub-indices tie.
test "a tie names both pollutants" {
  let air = aqi([
    Reading::of(Pm25, Daily, 115.0),
    Reading::of(Pm10, Daily, 250.0),
    Reading::of(So2, Daily, 150.0),
  ]).unwrap()
  @debug.debug_inspect(air.index(), content="150")
  @debug.debug_inspect(air.dominant().length(), content="2")
  @debug.debug_inspect(air.non_attainment().length(), content="2")
  inspect(air.category().name(), content="Lightly polluted")
}

///|
/// The standard names a primary pollutant only once the index is above 50, so
/// a day that lands exactly on 50 names none.
test "a clean day names no primary pollutant" {
  let air = aqi([Reading::of(Pm25, Daily, 35.0), Reading::of(No2, Daily, 40.0)]).unwrap()
  @debug.debug_inspect(air.index(), content="50")
  @debug.debug_inspect(air.dominant().length(), content="0")
  @debug.debug_inspect(air.non_attainment().length(), content="0")
  inspect(air.category().name(), content="Excellent")
}

///|
/// The non-attainment list is what went past the standard's second limit.
test "the non-attainment list is what went past 100" {
  let air = aqi([Reading::of(Pm25, Daily, 150.0)]).unwrap()
  @debug.debug_inspect(air.index(), content="200")
  @debug.debug_inspect(air.non_attainment().length(), content="1")
  inspect(air.non_attainment()[0].name(), content="PM2.5")
}

///|
/// The two windows that are not the obvious one. Read against the wrong
/// column there would be no table at all and the reading would drop out, so
/// an index at all is the assertion.
test "ozone is judged over eight hours and PM over the daily column" {
  let ozone = aqi([Reading::of(O3, Daily, 160.0)]).unwrap()
  @debug.debug_inspect(ozone.index(), content="100")
  let pm = aqi([Reading::of(Pm25, RealTime, 60.0)]).unwrap()
  @debug.debug_inspect(pm.index(), content="100")
}

///|
/// A pair the standard publishes no column for leaves that indicator out
/// rather than failing the report — the standard expects a missing indicator
/// to be described, not to sink the report.
test "a reading with no table is a missing indicator" {
  let air = aqi([
    Reading::new(So2, EightHour, 100.0),
    Reading::of(Pm25, Daily, 60.0),
  ]).unwrap()
  @debug.debug_inspect(air.index(), content="100")
  @debug.debug_inspect(air.sub_indices().length(), content="1")
}

///|
test "a report with nothing usable has no index" {
  @debug.debug_inspect(aqi([]) is None, content="true")
  @debug.debug_inspect(
    aqi([Reading::new(So2, EightHour, 100.0)]) is None,
    content="true",
  )
}

///|
test "the sub-indices come back in the order the readings were given" {
  let air = aqi([Reading::of(Co, Daily, 4.0), Reading::of(Pm25, Daily, 60.0)]).unwrap()
  @debug.debug_inspect(air.sub_indices().length(), content="2")
  inspect(air.sub_indices()[0].0.name(), content="CO")
  @debug.debug_inspect(air.sub_indices()[0].1, content="100")
  inspect(air.sub_indices()[1].0.name(), content="PM2.5")
}
