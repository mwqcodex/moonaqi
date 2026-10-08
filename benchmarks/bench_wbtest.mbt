///|
/// The readings the report benchmarks run on: a moderately polluted day.
fn sample_readings() -> Array[@moonaqi.Reading] {
  [
    @moonaqi.Reading::new(@moonaqi.Pm25, @moonaqi.Daily, 115.0),
    @moonaqi.Reading::new(@moonaqi.Pm10, @moonaqi.Daily, 120.0),
    @moonaqi.Reading::new(@moonaqi.So2, @moonaqi.Daily, 50.0),
    @moonaqi.Reading::new(@moonaqi.No2, @moonaqi.Daily, 40.0),
    @moonaqi.Reading::new(@moonaqi.Co, @moonaqi.Daily, 4.0),
    @moonaqi.Reading::new(@moonaqi.O3, @moonaqi.EightHour, 160.0),
  ]
}

///|
/// Twelve hourly PM2.5 values, the window a NowCast reads.
fn sample_hours() -> Array[Double?] {
  let hourly : Array[Double?] = []
  for i = 0; i < 12; i = i + 1 {
    hourly.push(Some(10.0 + i.to_double()))
  }
  hourly
}

///|
test "bench a lookup in a table" (it : @bench.T) {
  let table = match @moonaqi.hj633_2026(@moonaqi.Pm25, @moonaqi.Daily) {
    Some(table) => table
    None => abort("the 2026 standard publishes PM2.5")
  }
  it.bench(fn() { it.keep(@moonaqi.iaqi(table, 87.5)) })
}

///|
test "bench a whole report" (it : @bench.T) {
  let readings = sample_readings()
  it.bench(fn() { it.keep(@moonaqi.aqi(readings)) })
}

///|
test "bench the NowCast" (it : @bench.T) {
  let hourly = sample_hours()
  it.bench(fn() { it.keep(@moonaqi.nowcast_pm25(hourly)) })
}

///|
test "bench the EPA truncation" (it : @bench.T) {
  it.bench(fn() { it.keep(@moonaqi.epa_truncate(@moonaqi.Pm25, 35.4567)) })
}

///|
test "bench a band lookup" (it : @bench.T) {
  it.bench(fn() { it.keep(@moonaqi.AqiCategory::of(175)) })
}
