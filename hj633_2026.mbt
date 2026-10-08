///|
/// The breakpoint tables the Chinese standard publishes, HJ 633—2026.
///
/// 表3 of the standard lists, for each pollutant and averaging window, the
/// concentrations at which the sub-index reaches each of the eight fixed
/// points. A table here is that column turned into rows, one per step, and
/// `iaqi` walks the rows.
///
/// Two of the columns stop short of the others, and the standard says what
/// to do past the end rather than carrying the table on:
///
/// * an SO₂ one-hour concentration above 800 µg/m³ is reported as a
///   sub-index of 200, the last row of that column;
/// * an O₃ eight-hour concentration above 800 µg/m³ is reported as 300.
///
/// Both are exactly what `iaqi` already does with a concentration above its
/// table, so the truncated columns are stored truncated and the rule falls
/// out of the interpolation rather than being a special case in it.
///
/// The standard replaced HJ 633—2012 on 2026-03-01, which mattered: the
/// PM10 and PM2.5 columns both tightened at the 100 step, from 150 and 75
/// µg/m³ to 120 and 60.

///|
/// The pollutants the standard's tables cover.
pub enum Pollutant {
  /// PM2.5, fine particulate matter.
  Pm25
  /// PM10, coarse particulate matter.
  Pm10
  /// Sulphur dioxide.
  So2
  /// Nitrogen dioxide.
  No2
  /// Carbon monoxide, the one pollutant measured in milligrams.
  Co
  /// Ozone.
  O3
}

///|
/// Two pollutants are the same when they are the same pollutant.
pub extend Pollutant with Eq::{not_equal, equal}

///|
pub impl Eq for Pollutant with fn equal(self, other) {
  match (self, other) {
    (Pm25, Pm25) => true
    (Pm10, Pm10) => true
    (So2, So2) => true
    (No2, No2) => true
    (Co, Co) => true
    (O3, O3) => true
    _ => false
  }
}

///|
/// The averaging window a concentration is reported over. The standard
/// carries one-hour limits for the real-time report and daily ones for the
/// daily report, plus an eight-hour window for ozone in the daily report.
pub enum Averaging {
  /// One hour, for the real-time report.
  OneHour
  /// Eight hours, the window the daily report judges ozone over.
  EightHour
  /// A day, for the daily report.
  Daily
}

///|
/// Every pollutant, in the order the standard's table lists them.
pub fn Pollutant::all() -> Array[Pollutant] {
  [Pm25, Pm10, So2, No2, Co, O3]
}

///|
/// Every averaging window.
pub fn Averaging::all() -> Array[Averaging] {
  [OneHour, EightHour, Daily]
}

///|
/// The name the standard uses.
pub fn Pollutant::name(self : Pollutant) -> String {
  match self {
    Pm25 => "PM2.5"
    Pm10 => "PM10"
    So2 => "SO2"
    No2 => "NO2"
    Co => "CO"
    O3 => "O3"
  }
}

///|
/// The unit a concentration is measured in. Everything is in micrograms per
/// cubic metre except carbon monoxide, which the standard measures in
/// milligrams.
pub fn Pollutant::unit(self : Pollutant) -> String {
  match self {
    Co => "mg/m3"
    _ => "ug/m3"
  }
}

///|
/// The fixing of the index axis: every column in 表3 is read at the same
/// eight points.
fn index_axis() -> Array[Int] {
  [0, 50, 100, 150, 200, 300, 400, 500]
}

///|
/// Turn one concentration column of 表3 into rows. `indices` must be as long
/// as `concentrations`.
fn column(
  concentrations : Array[Double],
  indices : Array[Int],
) -> Array[Breakpoint] {
  let rows : Array[Breakpoint] = []
  for i = 0; i + 1 < concentrations.length(); i = i + 1 {
    rows.push(
      Breakpoint::new(
        concentrations[i],
        concentrations[i + 1],
        indices[i],
        indices[i + 1],
      ),
    )
  }
  rows
}

///|
/// The breakpoint table the standard publishes for a pollutant and averaging
/// window — 表3 of HJ 633—2026.
///
/// `None` when the standard publishes no table for the pair: the one-hour
/// limits are only for the real-time report, and only ozone is judged over
/// eight hours.
pub fn hj633_2026(
  pollutant : Pollutant,
  averaging : Averaging,
) -> Array[Breakpoint]? {
  let index = index_axis()
  match (pollutant, averaging) {
    (Pm25, Daily) =>
      Some(column([0.0, 35.0, 60.0, 115.0, 150.0, 250.0, 350.0, 500.0], index))
    (Pm10, Daily) =>
      Some(column([0.0, 50.0, 120.0, 250.0, 350.0, 420.0, 500.0, 600.0], index))
    (So2, Daily) =>
      Some(
        column([0.0, 50.0, 150.0, 475.0, 800.0, 1600.0, 2100.0, 2620.0], index),
      )
    (No2, Daily) =>
      Some(column([0.0, 40.0, 80.0, 180.0, 280.0, 565.0, 750.0, 940.0], index))
    (Co, Daily) =>
      Some(column([0.0, 2.0, 4.0, 14.0, 24.0, 36.0, 48.0, 60.0], index))
    (O3, EightHour) =>
      Some(
        column([0.0, 100.0, 160.0, 215.0, 265.0, 800.0], [
          0, 50, 100, 150, 200, 300,
        ]),
      )
    (So2, OneHour) =>
      Some(column([0.0, 150.0, 500.0, 650.0, 800.0], [0, 50, 100, 150, 200]))
    (No2, OneHour) =>
      Some(
        column(
          [0.0, 100.0, 200.0, 700.0, 1200.0, 2340.0, 3090.0, 3840.0],
          index,
        ),
      )
    (Co, OneHour) =>
      Some(column([0.0, 5.0, 10.0, 35.0, 60.0, 90.0, 120.0, 150.0], index))
    (O3, OneHour) =>
      Some(
        column([0.0, 160.0, 200.0, 300.0, 400.0, 800.0, 1000.0, 1200.0], index),
      )
    _ => None
  }
}
