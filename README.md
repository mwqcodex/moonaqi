# moonaqi

Air quality index computation in pure MoonBit.

The index a weather app shows you is not measured — it is derived. Each
pollutant's concentration is mapped onto a common 0–500 scale by
piecewise-linear interpolation against a table of breakpoints, and the day's
index is the worst of those sub-indices. `moonaqi` is that arithmetic: the
interpolation, the tables the standards publish, and the band an index falls
in.

## Quick start

```moonbit nocheck
///|
/// The sub-index for a concentration, given a breakpoint table.
let table = @moonaqi.pm25_24h()
let sub = @moonaqi.iaqi(table, 55.0)      // Some(75)

///|
/// And the band that index falls in.
let category = @moonaqi.AqiCategory::of(75)   // Good
```

## The interpolation

A breakpoint table is a list of rows, each mapping a concentration range onto
an index range. The sub-index for a concentration is where it falls inside the
row it lands in:

```
IAQI = (I_high - I_low) / (C_high - C_low) * (C - C_low) + I_low
```

rounding to the nearest integer, which is how an index is reported.

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

A concentration above the last row is reported as that row's index, so a value
off the end of a table cannot produce a sub-index the table has no room for. A
negative concentration is not a measurement, and gives `None`.

## Bands

The boundaries are the ones the Chinese standard draws:

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
