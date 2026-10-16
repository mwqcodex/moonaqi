///|
/// A day's rule of thumb, for the tests: a day averaged over twenty-four
/// hours of which twenty must be there, and ozone over eight of which six.
fn day_rule() -> Window {
  Window::new(24, 20)
}

///|
fn ozone_rule() -> Window {
  Window::new(8, 6)
}

///|
/// `hours` worth of one value.
fn constant(pollutant : Pollutant, value : Double, hours : Int32) -> Hourly {
  let series = Hourly::new(pollutant)
  for i = 0; i < hours; i = i + 1 {
    series.push(Some(value))
  }
  series
}

///|
test "a full day averages to its value" {
  let series = constant(Pm25, 35.0, 24)
  inspect(series.length().to_string(), content="24")
  match series.mean(day_rule().minimum_valid()) {
    Some(value) => inspect((value == 35.0).to_string(), content="true")
    None => abort("a full day has an average")
  }
}

///|
/// The point of the type: a monitor that was down for an hour did not measure
/// a clean hour, and averaging the outage in as a nought would report a day
/// nobody measured.
test "a missing hour is not a nought" {
  let series = Hourly::new(Pm25)
  for hour = 0; hour < 24; hour = hour + 1 {
    series.push(if hour == 9 { None } else { Some(35.0) })
  }
  inspect(series.valid_between(0, 23).to_string(), content="23")
  match series.mean(day_rule().minimum_valid()) {
    Some(value) => inspect((value == 35.0).to_string(), content="true")
    None => abort("twenty-three good hours are enough for a day")
  }
}

///|
test "too thin a day has no average" {
  let series = constant(Pm25, 35.0, 3)
  match series.mean(day_rule().minimum_valid()) {
    Some(_) => abort("three hours are not a day")
    None => inspect("none", content="none")
  }
}

///|
/// The eight-hour average is a window that slides, not a division of the day
/// into three blocks: the highest window straddles block boundaries.
test "the window slides, and the highest one is the answer" {
  let series = Hourly::new(O3)
  // Twelve hours of 100, then twelve of 160.
  for hour = 0; hour < 24; hour = hour + 1 {
    series.push(Some(if hour < 12 { 100.0 } else { 160.0 }))
  }
  match series.maximum_rolling(ozone_rule()) {
    Some(value) => inspect((value == 160.0).to_string(), content="true")
    None => abort("the day has a highest eight-hour average")
  }
  let averages = series.rolling(ozone_rule())
  inspect(averages.length().to_string(), content="24")
  // The first seven windows have not seen eight hours yet, but six of them
  // carry readings from the first hour, so they are averages all the same.
  inspect((averages[5] is Some(_)).to_string(), content="true")
}

///|
test "a window that is too thin reports nothing" {
  let series = Hourly::new(O3)
  for hour = 0; hour < 24; hour = hour + 1 {
    // Only three hours of the day were measured at all.
    series.push(if hour < 3 { Some(100.0) } else { None })
  }
  match series.window_mean(2, ozone_rule()) {
    Some(_) => abort("three hours is short of the six the rule wants")
    None => inspect("none", content="none")
  }
  match series.maximum_rolling(ozone_rule()) {
    Some(_) => abort("the rule wants six hours in the window")
    None => inspect("none", content="none")
  }
}

///|
test "a window running off the front of the day is shortened" {
  let series = constant(O3, 100.0, 24)
  // The day starts with a window of one, which is short of the six hours the
  // rule wants, so nothing is averaged until enough of the day has arrived.
  @debug.debug_inspect(
    series.window_mean(0, ozone_rule()) is None,
    content="true",
  )
  match series.window_mean(5, ozone_rule()) {
    Some(value) => inspect((value == 100.0).to_string(), content="true")
    None => abort("the sixth hour is the first window the rule accepts")
  }
}
