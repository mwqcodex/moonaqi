///|
/// One pollutant's hourly concentrations over a day.
///
/// A day of monitoring is not a list of numbers: hours go missing when an
/// instrument is down or a calibration runs, and every standard that asks for
/// an average of them also says how many of the window's hours have to be
/// present for that average to count at all.
///
/// This type holds the hours and answers the two questions the standards ask
/// of them — the average over a window, and the highest such average in the
/// day — leaving the rule about how many hours is enough to the caller,
/// because it is not the same rule everywhere.

///|
/// The averaging rule an authority asks for: how many consecutive hours an
/// average is taken over, and how many of them have to carry a reading.
///
/// The second number is deliberately not a constant of this library. The
/// United States and China both require averages, and both require a minimum
/// number of hours before an average may be reported, but the numbers are
/// theirs to set and have been revised; a caller that reports to one of them
/// supplies that authority's rule.
pub struct Window {
  window : Int32
  minimum_valid : Int32
}

///|
/// A rule of `window` hours, of which `minimum_valid` must carry a reading.
pub fn Window::new(window : Int32, minimum_valid : Int32) -> Window {
  { window, minimum_valid, }
}

///|
/// How many consecutive hours the average is over.
pub fn Window::window(self : Window) -> Int32 {
  self.window
}

///|
/// How many of those hours must carry a reading.
pub fn Window::minimum_valid(self : Window) -> Int32 {
  self.minimum_valid
}

///|
/// One pollutant's hours, in order.
pub struct Hourly {
  pollutant : Pollutant
  values : Array[Double?]
}

///|
/// An empty day for one pollutant.
pub fn Hourly::new(pollutant : Pollutant) -> Hourly {
  { pollutant, values: [], }
}

///|
/// Add the next hour.
///
/// `None` is an hour with no reading, which is not the same as an hour of
/// zero: a monitor that is down did not measure a clean hour, and averaging
/// its outage in as a nought would drag every average it touches towards a
/// number nobody measured.
pub fn Hourly::push(self : Hourly, value : Double?) -> Unit {
  self.values.push(value)
}

///|
/// The pollutant these hours are of.
pub fn Hourly::pollutant(self : Hourly) -> Pollutant {
  self.pollutant
}

///|
/// Every hour, in order, with `None` where there is no reading.
pub fn Hourly::values(self : Hourly) -> Array[Double?] {
  self.values
}

///|
/// How many hours have been recorded, readings or not.
pub fn Hourly::length(self : Hourly) -> Int32 {
  self.values.length()
}

///|
/// The reading at `index`, which counts from the first hour recorded.
pub fn Hourly::at(self : Hourly, index : Int32) -> Double? {
  self.values[index]
}

///|
/// How many of the hours from `start` to `end` inclusive carry a reading.
pub fn Hourly::valid_between(
  self : Hourly,
  start : Int32,
  end : Int32,
) -> Int32 {
  let mut valid = 0
  for i = start; i <= end; i = i + 1 {
    if i >= 0 && i < self.values.length() {
      match self.values[i] {
        Some(_) => valid += 1
        None => ()
      }
    }
  }
  valid
}

///|
/// The average of the `rule`'s hours ending at `end`, or `None` when fewer
/// than the rule's minimum carry a reading.
///
/// A window that runs off the front of the day is shortened rather than
/// refused, so the first hours of a day can still be averaged once enough of
/// them have arrived. The average is taken over the hours that carry a
/// reading, not over the window: a partly missing window is averaged over
/// what was measured.
pub fn Hourly::window_mean(
  self : Hourly,
  end : Int32,
  rule : Window,
) -> Double? {
  let window = rule.window()
  if window <= 0 || end < 0 || end >= self.values.length() {
    return None
  }
  let start = if end + 1 >= window { end + 1 - window } else { 0 }
  let mut total = 0.0
  let mut valid = 0
  for i = start; i <= end; i = i + 1 {
    match self.values[i] {
      Some(value) => {
        total = total + value
        valid += 1
      }
      None => ()
    }
  }
  if valid == 0 || valid < rule.minimum_valid() {
    None
  } else {
    Some(total / valid.to_double())
  }
}

///|
/// Every window ending at an hour of the day, in hour order, with `None`
/// where that window was too thin to average.
pub fn Hourly::rolling(self : Hourly, rule : Window) -> Array[Double?] {
  let averages : Array[Double?] = []
  for end = 0; end < self.values.length(); end = end + 1 {
    averages.push(self.window_mean(end, rule))
  }
  averages
}

///|
/// The highest window average in the day, which is what a standard asks of
/// ozone over eight hours: not the whole-day average but the worst eight-hour
/// stretch within it.
pub fn Hourly::maximum_rolling(self : Hourly, rule : Window) -> Double? {
  let averages = self.rolling(rule)
  let mut best : Double? = None
  for average in averages {
    match average {
      Some(value) =>
        best = match best {
          Some(current) => Some(if value > current { value } else { current })
          None => Some(value)
        }
      None => ()
    }
  }
  best
}

///|
/// The average over every hour recorded, or `None` when fewer than
/// `minimum_valid` of them carry a reading.
pub fn Hourly::mean(self : Hourly, minimum_valid : Int32) -> Double? {
  if self.values.length() == 0 {
    return None
  }
  self.window_mean(
    self.values.length() - 1,
    Window::new(self.values.length(), minimum_valid),
  )
}
