///|
/// A small report tool: takes six pollutant concentrations and prints the
/// index they add up to, the way a monitoring station publishes one.
///
/// ```
/// moon run cmd/main
/// moon run cmd/main -- --realtime
/// moon run cmd/main -- --pm25 150 --pm10 250
/// ```

///|
/// A non-negative decimal, or `None` when `text` is not one.
fn parse_decimal(text : StringView) -> Double? {
  if text.length() == 0 {
    return None
  }
  let mut value = 0.0
  let mut i = 0
  let mut whole_digits = 0
  while i < text.length() && text.at(i) >= '0' && text.at(i) <= '9' {
    value = value * 10.0 + (text.at(i).to_int() - '0'.to_int()).to_double()
    i += 1
    whole_digits += 1
  }
  if i >= text.length() {
    if whole_digits == 0 {
      return None
    }
    return Some(value)
  }
  if text.at(i) != '.' {
    return None
  }
  i += 1
  let mut scale = 0.1
  let mut fraction_digits = 0
  while i < text.length() && text.at(i) >= '0' && text.at(i) <= '9' {
    value = value + (text.at(i).to_int() - '0'.to_int()).to_double() * scale
    scale = scale * 0.1
    i += 1
    fraction_digits += 1
  }
  if i != text.length() || (whole_digits == 0 && fraction_digits == 0) {
    return None
  }
  Some(value)
}

///|
/// `text` padded on the right to `width`, so a column of them lines up.
fn pad_right(text : String, width : Int) -> String {
  let mut out = text
  while out.length() < width {
    out = out + " "
  }
  out
}

///|
/// The pollutant a flag names, or `None` when the flag is not one of the six.
fn pollutant_of(flag : StringView) -> @moonaqi.Pollutant? {
  let name = flag.to_owned()
  if name == "--pm25" {
    Some(@moonaqi.Pm25)
  } else if name == "--pm10" {
    Some(@moonaqi.Pm10)
  } else if name == "--so2" {
    Some(@moonaqi.So2)
  } else if name == "--no2" {
    Some(@moonaqi.No2)
  } else if name == "--co" {
    Some(@moonaqi.Co)
  } else if name == "--o3" {
    Some(@moonaqi.O3)
  } else {
    None
  }
}

///|
/// The default readings: a moderately polluted winter day.
fn default_concentrations() -> Array[(@moonaqi.Pollutant, Double)] {
  [
    (@moonaqi.Pm25, 115.0),
    (@moonaqi.Pm10, 120.0),
    (@moonaqi.So2, 50.0),
    (@moonaqi.No2, 40.0),
    (@moonaqi.Co, 4.0),
    (@moonaqi.O3, 160.0),
  ]
}

///|
/// Replace the concentration of `pollutant`.
fn set_concentration(
  concentrations : Array[(@moonaqi.Pollutant, Double)],
  pollutant : @moonaqi.Pollutant,
  value : Double,
) -> Unit {
  for i = 0; i < concentrations.length(); i = i + 1 {
    if concentrations[i].0 == pollutant {
      concentrations[i] = (pollutant, value)
    }
  }
}

///|
/// The report's readings, with any `--name value` overrides applied, or
/// `None` when an argument is not understood.
fn readings_from(
  args : Array[String],
  report : @moonaqi.Report,
) -> Array[@moonaqi.Reading]? {
  let concentrations = default_concentrations()
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match pollutant_of(arg) {
      Some(pollutant) => {
        if i + 1 >= args.length() {
          return None
        }
        match parse_decimal(args[i + 1]) {
          Some(value) => {
            set_concentration(concentrations, pollutant, value)
            i += 2
          }
          None => return None
        }
      }
      None => if arg == "--realtime" { i += 1 } else { return None }
    }
  }
  let readings : Array[@moonaqi.Reading] = []
  for entry in concentrations {
    readings.push(@moonaqi.Reading::of(entry.0, report, entry.1))
  }
  Some(readings)
}

///|
/// Whether the arguments ask for the real-time report.
fn wants_realtime(args : Array[String]) -> Bool {
  for arg in args {
    if arg == "--realtime" {
      return true
    }
  }
  false
}

///|
/// Whether the arguments ask for the usage.
fn wants_help(args : Array[String]) -> Bool {
  for arg in args {
    if arg == "--help" {
      return true
    }
  }
  false
}

///|
/// The pollutants as a comma-separated list.
fn names_of(pollutants : Array[@moonaqi.Pollutant]) -> String {
  let out = StringBuilder(size_hint=16)
  let mut first = true
  for pollutant in pollutants {
    if !first {
      out.write_string(", ")
    }
    out.write_string(pollutant.name())
    first = false
  }
  out.to_string()
}

///|
fn usage() -> Unit {
  println("moonaqi — the air quality index from six pollutant concentrations")
  println("")
  println("  moon run cmd/main [--realtime] [--pm25 N] [--pm10 N] [--so2 N]")
  println("                    [--no2 N] [--co N] [--o3 N]")
  println("")
  println("  PM2.5, PM10, SO2, NO2 and O3 are ug/m3; CO is mg/m3.")
  println("  Without --realtime the readings are read as a daily report.")
}

///|
fn main {
  // The first argument is the program itself.
  let argv = @env.args()
  let args : Array[String] = []
  for i = 1; i < argv.length(); i = i + 1 {
    args.push(argv[i])
  }
  if wants_help(args) {
    usage()
    return
  }
  let report = if wants_realtime(args) {
    @moonaqi.RealTime
  } else {
    @moonaqi.Daily
  }
  let readings = match readings_from(args, report) {
    Some(readings) => readings
    None => {
      usage()
      return
    }
  }
  let air = match @moonaqi.aqi(readings) {
    Some(air) => air
    None => {
      println("no usable readings")
      return
    }
  }
  println(
    if report is @moonaqi.Daily {
      "daily report (日报)"
    } else {
      "real-time report (实时报)"
    },
  )
  println("")
  println(
    "  " + pad_right("pollutant", 11) + pad_right("concentration", 16) + "IAQI",
  )
  for entry in air.sub_indices() {
    let pollutant = entry.0
    let mut value = 0.0
    for reading in readings {
      if reading.pollutant() == pollutant {
        value = reading.concentration()
      }
    }
    println(
      "  " +
      pad_right(pollutant.name(), 11) +
      pad_right("\{value} \{pollutant.unit()}", 16) +
      entry.1.to_string(),
    )
  }
  println("")
  println(
    "  AQI \{air.index()}   \{air.category().name()} / \{air.category().chinese_name()}",
  )
  if air.dominant().length() > 0 {
    println("  primary pollutant   \{names_of(air.dominant())}")
  }
  if air.non_attainment().length() > 0 {
    println("  over the limit      \{names_of(air.non_attainment())}")
  }
}
