# moonaqi

Air quality index computation in pure MoonBit.

Each pollutant's concentration is mapped onto a common 0–500 scale by
piecewise-linear interpolation against a table of breakpoints, and the index
is the worst of those sub-indices.

## Quick start

```moonbit nocheck
///|
let table = @moonaqi.hj633_2026(@moonaqi.Pm25, @moonaqi.Daily).unwrap()
let sub = @moonaqi.iaqi(table, 60.0)          // Some(100)

///|
let readings = [
  @moonaqi.Reading::of(@moonaqi.Pm25, @moonaqi.Daily, 60.0),
  @moonaqi.Reading::of(@moonaqi.No2, @moonaqi.Daily, 40.0),
]
let air = @moonaqi.aqi(readings).unwrap()
air.index()             // 100
air.category().name()   // "Good"
air.dominant()          // [Pm25]
```

## Interpolation

A breakpoint table maps concentration ranges onto index ranges. The
sub-index is

```
IAQI = (I_high - I_low) / (C_high - C_low) * (C - C_low) + I_low
```

carried up to the next integer, which is what the standard asks for
(向上进位取整).

```moonbit nocheck
///|
let iaqi = @moonaqi.iaqi(
  [
    @moonaqi.Breakpoint::new(0.0, 35.0, 0, 50),
    @moonaqi.Breakpoint::new(35.0, 75.0, 50, 100),
    @moonaqi.Breakpoint::new(75.0, 115.0, 100, 150),
  ],
  55.0,
)
```

A concentration above the last row gives that row's index. A negative one
gives `None`.

## The standard's tables

`hj633_2026` returns the column of 表3 (HJ 633—2026) for a pollutant and
averaging window:

| Pollutant | One hour | Eight hours | Daily |
| --- | --- | --- | --- |
| PM2.5 | — | — | ✓ |
| PM10 | — | — | ✓ |
| SO₂ | ✓ | — | ✓ |
| NO₂ | ✓ | — | ✓ |
| CO | ✓ | — | ✓ |
| O₃ | ✓ | ✓ | — |

A pair with no column returns `None`.

Two columns stop at 800 µg/m³, and the standard gives the sub-index above
that instead of carrying the column on: SO₂ over one hour as 200, O₃ over
eight hours as 300.

HJ 633—2026 replaced HJ 633—2012 on 2026-03-01. The PM10 and PM2.5 columns
tightened at the 100 step, from 150 and 75 µg/m³ to 120 and 60.

## The index

`aqi` combines a report's readings. `Reading::of` picks the window the
standard judges that pollutant over, which is where its exceptions for ozone,
PM10 and PM2.5 live.

```moonbit nocheck
///|
let air = @moonaqi.aqi([
  @moonaqi.Reading::of(@moonaqi.Pm25, @moonaqi.Daily, 60.0),
  @moonaqi.Reading::of(@moonaqi.No2, @moonaqi.Daily, 40.0),
]).unwrap()
```

`dominant()` names the pollutants that set the index, once it is above 50.
`non_attainment()` names the ones past 100.

A reading the standard publishes no column for is left out rather than
refused. A report with nothing usable in it gives `None`.

## Bands

| Index | Band | 中文 |
| --- | --- | --- |
| 0–50 | Excellent | 优 |
| 51–100 | Good | 良 |
| 101–150 | Lightly polluted | 轻度污染 |
| 151–200 | Moderately polluted | 中度污染 |
| 201–300 | Heavily polluted | 重度污染 |
| 301+ | Severely polluted | 严重污染 |

## Testing

```
moon test
```

## Licence

Apache-2.0.
