///|
test "every band has the colour the standards give it" {
  inspect(AqiCategory::of(25).colour_name(), content="Green")
  inspect(AqiCategory::of(75).colour_name(), content="Yellow")
  inspect(AqiCategory::of(125).colour_name(), content="Orange")
  inspect(AqiCategory::of(175).colour_name(), content="Red")
  inspect(AqiCategory::of(250).colour_name(), content="Purple")
  inspect(AqiCategory::of(400).colour_name(), content="Maroon")
}

///|
test "the colours as the Chinese standard names them" {
  inspect(AqiCategory::of(25).chinese_colour_name(), content="绿色")
  inspect(AqiCategory::of(75).chinese_colour_name(), content="黄色")
  inspect(AqiCategory::of(125).chinese_colour_name(), content="橙色")
  inspect(AqiCategory::of(175).chinese_colour_name(), content="红色")
  inspect(AqiCategory::of(250).chinese_colour_name(), content="紫色")
  inspect(AqiCategory::of(400).chinese_colour_name(), content="褐红色")
}

///|
/// The RGB values are the ones in the EPA's table.
test "the rgb values" {
  @debug.debug_inspect(AqiCategory::of(25).rgb().green(), content="228")
  @debug.debug_inspect(AqiCategory::of(75).rgb().red(), content="255")
  @debug.debug_inspect(AqiCategory::of(75).rgb().blue(), content="0")
  @debug.debug_inspect(AqiCategory::of(125).rgb().green(), content="126")
  @debug.debug_inspect(AqiCategory::of(175).rgb().green(), content="0")
  @debug.debug_inspect(AqiCategory::of(250).rgb().red(), content="143")
  @debug.debug_inspect(AqiCategory::of(250).rgb().blue(), content="151")
  @debug.debug_inspect(AqiCategory::of(400).rgb().blue(), content="35")
}

///|
test "every band carries a colour" {
  for category in AqiCategory::all() {
    let rgb = category.rgb()
    @debug.debug_inspect(rgb.red() >= 0 && rgb.red() <= 255, content="true")
    @debug.debug_inspect(rgb.green() >= 0 && rgb.green() <= 255, content="true")
    @debug.debug_inspect(rgb.blue() >= 0 && rgb.blue() <= 255, content="true")
    @debug.debug_inspect(category.colour_name().length() > 0, content="true")
  }
}
