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
fn pad_right(text : String, width : Int32) -> String {
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
      None =>
        if arg == "--realtime" || arg == "--json" {
          i += 1
        } else {
          return None
        }
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
/// Whether the arguments ask for JSON.
fn wants_json(args : Array[String]) -> Bool {
  for arg in args {
    if arg == "--json" {
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
/// A whole number, or `None` when the text is not one.
fn whole_number(text : String) -> Int32? {
  match parse_decimal(text) {
    Some(value) =>
      if value < 0.0 || value != value.to_int().to_double() {
        None
      } else {
        Some(value.to_int())
      }
    None => None
  }
}

///|
/// The pollutant a name gives, as the tables spell it: `PM2.5`, `PM10`,
/// `SO2`, `NO2`, `CO` or `O3`.
fn pollutant_named(name : String) -> @moonaqi.Pollutant? {
  if name == "PM2.5" {
    Some(@moonaqi.Pm25)
  } else if name == "PM10" {
    Some(@moonaqi.Pm10)
  } else if name == "SO2" {
    Some(@moonaqi.So2)
  } else if name == "NO2" {
    Some(@moonaqi.No2)
  } else if name == "CO" {
    Some(@moonaqi.Co)
  } else if name == "O3" {
    Some(@moonaqi.O3)
  } else {
    None
  }
}

///|
/// A day's worth of hours for one pollutant, written on the command line.
///
/// Elements are separated by commas. An element is a concentration, or a
/// concentration and a repeat count joined by `x`, or nothing at all for an
/// hour with no reading:
///
///     PM2.5=35x24
///     O3=100x12,160x12
///     NO2=,40x23
fn parse_series(text : String) -> Array[Double?]? {
  let hours : Array[Double?] = []
  let view : StringView = text
  let mut at = 0
  while at <= view.length() {
    // The element runs to the next comma, or to the end.
    let mut end = at
    while end < view.length() && view.at(end) != ',' {
      end += 1
    }
    let element = view[at:end]
    if element.length() == 0 {
      hours.push(None)
    } else {
      // `value` or `value xN`.
      let mut split = element.length()
      for i = 0; i < element.length(); i = i + 1 {
        if element.at(i) == 'x' || element.at(i) == 'X' {
          split = i
          break
        }
      }
      let value_text = element[0:split]
      match parse_decimal(value_text) {
        Some(value) => {
          let count = if split >= element.length() {
            1
          } else {
            match whole_number(element[split + 1:element.length()].to_owned()) {
              Some(found) => found
              None => return None
            }
          }
          for i = 0; i < count; i = i + 1 {
            hours.push(Some(value))
          }
        }
        None => return None
      }
    }
    if end >= view.length() {
      break
    }
    at = end + 1
  }
  Some(hours)
}

///|
/// Whether the command line is feeding a day of hours rather than one set of
/// readings.
fn has_series(args : Array[String]) -> Bool {
  for arg in args {
    if arg == "--series" {
      return true
    }
  }
  false
}

///|
/// A day of hours from the command line, and what to report it under.
priv struct DayRequest {
  station : String
  series : Array[(@moonaqi.Pollutant, Array[Double?])]
  standard : @moonaqi.Standard
  daily_minimum : Int32
  ozone_minimum : Int32
}

///|
/// Read the day's arguments, or `None` when one of them is not understood.
fn day_request(args : Array[String]) -> DayRequest? {
  let series : Array[(@moonaqi.Pollutant, Array[Double?])] = []
  let mut station = "STATION"
  let mut standard = @moonaqi.China
  let mut daily_minimum = 20
  let mut ozone_minimum = 6
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    if argument == "--series" {
      if index + 1 >= args.length() {
        return None
      }
      let specification = args[index + 1]
      let equals = match index_of_char(specification, '=') {
        Some(found) => found
        None => return None
      }
      let spelling : StringView = specification
      let pollutant = match pollutant_named(spelling[0:equals].to_owned()) {
        Some(found) => found
        None => return None
      }
      let hours = match
        parse_series(spelling[equals + 1:spelling.length()].to_owned()) {
        Some(found) => found
        None => return None
      }
      series.push((pollutant, hours))
      index += 2
    } else if argument == "--station" {
      if index + 1 >= args.length() {
        return None
      }
      station = args[index + 1]
      index += 2
    } else if argument == "--standard" {
      if index + 1 >= args.length() {
        return None
      }
      standard = if args[index + 1] == "epa" {
        @moonaqi.Epa
      } else if args[index + 1] == "china" {
        @moonaqi.China
      } else if args[index + 1] == "china2012" {
        @moonaqi.China2012
      } else {
        return None
      }
      index += 2
    } else if argument == "--daily-min" {
      match following_whole(args, index) {
        Some(found) => {
          daily_minimum = found
          index += 2
        }
        None => return None
      }
    } else if argument == "--ozone-min" {
      match following_whole(args, index) {
        Some(found) => {
          ozone_minimum = found
          index += 2
        }
        None => return None
      }
    } else {
      return None
    }
  }
  if series.length() == 0 {
    return None
  }
  Some({ station, series, standard, daily_minimum, ozone_minimum, })
}

///|
fn following_whole(args : Array[String], index : Int32) -> Int32? {
  if index + 1 >= args.length() {
    None
  } else {
    whole_number(args[index + 1])
  }
}

///|
/// The index of the first `c` in `text`, or `None`.
fn index_of_char(text : String, c : Char) -> Int32? {
  let view : StringView = text
  for i = 0; i < view.length(); i = i + 1 {
    if view.at(i).to_int() == c.to_int() {
      return Some(i)
    }
  }
  None
}

///|
/// Report a day of hours.
fn run_day(request : DayRequest) -> Unit {
  let day = @moonaqi.Day::new(request.station)
  for entry in request.series {
    for value in entry.1 {
      day.record(entry.0, value)
    }
  }
  let rules = @moonaqi.DayRules::new(
    @moonaqi.Window::new(24, request.daily_minimum),
    @moonaqi.Window::new(8, request.ozone_minimum),
  )
  let air = match day.aqi(request.standard, rules) {
    Some(found) => found
    None => {
      println("no indicator survived the averaging rules")
      return
    }
  }
  println("")
  println("moonaqi — a day of hours, averaged and indexed")
  println("")
  println("  station   \{request.station}\{standard_text(request.standard)}")
  println(
    "  rules     a day over 24 hours with at least \{request.daily_minimum} reported, ozone over its highest 8 with at least \{request.ozone_minimum}",
  )
  println("")
  for hours in day.hours() {
    let pollutant = hours.pollutant()
    let rule = if pollutant is @moonaqi.O3 {
      "8-hour maximum"
    } else {
      "24-hour average"
    }
    let indicator = match pollutant {
      @moonaqi.O3 =>
        hours.maximum_rolling(@moonaqi.Window::new(8, request.ozone_minimum))
      _ => hours.mean(request.daily_minimum)
    }
    let reported = hours.values().length()
    let valid = hours.valid_between(0, reported - 1)
    // The unit is the one the chosen standard measures the pollutant in, so
    // that a concentration fed in the other standard's units is visibly wrong
    // rather than quietly indexed.
    let unit = match request.standard {
      @moonaqi.Epa => @moonaqi.epa_unit(pollutant)
      _ => pollutant.unit()
    }
    let text = match indicator {
      Some(value) => "\{value} \{unit}"
      None => "left out"
    }
    println(
      "  " +
      pad_right(pollutant.name(), 8) +
      pad_right("\{reported} hours, \{valid} reported", 24) +
      pad_right(rule, 18) +
      text,
    )
  }
  println("")
  println(
    "  AQI \{air.index()}   \{air.category().name()} / \{air.category().chinese_name()}" +
    "   \{air.category().colour_name()} / \{air.category().chinese_colour_name()}",
  )
  if air.dominant().length() > 0 {
    println("  primary pollutant   \{names_of(air.dominant())}")
  }
  if air.non_attainment().length() > 0 {
    println("  over the limit      \{names_of(air.non_attainment())}")
  }
}

///|
fn standard_text(standard : @moonaqi.Standard) -> String {
  match standard {
    @moonaqi.China => " (HJ 633—2026)"
    @moonaqi.China2012 => " (HJ 633—2012)"
    @moonaqi.Epa => " (US EPA)"
  }
}

///|
/// A list of names as a JSON array.
fn json_names(names : Array[String]) -> String {
  let out = StringBuilder(size_hint=32)
  out.write_string("[")
  for i = 0; i < names.length(); i = i + 1 {
    if i > 0 {
      out.write_string(", ")
    }
    out.write_string("\"" + names[i] + "\"")
  }
  out.write_string("]")
  out.to_string()
}

///|
/// The pollutants in `pollutants`, as a JSON array of names.
fn json_pollutant_names(pollutants : Array[@moonaqi.Pollutant]) -> String {
  let names : Array[String] = []
  for pollutant in pollutants {
    names.push(pollutant.name())
  }
  json_names(names)
}

///|
/// The report as JSON.
fn report_json(
  air : @moonaqi.AirQuality,
  readings : Array[@moonaqi.Reading],
  report : @moonaqi.Report,
) -> String {
  let out = StringBuilder(size_hint=512)
  out.write_string("{\n")
  out.write_string(
    "  \"report\": \"" +
    (if report is @moonaqi.Daily { "daily" } else { "realtime" }) +
    "\",\n",
  )
  out.write_string("  \"aqi\": \{air.index()},\n")
  out.write_string("  \"category\": \"\{air.category().name()}\",\n")
  out.write_string(
    "  \"chinese_category\": \"\{air.category().chinese_name()}\",\n",
  )
  out.write_string("  \"colour\": \"\{air.category().colour_name()}\",\n")
  let rgb = air.category().rgb()
  out.write_string(
    "  \"colour_rgb\": [\{rgb.red()}, \{rgb.green()}, \{rgb.blue()}],\n",
  )
  out.write_string("  \"readings\": [\n")
  let entries = air.sub_indices()
  for i = 0; i < entries.length(); i = i + 1 {
    let pollutant = entries[i].0
    let mut value = 0.0
    for reading in readings {
      if reading.pollutant() == pollutant {
        value = reading.concentration()
      }
    }
    out.write_string(
      "    {\"pollutant\": \"" +
      pollutant.name() +
      "\", \"concentration\": " +
      value.to_string() +
      ", \"unit\": \"" +
      pollutant.unit() +
      "\", \"iaqi\": " +
      entries[i].1.to_string() +
      "}",
    )
    if i + 1 < entries.length() {
      out.write_string(",")
    }
    out.write_string("\n")
  }
  out.write_string("  ],\n")
  out.write_string(
    "  \"primary_pollutants\": " + json_pollutant_names(air.dominant()) + ",\n",
  )
  out.write_string(
    "  \"non_attainment\": " + json_pollutant_names(air.non_attainment()) + "\n",
  )
  out.write_string("}")
  out.to_string()
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
  println("  moon run cmd/main [--realtime] [--json] [--pm25 N] [--pm10 N]")
  println("                    [--so2 N] [--no2 N] [--co N] [--o3 N]")
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
  if has_series(args) {
    match day_request(args) {
      Some(request) => run_day(request)
      None => {
        println("the day's arguments could not be read")
        println("")
        usage()
      }
    }
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
  if wants_json(args) {
    println(report_json(air, readings, report))
    return
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
    "  AQI \{air.index()}   \{air.category().name()} / \{air.category().chinese_name()}" +
    "   \{air.category().colour_name()} / \{air.category().chinese_colour_name()}",
  )
  if air.dominant().length() > 0 {
    println("  primary pollutant   \{names_of(air.dominant())}")
  }
  if air.non_attainment().length() > 0 {
    println("  over the limit      \{names_of(air.non_attainment())}")
  }
}
