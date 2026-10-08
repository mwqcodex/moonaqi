///|
/// The tables of HJ 633—2012.
///
/// HJ 633—2026 replaced this standard on 2026-03-01, and two steps moved: at
/// an index of 100, PM10 went from 150 to 120 ug/m3 and PM2.5 from 75 to 60.
/// Everything else in 表1 is the same in both, so the two functions return
/// the same rows for the other columns.
///
/// The 2012 table also has the same two footnotes the 2026 one kept: an SO₂
/// one-hour concentration above 800 ug/m3 is reported as 200, and an O₃
/// eight-hour concentration above 800 ug/m3 as 300. Those columns are stored
/// truncated here for the same reason, and `iaqi` clamps to the last row.
pub fn hj633_2012(
  pollutant : Pollutant,
  averaging : Averaging,
) -> Array[Breakpoint]? {
  let index = index_axis()
  match (pollutant, averaging) {
    (Pm25, Daily) =>
      Some(column([0.0, 35.0, 75.0, 115.0, 150.0, 250.0, 350.0, 500.0], index))
    (Pm10, Daily) =>
      Some(column([0.0, 50.0, 150.0, 250.0, 350.0, 420.0, 500.0, 600.0], index))
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
