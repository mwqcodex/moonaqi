///|
/// The air quality index, computed from pollutant concentrations.
///
/// The index is not measured, it is derived: each pollutant's concentration
/// is mapped onto a common 0-500 scale by piecewise-linear interpolation
/// against a published table of breakpoints, and the day's index is the worst
/// of those sub-indices. Because the tables are what the standards actually
/// say, and because the same arithmetic serves every pollutant, the whole
/// computation is one interpolation and a maximum.
///
/// ```moonbit nocheck
/// let table = @moonaqi.pm25_24h()
/// let sub = @moonaqi.iaqi(table, 55.0)   // Some(75)
/// let category = @moonaqi.AqiCategory::of(75)  // Good
/// ```

///|
/// One row of a breakpoint table: the concentration range that maps onto an
/// index range.
///
/// The concentration is in the unit the standard uses for that pollutant —
/// micrograms per cubic metre for everything but carbon monoxide, which is in
/// milligrams.
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
/// The sub-index for one pollutant: where `concentration` falls in `table`,
/// scaled onto the index range of the row it lands in.
///
/// The interpolation is the one the standards write out —
/// `(I_high - I_low) / (C_high - C_low) * (C - C_low) + I_low` — and the
/// result is rounded to the nearest integer, which is how an index is
/// reported.
///
/// A concentration above the last row's ceiling is reported as that row's
/// index, so a value off the end of the table cannot produce a sub-index the
/// table has no room for. A negative concentration is not a measurement, and
/// gives `None`.
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
      return Some((scaled + 0.5).to_int())
    }
  }
  None
}

///|
/// The band the index falls in, which is what an index is read for.
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
/// The band an index falls in.
///
/// The boundaries are the ones the Chinese standard draws: 50, 100, 150, 200
/// and 300, with everything above 300 in the last band.
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
