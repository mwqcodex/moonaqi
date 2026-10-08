///|
/// The colour each band of the index is shown in.
///
/// Both standards use the same six colours for the six bands, and the RGB
/// values here are the ones the EPA's technical assistance document gives.
/// The Chinese standard names the colours rather than giving values.

///|
/// A colour, as its three channels.
pub struct Rgb {
  red : Int
  green : Int
  blue : Int
}

///|
pub fn Rgb::new(red : Int, green : Int, blue : Int) -> Rgb {
  { red, green, blue, }
}

///|
pub fn Rgb::red(self : Rgb) -> Int {
  self.red
}

///|
pub fn Rgb::green(self : Rgb) -> Int {
  self.green
}

///|
pub fn Rgb::blue(self : Rgb) -> Int {
  self.blue
}

///|
/// The colour the band is shown in.
pub fn AqiCategory::rgb(self : AqiCategory) -> Rgb {
  match self {
    Excellent => Rgb::new(0, 228, 0)
    Good => Rgb::new(255, 255, 0)
    LightlyPolluted => Rgb::new(255, 126, 0)
    ModeratelyPolluted => Rgb::new(255, 0, 0)
    HeavilyPolluted => Rgb::new(143, 63, 151)
    SeverelyPolluted => Rgb::new(126, 0, 35)
  }
}

///|
/// The colour's English name.
pub fn AqiCategory::colour_name(self : AqiCategory) -> String {
  match self {
    Excellent => "Green"
    Good => "Yellow"
    LightlyPolluted => "Orange"
    ModeratelyPolluted => "Red"
    HeavilyPolluted => "Purple"
    SeverelyPolluted => "Maroon"
  }
}

///|
/// The colour's name as the Chinese standard writes it.
pub fn AqiCategory::chinese_colour_name(self : AqiCategory) -> String {
  match self {
    Excellent => "绿色"
    Good => "黄色"
    LightlyPolluted => "橙色"
    ModeratelyPolluted => "红色"
    HeavilyPolluted => "紫色"
    SeverelyPolluted => "褐红色"
  }
}
