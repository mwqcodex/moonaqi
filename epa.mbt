///|
/// The United States EPA's breakpoints and its NowCast.
///
/// The EPA's tables differ from China's in three ways that are not cosmetic:
///
/// * the units are what the EPA measures in, so ozone and carbon monoxide are
///   in ppm and sulphur dioxide and nitrogen dioxide in ppb;
/// * a concentration is truncated to a fixed number of places before it is
///   looked up, so 35.45 ug/m3 of PM2.5 is read as 35.4;
/// * the index is rounded to the nearest integer rather than carried up.
///
/// The breakpoints are the ones the EPA's Air Quality System publishes.

///|
/// The unit a concentration is measured in, in the EPA's tables.
pub fn epa_unit(pollutant : Pollutant) -> String {
  match pollutant {
    Pm25 | Pm10 => "ug/m3"
    Co | O3 => "ppm"
    So2 | No2 => "ppb"
  }
}

///|
/// The number of decimal places the EPA truncates a concentration to before
/// looking it up.
fn epa_places(pollutant : Pollutant) -> Int {
  match pollutant {
    O3 => 3
    Pm25 | Co => 1
    Pm10 | So2 | No2 => 0
  }
}

///|
/// `value` truncated, not rounded, to `places` decimals.
fn truncate_to(value : Double, places : Int) -> Double {
  let mut scale = 1.0
  for i = 0; i < places; i = i + 1 {
    scale = scale * 10.0
  }
  // The nudge keeps a value that is only below its integer because of how a
  // double rounds from being truncated one step too far.
  let scaled = value * scale + 1.0e-9
  scaled.to_int().to_double() / scale
}

///|
/// `value` truncated the way the EPA truncates a concentration of
/// `pollutant` before using it.
pub fn epa_truncate(pollutant : Pollutant, value : Double) -> Double {
  truncate_to(value, epa_places(pollutant))
}

///|
/// The breakpoint table the EPA publishes for a pollutant and averaging
/// window, or `None` for a pair it does not carry.
///
/// Note the shapes the EPA's own tables have: the ozone one-hour column only
/// starts at an index of 101, because it is only used when the eight-hour
/// concentration goes above 0.200 ppm; the sulphur dioxide one-hour column
/// stops at 200 for the same kind of reason, and its daily column only starts
/// above 304 ppb.
pub fn epa(pollutant : Pollutant, averaging : Averaging) -> Array[Breakpoint]? {
  match (pollutant, averaging) {
    (Pm25, Daily) =>
      Some([
        Breakpoint::new(0.0, 9.0, 0, 50),
        Breakpoint::new(9.1, 35.4, 51, 100),
        Breakpoint::new(35.5, 55.4, 101, 150),
        Breakpoint::new(55.5, 125.4, 151, 200),
        Breakpoint::new(125.5, 225.4, 201, 300),
        Breakpoint::new(225.5, 325.4, 301, 500),
      ])
    (Pm10, Daily) =>
      Some([
        Breakpoint::new(0.0, 54.0, 0, 50),
        Breakpoint::new(55.0, 154.0, 51, 100),
        Breakpoint::new(155.0, 254.0, 101, 150),
        Breakpoint::new(255.0, 354.0, 151, 200),
        Breakpoint::new(355.0, 424.0, 201, 300),
        Breakpoint::new(425.0, 604.0, 301, 500),
      ])
    (O3, EightHour) =>
      Some([
        Breakpoint::new(0.0, 0.054, 0, 50),
        Breakpoint::new(0.055, 0.07, 51, 100),
        Breakpoint::new(0.071, 0.085, 101, 150),
        Breakpoint::new(0.086, 0.105, 151, 200),
        Breakpoint::new(0.106, 0.2, 201, 300),
      ])
    (O3, OneHour) =>
      Some([
        Breakpoint::new(0.125, 0.164, 101, 150),
        Breakpoint::new(0.165, 0.204, 151, 200),
        Breakpoint::new(0.205, 0.404, 201, 300),
        Breakpoint::new(0.405, 0.604, 301, 500),
      ])
    (Co, EightHour) =>
      Some([
        Breakpoint::new(0.0, 4.4, 0, 50),
        Breakpoint::new(4.5, 9.4, 51, 100),
        Breakpoint::new(9.5, 12.4, 101, 150),
        Breakpoint::new(12.5, 15.4, 151, 200),
        Breakpoint::new(15.5, 30.4, 201, 300),
        Breakpoint::new(30.5, 50.4, 301, 500),
      ])
    (So2, OneHour) =>
      Some([
        Breakpoint::new(0.0, 35.0, 0, 50),
        Breakpoint::new(36.0, 75.0, 51, 100),
        Breakpoint::new(76.0, 185.0, 101, 150),
        Breakpoint::new(186.0, 304.0, 151, 200),
      ])
    (So2, Daily) =>
      Some([
        Breakpoint::new(305.0, 604.0, 201, 300),
        Breakpoint::new(605.0, 1004.0, 301, 500),
      ])
    (No2, OneHour) =>
      Some([
        Breakpoint::new(0.0, 53.0, 0, 50),
        Breakpoint::new(54.0, 100.0, 51, 100),
        Breakpoint::new(101.0, 360.0, 101, 150),
        Breakpoint::new(361.0, 649.0, 151, 200),
        Breakpoint::new(650.0, 1249.0, 201, 300),
        Breakpoint::new(1250.0, 2049.0, 301, 500),
      ])
    _ => None
  }
}

///|
/// The EPA's NowCast for PM2.5: a weighted average of the last twelve hourly
/// concentrations.
///
/// `hourly` is most recent first, and up to twelve hours are read. The weight
/// is the ratio of the smallest to the largest concentration in the window,
/// floored at a half, so a steady window is averaged almost evenly and a
/// window that is moving puts most of the weight on the recent hours. Hours
/// with no measurement are left out of both sums.
///
/// The EPA computes a NowCast only when at least two of the last three hours
/// have a measurement, and neither does this.
pub fn nowcast_pm25(hourly : Array[Double?]) -> Double? {
  let window = if hourly.length() > 12 { 12 } else { hourly.length() }
  let mut present = 0
  let mut recent = 0
  let mut smallest = 0.0
  let mut largest = 0.0
  let mut seen = false
  for i = 0; i < window; i = i + 1 {
    match hourly[i] {
      Some(value) => {
        if value < 0.0 {
          return None
        }
        present += 1
        if i < 3 {
          recent += 1
        }
        if !seen || value < smallest {
          smallest = value
        }
        if !seen || value > largest {
          largest = value
        }
        seen = true
      }
      None => ()
    }
  }
  if recent < 2 || present == 0 {
    return None
  }
  if largest <= 0.0 {
    return Some(0.0)
  }
  let raw = smallest / largest
  let weight = if raw < 0.5 { 0.5 } else { raw }
  let mut numerator = 0.0
  let mut denominator = 0.0
  let mut factor = 1.0
  for i = 0; i < window; i = i + 1 {
    match hourly[i] {
      Some(value) => {
        numerator = numerator + value * factor
        denominator = denominator + factor
      }
      None => ()
    }
    factor = factor * weight
  }
  Some(numerator / denominator)
}
