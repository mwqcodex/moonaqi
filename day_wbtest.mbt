///|
/// A station's day: twenty-four hours of PM2.5 and NO2 that sit on the first
/// step of the table, and ozone that spends half the day at a level the
/// eight-hour average will pick up.
fn station_day(station : String) -> Day {
  let day = Day::new(station)
  for hour = 0; hour < 24; hour = hour + 1 {
    day.record(Pm25, Some(35.0))
    day.record(No2, Some(40.0))
    day.record(O3, Some(if hour < 12 { 100.0 } else { 160.0 }))
  }
  day
}

///|
test "a day of hours becomes the day's indicators" {
  let day = station_day("TEST")
  let readings = day.readings(DayRules::new(day_rule(), ozone_rule()))
  inspect(readings.length().to_string(), content="3")
  // Every pollutant but ozone is the day's average, which here is the value
  // every hour carried.
  let air = day.aqi(China, DayRules::new(day_rule(), ozone_rule())).unwrap()
  @debug.debug_inspect(air.sub_index(Pm25), content="Some(50)")
  @debug.debug_inspect(air.sub_index(No2), content="Some(50)")
  // Ozone is the day's highest eight-hour average, not its whole-day average:
  // twelve hours at 160 make one, and the table puts that at 100.
  @debug.debug_inspect(air.sub_index(O3), content="Some(100)")
  @debug.debug_inspect(air.index(), content="100")
  inspect(air.category().name(), content="Good")
  inspect(air.dominant()[0].name(), content="O3")
}

///|
/// Ozone judged over the whole day instead of over its worst eight hours
/// would read far lower here, which is the difference the rule makes.
test "ozone is judged over its worst eight hours, not its average" {
  let day = station_day("TEST")
  let ozone = day.hourly(O3).unwrap()
  match ozone.mean(6) {
    Some(whole_day) => inspect((whole_day == 130.0).to_string(), content="true")
    None => abort("the day has a whole-day average")
  }
  match ozone.maximum_rolling(ozone_rule()) {
    Some(worst) => inspect((worst == 160.0).to_string(), content="true")
    None => abort("the day has a worst eight hours")
  }
}

///|
test "a pollutant too thin to average is left out, not guessed at" {
  let day = Day::new("THIN")
  for hour = 0; hour < 24; hour = hour + 1 {
    day.record(Pm25, Some(35.0))
    // Two hours of ozone is short of the six an eight-hour window wants.
    day.record(O3, if hour < 2 { Some(160.0) } else { None })
  }
  let air = day.aqi(China, DayRules::new(day_rule(), ozone_rule())).unwrap()
  @debug.debug_inspect(air.sub_indices().length(), content="1")
  @debug.debug_inspect(air.sub_index(O3), content="None")
  @debug.debug_inspect(air.index(), content="50")
}

///|
test "the latest hour is what a real-time report is made of" {
  let day = station_day("TEST")
  let readings = day.latest_readings()
  inspect(readings.length().to_string(), content="3")
  let air = aqi_with(China, readings).unwrap()
  // The last hour of ozone is 160, which the one-hour column reads as 50 —
  // a very different number from the 100 the daily column gives the same
  // concentration, which is why the two reports are not interchangeable.
  @debug.debug_inspect(air.sub_index(O3), content="Some(50)")
  @debug.debug_inspect(air.index(), content="50")
}

///|
/// A station that was down for half the day does not drag the city's hours
/// towards zero: the city's hour is the average of the stations that reported
/// it, not of every station.
test "a city's hour averages the stations that reported it" {
  let a = Day::new("A")
  let b = Day::new("B")
  for hour = 0; hour < 24; hour = hour + 1 {
    a.record(Pm25, Some(35.0))
    b.record(Pm25, if hour < 12 { None } else { Some(45.0) })
  }
  let city = Day::merged("CITY", [a, b])
  let hours = city.hourly(Pm25).unwrap()
  @debug.debug_inspect(hours.length(), content="24")
  // Twelve hours of A alone at 35, twelve of both at the mean of 35 and 45.
  match hours.mean(20) {
    Some(value) => inspect((value == 37.5).to_string(), content="true")
    None => abort("the city's day has an average")
  }
}

///|
test "a city with no stations has an empty day" {
  let city = Day::merged("CITY", [])
  inspect(city.hours().length().to_string(), content="0")
  @debug.debug_inspect(
    city.aqi(China, DayRules::new(day_rule(), ozone_rule())) is None,
    content="true",
  )
}
