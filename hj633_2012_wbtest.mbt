///|
/// A 2012 table, unwrapped.
fn table_2012(
  pollutant : Pollutant,
  averaging : Averaging,
) -> Array[Breakpoint] {
  match hj633_2012(pollutant, averaging) {
    Some(table) => table
    None => abort("the 2012 standard publishes this table")
  }
}

///|
/// A 2026 table, unwrapped.
fn table_2026(
  pollutant : Pollutant,
  averaging : Averaging,
) -> Array[Breakpoint] {
  match hj633_2026(pollutant, averaging) {
    Some(table) => table
    None => abort("the 2026 standard publishes this table")
  }
}

///|
/// The two steps the 2026 standard moved.
test "the particulate steps are looser than the 2026 ones" {
  let pm10 = table_2012(Pm10, Daily)
  @debug.debug_inspect(iaqi(pm10, 50.0), content="Some(50)")
  @debug.debug_inspect(iaqi(pm10, 150.0), content="Some(100)")
  @debug.debug_inspect(iaqi(pm10, 250.0), content="Some(150)")
  let pm25 = table_2012(Pm25, Daily)
  @debug.debug_inspect(iaqi(pm25, 35.0), content="Some(50)")
  @debug.debug_inspect(iaqi(pm25, 75.0), content="Some(100)")
  @debug.debug_inspect(iaqi(pm25, 115.0), content="Some(150)")
}

///|
/// The same concentration lands on a lower index under the older standard.
test "a concentration reads lower under 2012" {
  @debug.debug_inspect(iaqi(table_2012(Pm10, Daily), 120.0), content="Some(85)")
  @debug.debug_inspect(
    iaqi(table_2026(Pm10, Daily), 120.0),
    content="Some(100)",
  )
  @debug.debug_inspect(iaqi(table_2012(Pm25, Daily), 60.0), content="Some(82)")
  @debug.debug_inspect(iaqi(table_2026(Pm25, Daily), 60.0), content="Some(100)")
}

///|
/// Only the two particulate columns moved, so every other column must agree
/// row for row between the two standards.
test "the other columns are the same in both standards" {
  for pollutant in Pollutant::all() {
    for averaging in Averaging::all() {
      if pollutant != Pm25 && pollutant != Pm10 {
        match
          (hj633_2012(pollutant, averaging), hj633_2026(pollutant, averaging)) {
          (Some(old), Some(new)) => {
            @debug.debug_inspect(old.length() == new.length(), content="true")
            for i = 0; i < old.length(); i = i + 1 {
              @debug.debug_inspect(
                old[i].concentration_low() == new[i].concentration_low(),
                content="true",
              )
              @debug.debug_inspect(
                old[i].index_low() == new[i].index_low(),
                content="true",
              )
            }
          }
          (None, None) => ()
          _ => abort("the standards disagree about which columns exist")
        }
      }
    }
  }
}

///|
test "the 2012 standard carries no column for these pairs" {
  @debug.debug_inspect(hj633_2012(So2, EightHour) is None, content="true")
  @debug.debug_inspect(hj633_2012(Pm25, OneHour) is None, content="true")
}

///|
/// The standard is reachable through the same entry point as the others.
test "a 2012 report comes out of aqi_with" {
  let readings = [Reading::new(Pm25, Daily, 60.0)]
  inspect(
    aqi_with(China2012, readings).unwrap().index().to_string(),
    content="82",
  )
  inspect(aqi_with(China, readings).unwrap().index().to_string(), content="100")
}
