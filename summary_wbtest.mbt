///|
/// An index from one reading, for tests that only need the summary's
/// arithmetic.
fn index_of(pollutant : Pollutant, concentration : Double) -> AirQuality {
  match aqi_with(China, [Reading::of(pollutant, Daily, concentration)]) {
    Some(air) => air
    None => abort("a single reading always indexes")
  }
}

///|
test "a period counts the days that were good and the days that were heavy" {
  let summary = Summary::new()
  summary.add("A", index_of(Pm25, 35.0)) // 50, good
  summary.add("B", index_of(Pm25, 60.0)) // 100, good
  summary.add("C", index_of(Pm25, 115.0)) // 150, neither
  summary.add("D", index_of(Pm25, 250.0)) // 300, heavy
  inspect(summary.days().to_string(), content="4")
  inspect(summary.good_days().to_string(), content="2")
  inspect(summary.heavy_days().to_string(), content="1")
  match summary.good_rate() {
    Some(rate) => inspect((rate == 0.5).to_string(), content="true")
    None => abort("four days have a rate")
  }
  match summary.average_index() {
    Some(mean) => inspect((mean == 150.0).to_string(), content="true")
    None => abort("four days have a mean")
  }
}

///|
test "the worst day keeps the station it came from" {
  let summary = Summary::new()
  summary.add("CALM", index_of(Pm25, 35.0))
  summary.add("WORST", index_of(Pm25, 250.0))
  summary.add("MIDDLE", index_of(Pm25, 115.0))
  @debug.debug_inspect(summary.worst_index(), content="Some(300)")
  inspect(summary.worst_station().unwrap(), content="WORST")
}

///|
/// A good day names no primary pollutant — the standard only names one above
/// 50 — so a period of good days has nothing to report as most frequent.
test "a period of good days names no primary pollutant" {
  let summary = Summary::new()
  summary.add("A", index_of(Pm25, 35.0))
  @debug.debug_inspect(summary.most_frequent_primary() is None, content="true")
  inspect(summary.primary_counts().length().to_string(), content="0")
}

///|
test "the most frequent primary pollutant is counted once per day" {
  let summary = Summary::new()
  summary.add("A", index_of(Pm25, 60.0))
  summary.add("B", index_of(Pm25, 115.0))
  summary.add("C", index_of(Pm25, 250.0))
  summary.add("D", index_of(Pm25, 35.0)) // no primary pollutant at 50
  inspect(summary.primary_counts().length().to_string(), content="1")
  @debug.debug_inspect(summary.primary_counts()[0].1, content="3")
  inspect(summary.most_frequent_primary().unwrap().name(), content="PM2.5")
}

///|
test "an empty summary has no rate, mean or worst day" {
  let summary = Summary::new()
  inspect(summary.days().to_string(), content="0")
  @debug.debug_inspect(summary.good_rate() is None, content="true")
  @debug.debug_inspect(summary.average_index() is None, content="true")
  @debug.debug_inspect(summary.worst_index() is None, content="true")
  @debug.debug_inspect(summary.worst_station() is None, content="true")
  @debug.debug_inspect(summary.most_frequent_primary() is None, content="true")
}
