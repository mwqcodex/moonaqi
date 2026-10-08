///|
/// Air quality index computation from pollutant concentrations.
///
/// ```moonbit nocheck
/// let table = @moonaqi.hj633_2026(@moonaqi.Pm25, @moonaqi.Daily).unwrap()
/// let sub = @moonaqi.iaqi(table, 60.0)          // Some(100)
/// let category = @moonaqi.AqiCategory::of(100)  // Good
/// ```

///|
/// One row of a breakpoint table: a concentration range and the index range
/// it maps onto, in the unit the standard measures that pollutant in.
pub struct Breakpoint {
  concentration_low : Double
  concentration_high : Double
  index_low : Int
  index_high : Int
}

///|
/// One row of a breakpoint table.
pub fn Breakpoint::new(
  concentration_low : Double,
  concentration_high : Double,
  index_low : Int,
  index_high : Int,
) -> Breakpoint {
  { concentration_low, concentration_high, index_low, index_high, }
}

///|
/// The concentration at the low end of the row.
pub fn Breakpoint::concentration_low(self : Breakpoint) -> Double {
  self.concentration_low
}

///|
/// The concentration at the high end of the row.
pub fn Breakpoint::concentration_high(self : Breakpoint) -> Double {
  self.concentration_high
}

///|
/// The index at the low end of the row.
pub fn Breakpoint::index_low(self : Breakpoint) -> Int {
  self.index_low
}

///|
/// The index at the high end of the row.
pub fn Breakpoint::index_high(self : Breakpoint) -> Int {
  self.index_high
}

///|
/// `value` carried up to the next integer: 75.0 stays 75, 75.1 becomes 76.
///
/// The tolerance absorbs the last-bit error of an interpolation that lands on
/// an integer.
fn carry_up(value : Double) -> Int {
  let truncated = value.to_int()
  if value - truncated.to_double() > 1.0e-9 {
    truncated + 1
  } else {
    truncated
  }
}

///|
/// The sub-index for one pollutant: where `concentration` falls in `table`.
///
/// The result is carried up to the next integer, not rounded to the nearest:
/// HJ 633—2012 §6.2 and HJ 633—2026 §4.2.6 both ask for 向上进位取整.
///
/// A concentration above the last row is reported as that row's index. A
/// negative concentration is not a measurement, and gives `None`.
pub fn iaqi(table : Array[Breakpoint], concentration : Double) -> Int? {
  if table.length() == 0 || concentration < 0.0 {
    return None
  }
  let last = table[table.length() - 1]
  if concentration >= last.concentration_high {
    return Some(last.index_high)
  }
  for row in table {
    if concentration >= row.concentration_low &&
      concentration <= row.concentration_high {
      let span = row.concentration_high - row.concentration_low
      if span <= 0.0 {
        return None
      }
      let index_span = (row.index_high - row.index_low).to_double()
      let scaled = index_span / span * (concentration - row.concentration_low) +
        row.index_low.to_double()
      return Some(carry_up(scaled))
    }
  }
  None
}

///|
/// The band the index falls in.
pub enum AqiCategory {
  /// 优: good enough that no one has to think about it.
  Excellent
  /// 良: acceptable.
  Good
  /// 轻度污染: light pollution.
  LightlyPolluted
  /// 中度污染: moderate pollution.
  ModeratelyPolluted
  /// 重度污染: heavy pollution.
  HeavilyPolluted
  /// 严重污染: severe pollution.
  SeverelyPolluted
}

///|
/// The band an index falls in: 50, 100, 150, 200 and 300 are the boundaries,
/// as the Chinese standard draws them.
pub fn AqiCategory::of(index : Int) -> AqiCategory {
  if index <= 50 {
    Excellent
  } else if index <= 100 {
    Good
  } else if index <= 150 {
    LightlyPolluted
  } else if index <= 200 {
    ModeratelyPolluted
  } else if index <= 300 {
    HeavilyPolluted
  } else {
    SeverelyPolluted
  }
}

///|
/// Every band, worst last.
pub fn AqiCategory::all() -> Array[AqiCategory] {
  [
    Excellent,
    Good,
    LightlyPolluted,
    ModeratelyPolluted,
    HeavilyPolluted,
    SeverelyPolluted,
  ]
}

///|
/// The band's English name.
pub fn AqiCategory::name(self : AqiCategory) -> String {
  match self {
    Excellent => "Excellent"
    Good => "Good"
    LightlyPolluted => "Lightly polluted"
    ModeratelyPolluted => "Moderately polluted"
    HeavilyPolluted => "Heavily polluted"
    SeverelyPolluted => "Severely polluted"
  }
}

///|
/// The band's name as the Chinese standard writes it.
pub fn AqiCategory::chinese_name(self : AqiCategory) -> String {
  match self {
    Excellent => "优"
    Good => "良"
    LightlyPolluted => "轻度污染"
    ModeratelyPolluted => "中度污染"
    HeavilyPolluted => "重度污染"
    SeverelyPolluted => "严重污染"
  }
}

///|
/// The lowest index in the band.
pub fn AqiCategory::lower(self : AqiCategory) -> Int {
  match self {
    Excellent => 0
    Good => 51
    LightlyPolluted => 101
    ModeratelyPolluted => 151
    HeavilyPolluted => 201
    SeverelyPolluted => 301
  }
}
