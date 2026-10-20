///|
/// Summarising a period of days.
///
/// A report is rarely one day. A monthly summary counts the days that were
/// good, the days that were heavy, the worst of them, and which pollutant
/// kept setting the index — the four things a period is described by.
///
/// Everything here is counted from the days the library has already indexed,
/// so a summary cannot disagree with the days it summarises.

///|
/// A running summary of days.
pub(all) struct Summary {
  mut days : Int32
  mut total_index : Int32
  mut good_days : Int32
  mut heavy_days : Int32
  mut worst_index : Int32?
  mut worst_station : String?
  primary_counts : Array[(Pollutant, Int32)]
}

///|
/// An empty summary.
pub fn Summary::new() -> Summary {
  {
    days: 0,
    total_index: 0,
    good_days: 0,
    heavy_days: 0,
    worst_index: None,
    worst_station: None,
    primary_counts: [],
  }
}

///|
/// Add one day's index, and the station it came from.
///
/// A day is counted as good when its index is at or below 100, which is the
/// boundary both standards draw for the second band; it is counted as heavy
/// above 200, where the fourth band begins. Those are the bands' own
/// boundaries rather than numbers invented here.
pub fn Summary::add(self : Summary, station : String, air : AirQuality) -> Unit {
  let index = air.index()
  self.days += 1
  self.total_index += index
  if index <= 100 {
    self.good_days += 1
  }
  if index > 200 {
    self.heavy_days += 1
  }
  self.worst_index = match self.worst_index {
    Some(worst) =>
      if index > worst {
        self.worst_station = Some(station)
        Some(index)
      } else {
        Some(worst)
      }
    None => {
      self.worst_station = Some(station)
      Some(index)
    }
  }
  // Count the pollutant that set the index, once per day.
  for pollutant in air.dominant() {
    let mut seen = false
    for entry in self.primary_counts {
      if entry.0 == pollutant {
        seen = true
      }
    }
    if seen {
      for i = 0; i < self.primary_counts.length(); i = i + 1 {
        if self.primary_counts[i].0 == pollutant {
          self.primary_counts[i] = (pollutant, self.primary_counts[i].1 + 1)
        }
      }
    } else {
      self.primary_counts.push((pollutant, 1))
    }
  }
}

///|
/// How many days have been added.
pub fn Summary::days(self : Summary) -> Int32 {
  self.days
}

///|
/// How many of them were at or below 100.
pub fn Summary::good_days(self : Summary) -> Int32 {
  self.good_days
}

///|
/// The share of days at or below 100, as a fraction of one, or `None` for an
/// empty summary.
pub fn Summary::good_rate(self : Summary) -> Double? {
  if self.days == 0 {
    None
  } else {
    Some(self.good_days.to_double() / self.days.to_double())
  }
}

///|
/// How many days were above 200.
pub fn Summary::heavy_days(self : Summary) -> Int32 {
  self.heavy_days
}

///|
/// The mean index over the days, or `None` for an empty summary.
pub fn Summary::average_index(self : Summary) -> Double? {
  if self.days == 0 {
    None
  } else {
    Some(self.total_index.to_double() / self.days.to_double())
  }
}

///|
/// The worst index in the period.
pub fn Summary::worst_index(self : Summary) -> Int32? {
  self.worst_index
}

///|
/// The station the worst day came from.
pub fn Summary::worst_station(self : Summary) -> String? {
  self.worst_station
}

///|
/// How often each pollutant set the index, as pairs of pollutant and count,
/// in the order they were first seen.
pub fn Summary::primary_counts(self : Summary) -> Array[(Pollutant, Int32)] {
  self.primary_counts
}

///|
/// The pollutant that set the index most often, or `None` when no day named
/// one.
pub fn Summary::most_frequent_primary(self : Summary) -> Pollutant? {
  let mut best : Pollutant? = None
  let mut best_count = 0
  for entry in self.primary_counts {
    if entry.1 > best_count {
      best = Some(entry.0)
      best_count = entry.1
    }
  }
  best
}
