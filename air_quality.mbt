///|
/// Putting a report's readings together into an index.
///
/// The index is the worst of the sub-indices, and the standard reads two
/// things off the report besides it: the pollutant or pollutants that set it,
/// which is only named once the index is above 50, and the pollutants that
/// went past 100, which the standard calls the non-attainment ones.
///
/// ```moonbit nocheck
/// let readings = [
///   @moonaqi.Reading::of(@moonaqi.Pm25, @moonaqi.Daily, 60.0),
///   @moonaqi.Reading::of(@moonaqi.No2, @moonaqi.Daily, 40.0),
/// ]
/// let air = @moonaqi.aqi(readings).unwrap()
/// air.index()                                  // 100
/// air.dominant()                               // [Pm25]
/// ```

///|
/// Which report a set of readings is for. The standard carries two: the daily
/// report, over day averages, and the real-time report, over the latest hour.
pub enum Report {
  /// 日报: the day's averages.
  Daily
  /// 实时报: the latest hour.
  RealTime
}

///|
/// Both reports.
pub fn Report::all() -> Array[Report] {
  [Daily, RealTime]
}

///|
/// The averaging window the standard judges a pollutant over in a report.
///
/// Two of the windows are not the obvious one:
///
/// * ozone is the one pollutant the daily report judges over its maximum
///   eight-hour average rather than its daily average;
/// * PM10 and PM2.5 have no one-hour limit, so the real-time report has their
///   one-hour concentration read against the daily column — 表3's footnote
///   says so, and the low and high breakpoints come from there.
pub fn window_for(pollutant : Pollutant, report : Report) -> Averaging {
  match (pollutant, report) {
    (O3, Daily) => EightHour
    (Pm25, RealTime) => Daily
    (Pm10, RealTime) => Daily
    (_, Daily) => Daily
    (_, RealTime) => OneHour
  }
}

///|
/// One pollutant's concentration.
pub struct Reading {
  pollutant : Pollutant
  averaging : Averaging
  concentration : Double
}

///|
/// A reading over an averaging window, named directly.
pub fn Reading::new(
  pollutant : Pollutant,
  averaging : Averaging,
  concentration : Double,
) -> Reading {
  { pollutant, averaging, concentration, }
}

///|
/// A reading for a report, over the window that report judges the pollutant
/// over. This is the one to reach for: it is where the standard's exceptions
/// for ozone, PM10 and PM2.5 live.
pub fn Reading::of(
  pollutant : Pollutant,
  report : Report,
  concentration : Double,
) -> Reading {
  { pollutant, averaging: window_for(pollutant, report), concentration, }
}

///|
/// The pollutant the reading is of.
pub fn Reading::pollutant(self : Reading) -> Pollutant {
  self.pollutant
}

///|
/// The averaging window the concentration is over.
pub fn Reading::averaging(self : Reading) -> Averaging {
  self.averaging
}

///|
/// The concentration, in the unit `Pollutant::unit` names.
pub fn Reading::concentration(self : Reading) -> Double {
  self.concentration
}

///|
/// The index a report's readings add up to.
///
/// A reading the standard publishes no table for is skipped rather than
/// refused — a report that carries a pair the standard does not define is a
/// report with a missing indicator, which the standard expects to be
/// described rather than to fail. When nothing is left, there is no index and
/// the result is `None`.
pub struct AirQuality {
  index : Int
  sub_indices : Array[(Pollutant, Int)]
  dominant : Array[Pollutant]
  non_attainment : Array[Pollutant]
}

///|
/// The index for a set of readings: each sub-index in turn, the worst of them
/// for the index itself, and the pollutants that set it or went past the
/// standard's second limit.
pub fn aqi(readings : Array[Reading]) -> AirQuality? {
  let sub_indices : Array[(Pollutant, Int)] = []
  for reading in readings {
    match hj633_2026(reading.pollutant, reading.averaging) {
      Some(table) =>
        match iaqi(table, reading.concentration) {
          Some(sub_index) => sub_indices.push((reading.pollutant, sub_index))
          None => ()
        }
      None => ()
    }
  }
  if sub_indices.length() == 0 {
    return None
  }
  let mut index = 0
  for entry in sub_indices {
    let (_, sub_index) = entry
    if sub_index > index {
      index = sub_index
    }
  }
  let dominant : Array[Pollutant] = []
  let non_attainment : Array[Pollutant] = []
  for entry in sub_indices {
    let (pollutant, sub_index) = entry
    // The standard names a primary pollutant only once the index is above
    // 50, and allows more than one to be named.
    if index > 50 && sub_index == index {
      dominant.push(pollutant)
    }
    if sub_index > 100 {
      non_attainment.push(pollutant)
    }
  }
  Some({ index, sub_indices, dominant, non_attainment, })
}

///|
/// The index itself.
pub fn AirQuality::index(self : AirQuality) -> Int {
  self.index
}

///|
/// The band the index falls in.
pub fn AirQuality::category(self : AirQuality) -> AqiCategory {
  AqiCategory::of(self.index)
}

///|
/// The pollutant or pollutants that set the index, which the standard names
/// only once the index is above 50.
pub fn AirQuality::dominant(self : AirQuality) -> Array[Pollutant] {
  self.dominant
}

///|
/// The pollutants that went past the standard's second limit.
pub fn AirQuality::non_attainment(self : AirQuality) -> Array[Pollutant] {
  self.non_attainment
}

///|
/// Every sub-index the report produced, in the order the readings came in.
pub fn AirQuality::sub_indices(self : AirQuality) -> Array[(Pollutant, Int)] {
  self.sub_indices
}

///|
/// The sub-index for one pollutant, when the report carried it.
pub fn AirQuality::sub_index(self : AirQuality, pollutant : Pollutant) -> Int? {
  for entry in self.sub_indices {
    let (reported, sub_index) = entry
    if reported == pollutant {
      return Some(sub_index)
    }
  }
  None
}
