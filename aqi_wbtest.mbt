///|
/// A table with the same shape as the real ones, for testing the arithmetic
/// without depending on a published table.
fn test_table() -> Array[Breakpoint] {
  [
    Breakpoint::new(0.0, 35.0, 0, 50),
    Breakpoint::new(35.0, 75.0, 50, 100),
    Breakpoint::new(75.0, 115.0, 100, 150),
    Breakpoint::new(115.0, 150.0, 150, 200),
    Breakpoint::new(150.0, 250.0, 200, 300),
    Breakpoint::new(250.0, 350.0, 300, 400),
    Breakpoint::new(350.0, 500.0, 400, 500),
  ]
}

///|
test "iaqi lands on the breakpoints" {
  let table = test_table()
  @debug.debug_inspect(iaqi(table, 0.0), content="Some(0)")
  @debug.debug_inspect(iaqi(table, 35.0), content="Some(50)")
  @debug.debug_inspect(iaqi(table, 75.0), content="Some(100)")
  @debug.debug_inspect(iaqi(table, 115.0), content="Some(150)")
  @debug.debug_inspect(iaqi(table, 150.0), content="Some(200)")
  @debug.debug_inspect(iaqi(table, 250.0), content="Some(300)")
  @debug.debug_inspect(iaqi(table, 350.0), content="Some(400)")
  @debug.debug_inspect(iaqi(table, 500.0), content="Some(500)")
}

///|
test "iaqi interpolates between the breakpoints" {
  let table = test_table()
  // Halfway up 35..75, so halfway up 50..100.
  @debug.debug_inspect(iaqi(table, 55.0), content="Some(75)")
  // The 150..250 row is a long climb: 200 -> 300 over 100 ug/m3.
  @debug.debug_inspect(iaqi(table, 200.0), content="Some(250)")
  @debug.debug_inspect(iaqi(table, 249.0), content="Some(299)")
}

///|
test "iaqi rounds to the nearest integer" {
  let table = [Breakpoint::new(0.0, 10.0, 0, 100)]
  // 3.5 of 10 maps to 35 exactly.
  @debug.debug_inspect(iaqi(table, 3.5), content="Some(35)")
  // 3.55 of 10 is 35.5, which rounds up.
  @debug.debug_inspect(iaqi(table, 3.55), content="Some(36)")
}

///|
test "iaqi clamps above the table" {
  let table = test_table()
  @debug.debug_inspect(iaqi(table, 900.0), content="Some(500)")
}

///|
test "iaqi rejects what is not a measurement" {
  let table = test_table()
  @debug.debug_inspect(iaqi(table, -1.0), content="None")
  @debug.debug_inspect(iaqi([], 10.0), content="None")
}

///|
test "categories follow the standard's boundaries" {
  inspect(AqiCategory::of(0).name(), content="Excellent")
  inspect(AqiCategory::of(50).name(), content="Excellent")
  inspect(AqiCategory::of(51).name(), content="Good")
  inspect(AqiCategory::of(100).name(), content="Good")
  inspect(AqiCategory::of(101).name(), content="Lightly polluted")
  inspect(AqiCategory::of(150).name(), content="Lightly polluted")
  inspect(AqiCategory::of(151).name(), content="Moderately polluted")
  inspect(AqiCategory::of(200).name(), content="Moderately polluted")
  inspect(AqiCategory::of(201).name(), content="Heavily polluted")
  inspect(AqiCategory::of(300).name(), content="Heavily polluted")
  inspect(AqiCategory::of(301).name(), content="Severely polluted")
  inspect(AqiCategory::of(500).name(), content="Severely polluted")
}

///|
test "category names" {
  inspect(AqiCategory::of(40).name(), content="Excellent")
  inspect(AqiCategory::of(40).chinese_name(), content="优")
  inspect(AqiCategory::of(400).chinese_name(), content="严重污染")
  inspect(AqiCategory::all().length(), content="6")
}
