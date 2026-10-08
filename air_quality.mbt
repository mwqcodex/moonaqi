///|
/// Combining a report's readings into an index.
///
/// ```moonbit nocheck
/// let readings = [
///   @moonaqi.Reading::of(@moonaqi.Pm25, @moonaqi.Daily, 60.0),
///   @moonaqi.Reading::of(@moonaqi.No2, @moonaqi.Daily, 40.0),
/// ]
/// let air = @moonaqi.aqi(readings).unwrap()
/// air.index()    // 100
/// air.dominant() // [Pm25]
/// ```

///|
/// Which report a set of readings is for.
pub(all) enum Report {
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
/// Two are not the obvious one: ozone is judged over its maximum eight-hour
/// average in the daily report, and PM10 and PM2.5 have no one-hour limit, so
/// the real-time report reads them against the daily column.
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
/// over. This is where the standard's exceptions for ozone, PM10 and PM2.5
/// live.
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
pub struct AirQuality {
  index : Int
  sub_indices : Array[(Pollutant, Int)]
  dominant : Array[Pollutant]
  non_attainment : Array[Pollutant]
}

///|
/// Which standard's breakpoints an index is computed from.
pub(all) enum Standard {
  /// China's HJ 633—2026.
  China
  /// The United States EPA's AQI.
  Epa
}

///|
/// The breakpoint table a standard publishes for a pollutant and window.
pub fn breakpoints(
  standard : Standard,
  pollutant : Pollutant,
  averaging : Averaging,
) -> Array[Breakpoint]? {
  match standard {
    China => hj633_2026(pollutant, averaging)
    Epa => epa(pollutant, averaging)
  }
}

///|
/// The rounding a standard asks for: China carries the index up, the EPA
/// rounds to the nearest integer.
pub fn rounding_of(standard : Standard) -> Rounding {
  match standard {
    China => CarryUp
    Epa => Nearest
  }
}

///|
/// Put a report's sub-indices together into an index.
fn combine(sub_indices : Array[(Pollutant, Int)]) -> AirQuality? {
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
/// The index for a set of readings, from a chosen standard's tables.
///
/// A reading the standard publishes no column for is left out rather than
/// refused. The EPA truncates a concentration before it looks it up, so that
/// is done here too. A report with nothing usable in it gives `None`.
pub fn aqi_with(standard : Standard, readings : Array[Reading]) -> AirQuality? {
  let sub_indices : Array[(Pollutant, Int)] = []
  for reading in readings {
    match breakpoints(standard, reading.pollutant, reading.averaging) {
      Some(table) => {
        let concentration = match standard {
          Epa => epa_truncate(reading.pollutant, reading.concentration)
          China => reading.concentration
        }
        match iaqi_with(table, concentration, rounding_of(standard)) {
          Some(sub_index) => sub_indices.push((reading.pollutant, sub_index))
          None => ()
        }
      }
      None => ()
    }
  }
  combine(sub_indices)
}

///|
/// The index for a set of readings, from China's tables.
pub fn aqi(readings : Array[Reading]) -> AirQuality? {
  aqi_with(China, readings)
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
