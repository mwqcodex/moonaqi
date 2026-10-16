///|
/// A day at one station, and the report that comes out of it.
///
/// A monitoring station reports concentrations, not indices. Between the two
/// sits the work the standards actually describe: average the day's hours
/// into the indicators a daily report is made of — twenty-four hours for
/// everything but ozone, and the day's highest eight-hour average for ozone —
/// then turn each indicator into a sub-index and take the worst.
///
/// `Hourly` keeps the hours; this keeps a station's worth of them and does
/// the averaging, so that a caller who has a day of raw readings never has to
/// decide what a partly missing window means.

///|
/// How a report averages its hours.
///
/// Both windows are rules rather than numbers because both are the
/// authority's to set: what counts as enough of a day, and enough of an
/// eight-hour stretch, has been revised more than once in both of the
/// standards this library carries.
pub struct DayRules {
  daily : Window
  ozone : Window
}

///|
/// The shape a report is usually built to: a day averaged over `daily` hours,
/// and ozone judged over its highest `ozone`-hour average.
pub fn DayRules::new(daily : Window, ozone : Window) -> DayRules {
  { daily, ozone, }
}

///|
/// The rule the day's other pollutants are averaged under.
pub fn DayRules::daily(self : DayRules) -> Window {
  self.daily
}

///|
/// The rule ozone is judged over.
pub fn DayRules::ozone(self : DayRules) -> Window {
  self.ozone
}

///|
/// A station's day: the hours recorded for each pollutant.
pub struct Day {
  station : String
  hours : Array[Hourly]
}

///|
/// An empty day at a station.
pub fn Day::new(station : String) -> Day {
  { station, hours: [], }
}

///|
/// The station the day is from.
pub fn Day::station(self : Day) -> String {
  self.station
}

///|
/// One entry per pollutant that has been recorded, in the order the
/// pollutants were first seen.
pub fn Day::hours(self : Day) -> Array[Hourly] {
  self.hours
}

///|
/// The hours recorded for one pollutant, when it has any.
pub fn Day::hourly(self : Day, pollutant : Pollutant) -> Hourly? {
  for hours in self.hours {
    if hours.pollutant() == pollutant {
      return Some(hours)
    }
  }
  None
}

///|
/// Record one hour of one pollutant, starting that pollutant's series the
/// first time it is seen.
///
/// An hour is recorded for every pollutant on every pass, so that the series
/// stay aligned and a gap in one pollutant cannot silently shift another's
/// hours. `None` records an hour without a reading.
pub fn Day::record(self : Day, pollutant : Pollutant, value : Double?) -> Unit {
  match self.hourly(pollutant) {
    Some(hours) => hours.push(value)
    None => {
      let hours = Hourly::new(pollutant)
      hours.push(value)
      self.hours.push(hours)
    }
  }
}

///|
/// The day's indicators, ready to be turned into an index: the average of the
/// day's hours for every pollutant but ozone, and the day's highest eight-hour
/// average for ozone.
///
/// A pollutant whose hours were too thin to average under the rules is left
/// out rather than guessed at, which is what the standards mean by a missing
/// indicator.
pub fn Day::readings(self : Day, rules : DayRules) -> Array[Reading] {
  let readings : Array[Reading] = []
  for hours in self.hours {
    let indicator = match hours.pollutant() {
      O3 => hours.maximum_rolling(rules.ozone())
      _ => hours.mean(rules.daily().minimum_valid())
    }
    match indicator {
      Some(value) => readings.push(Reading::of(hours.pollutant(), Daily, value))
      None => ()
    }
  }
  readings
}

///|
/// The day's index under a standard's tables.
pub fn Day::aqi(
  self : Day,
  standard : Standard,
  rules : DayRules,
) -> AirQuality? {
  aqi_with(standard, self.readings(rules))
}

///|
/// The latest hour of every pollutant, which is what a real-time report is
/// made of.
pub fn Day::latest_readings(self : Day) -> Array[Reading] {
  let readings : Array[Reading] = []
  for hours in self.hours {
    if hours.length() > 0 {
      match hours.at(hours.length() - 1) {
        Some(value) =>
          readings.push(Reading::of(hours.pollutant(), RealTime, value))
        None => ()
      }
    }
  }
  readings
}

///|
/// A city's day, from its stations': the average, hour by hour, of the
/// stations that reported that hour.
///
/// A station that did not report an hour does not drag the city's hour
/// towards zero, and a pollutant no station recorded does not appear. The
/// result is a day like any other and is reported with the same rules.
pub fn Day::merged(station : String, stations : Array[Day]) -> Day {
  let merged = Day::new(station)
  if stations.length() == 0 {
    return merged
  }
  // How many hours the longest station recorded, so that every pollutant of
  // the merged day covers the same span.
  let mut span = 0
  for day in stations {
    for hours in day.hours() {
      if hours.length() > span {
        span = hours.length()
      }
    }
  }
  let pollutants : Array[Pollutant] = []
  for day in stations {
    for hours in day.hours() {
      let mut seen = false
      for known in pollutants {
        if known == hours.pollutant() {
          seen = true
        }
      }
      if !seen {
        pollutants.push(hours.pollutant())
      }
    }
  }
  for pollutant in pollutants {
    for hour = 0; hour < span; hour = hour + 1 {
      let mut total = 0.0
      let mut reported = 0
      for day in stations {
        match day.hourly(pollutant) {
          Some(hours) =>
            if hour < hours.length() {
              match hours.at(hour) {
                Some(value) => {
                  total = total + value
                  reported += 1
                }
                None => ()
              }
            }
          None => ()
        }
      }
      merged.record(
        pollutant,
        if reported == 0 {
          None
        } else {
          Some(total / reported.to_double())
        },
      )
    }
  }
  merged
}
