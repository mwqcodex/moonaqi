///|
/// The table for a pair, unwrapped, so that a test reads as the standard.
fn table_for(pollutant : Pollutant, averaging : Averaging) -> Array[Breakpoint] {
  match hj633_2026(pollutant, averaging) {
    Some(table) => table
    None => abort("the standard publishes this table")
  }
}

///|
test "the PM2.5 column reaches each index at the standard's concentration" {
  let table = table_for(Pm25, Daily)
  @debug.debug_inspect(iaqi(table, 0.0), content="Some(0)")
  @debug.debug_inspect(iaqi(table, 35.0), content="Some(50)")
  @debug.debug_inspect(iaqi(table, 60.0), content="Some(100)")
  @debug.debug_inspect(iaqi(table, 115.0), content="Some(150)")
  @debug.debug_inspect(iaqi(table, 150.0), content="Some(200)")
  @debug.debug_inspect(iaqi(table, 250.0), content="Some(300)")
  @debug.debug_inspect(iaqi(table, 350.0), content="Some(400)")
  @debug.debug_inspect(iaqi(table, 500.0), content="Some(500)")
}

///|
/// The 2026 tables tightened these two steps relative to the 2012 ones: PM10
/// reached 100 at 120 ug/m3 rather than 150, and PM2.5 at 60 rather than 75.
test "the particulate columns are the 2026 ones, not the 2012 ones" {
  @debug.debug_inspect(iaqi(table_for(Pm10, Daily), 120.0), content="Some(100)")
  @debug.debug_inspect(iaqi(table_for(Pm25, Daily), 60.0), content="Some(100)")
}

///|
test "the remaining columns reach 100 where the standard says" {
  @debug.debug_inspect(iaqi(table_for(So2, Daily), 150.0), content="Some(100)")
  @debug.debug_inspect(iaqi(table_for(No2, Daily), 80.0), content="Some(100)")
  @debug.debug_inspect(iaqi(table_for(Co, Daily), 4.0), content="Some(100)")
  @debug.debug_inspect(
    iaqi(table_for(O3, EightHour), 160.0),
    content="Some(100)",
  )
}

///|
test "the one-hour columns reach 100 where the standard says" {
  @debug.debug_inspect(
    iaqi(table_for(So2, OneHour), 500.0),
    content="Some(100)",
  )
  @debug.debug_inspect(
    iaqi(table_for(No2, OneHour), 200.0),
    content="Some(100)",
  )
  @debug.debug_inspect(iaqi(table_for(Co, OneHour), 10.0), content="Some(100)")
  @debug.debug_inspect(iaqi(table_for(O3, OneHour), 200.0), content="Some(100)")
}

///|
/// 表3's footnotes: the SO2 one-hour column stops at 800, and anything above
/// it is reported as 200 rather than carried into the next index step. Same
/// for O3 over eight hours, which stops at 300.
test "the truncated columns stop where the footnotes say" {
  @debug.debug_inspect(
    iaqi(table_for(So2, OneHour), 800.0),
    content="Some(200)",
  )
  @debug.debug_inspect(
    iaqi(table_for(So2, OneHour), 1500.0),
    content="Some(200)",
  )
  @debug.debug_inspect(
    iaqi(table_for(O3, EightHour), 800.0),
    content="Some(300)",
  )
  @debug.debug_inspect(
    iaqi(table_for(O3, EightHour), 2000.0),
    content="Some(300)",
  )
}

///|
test "the standard publishes no table for the pairs it does not list" {
  @debug.debug_inspect(hj633_2026(So2, EightHour) is None, content="true")
  @debug.debug_inspect(hj633_2026(Pm25, OneHour) is None, content="true")
  @debug.debug_inspect(hj633_2026(Pm10, OneHour) is None, content="true")
  @debug.debug_inspect(hj633_2026(No2, EightHour) is None, content="true")
  @debug.debug_inspect(hj633_2026(Co, EightHour) is None, content="true")
  @debug.debug_inspect(hj633_2026(So2, EightHour) is None, content="true")
}

///|
test "every pollutant carries the unit the standard measures it in" {
  @debug.debug_inspect(Pollutant::all().length(), content="6")
  inspect(Co.unit(), content="mg/m3")
  inspect(Pm25.unit(), content="ug/m3")
  inspect(Pm25.name(), content="PM2.5")
  @debug.debug_inspect(Averaging::all().length(), content="3")
}
