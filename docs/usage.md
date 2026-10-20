# 使用指南

moonaqi 计算空气质量指数。这份文档按"你手上有什么"来组织：

| 你手上有什么 | 用哪一层 |
| --- | --- |
| 六项污染物的浓度（已经算好的日均值） | [`aqi`](#只有浓度算指数) |
| 一天的逐小时原始数据 | [`Day`](#有逐小时数据算日报) |
| 多个站点的一天 | [`Day::merged`](#多站点聚合成城市) |
| 一段时间的指数 | [`Summary`](#一段时间的统计) |
| 只想查一张断点表 | [`hj633_2026`](#只查断点表) |

---

## 安装

```sh
moon add mwqcodex/moonaqi
```

在 `moon.pkg` 里引入：

```moonbit nocheck
import {
  "mwqcodex/moonaqi",
}
```

---

## 只有浓度：算指数

六项浓度已经算好时，直接合成：

```moonbit nocheck
///|
let readings = [
  @moonaqi.Reading::of(@moonaqi.Pm25, @moonaqi.Daily, 115.0),
  @moonaqi.Reading::of(@moonaqi.Pm10, @moonaqi.Daily, 120.0),
  @moonaqi.Reading::of(@moonaqi.So2, @moonaqi.Daily, 50.0),
  @moonaqi.Reading::of(@moonaqi.No2, @moonaqi.Daily, 40.0),
  @moonaqi.Reading::of(@moonaqi.Co, @moonaqi.Daily, 4.0),
  @moonaqi.Reading::of(@moonaqi.O3, @moonaqi.Daily, 160.0),
]

///|
match @moonaqi.aqi(readings) {
  Some(air) => {
    println(air.index())              // 150
    println(air.category().name())    // "Lightly polluted"
    println(air.category().chinese_name()) // "轻度污染"
    println(air.dominant())           // [Pm25]
    println(air.non_attainment())     // [Pm25]
  }
  None => println("没有可用读数")
}
```

`Reading::of` 的第二个参数是**报告类型**（`Daily` / `RealTime`），它决定了用哪一根断点柱：

| 污染物 | 日报 | 实时报 |
| --- | --- | --- |
| PM2.5 / PM10 | 日均列 | **日均列**（标准没有 1 小时限值） |
| O₃ | **最大 8 小时列** | 1 小时列 |
| SO₂ / NO₂ / CO | 日均列 | 1 小时列 |

传 `Report` 而不是自己传窗口，就是为了不让这三条例外被写错。

---

## 有逐小时数据：算日报

监测站按小时报浓度。中间那步——把小时平均成日报指标——由 `Day` 做：

```moonbit nocheck
///|
let day = @moonaqi.Day::new("STATION")

///|
// 每小时把所有污染物都记录一次，保证各序列对齐。
for hour = 0; hour < 24; hour = hour + 1 {
  day.record(@moonaqi.Pm25, Some(35.0))
  day.record(@moonaqi.No2, Some(40.0))
  // 某一小时没有读数就记 None，不要记 0。
  day.record(@moonaqi.O3, Some(if hour < 12 { 100.0 } else { 160.0 }))
}

///|
let rules = @moonaqi.DayRules::new(
  @moonaqi.Window::new(24, 20), // 日均：24 小时里至少 20 小时有读数
  @moonaqi.Window::new(8, 6),   // 臭氧：8 小时里至少 6 小时有读数
)

///|
match day.aqi(@moonaqi.China, rules) {
  Some(air) => println(air.index())
  None => println("没有指标通过平均规则")
}
```

### 三条必须知道的规则

**① 缺测不是 0。** 平均只按**有读数的那些小时**算。监测仪停机的那一小时不是"干净的一小时"。

> 23 个有效小时 + 1 个缺测、值全是 35 的一天，日均是 **35**，不是 33.5。

**② 臭氧取当日最高的 8 小时滑动平均**，不是整日平均。

> 12 小时 100 + 12 小时 160 的一天：整日平均 130，最高 8 小时 **160**。两者在标准下分指数不同。

**③ 有效小时数不够时，该指标被剔除**，报告里不会出现它 —— 这正是标准所说的"缺项指标"。

### 最小有效小时数为什么是参数

因为**不是全世界的都一样**。中国和美国各自设定，而且都修订过。库不替你决定，由你按所报的权威口径传入。

---

## 多站点聚合成城市

```moonbit nocheck
///|
let city = @moonaqi.Day::merged("CITY", [day_a, day_b])

///|
city.aqi(@moonaqi.China, rules)
```

聚合方式是**逐小时取当小时有上报的站点的平均**。停报的站点不会把城市的小时拉向 0。

> 两站一天，其中一站前 12 小时停报：城市那一天是 **37.5**；若把停报当 0 会得 28.75。

---

## 一段时间的统计

```moonbit nocheck
///|
let summary = @moonaqi.Summary::new()

///|
for (station, day) in days {
  match day.aqi(@moonaqi.China, rules) {
    Some(air) => summary.add(station, air)
    None => ()
  }
}

///|
summary.days()                 // 统计了几天
summary.good_days()            // 指数 ≤ 100 的天数
summary.good_rate()            // 占比
summary.heavy_days()           // 指数 > 200 的天数
summary.average_index()        // 平均指数
summary.worst_index()          // 最差的一天
summary.worst_station()        // 来自哪个站
summary.most_frequent_primary()// 最常出现的首要污染物
```

---

## 切换标准

同一组读数可以按三套表算：

```moonbit nocheck
///|
let as_china   = @moonaqi.aqi_with(@moonaqi.China, readings)
let as_old     = @moonaqi.aqi_with(@moonaqi.China2012, readings)
let as_epa     = @moonaqi.aqi_with(@moonaqi.Epa, readings)
```

| | 中国 HJ 633—2026 | 中国 HJ 633—2012 | 美国 EPA |
| --- | --- | --- | --- |
| 取整 | 向上进位 | 向上进位 | 四舍五入 |
| 查表前 | 原值 | 原值 | 按污染物截断 |
| 单位 | µg/m³ / mg/m³ | 同左 | µg/m³ / ppm / ppb |

### ⚠️ 单位不是小事

中国标准里 CO 用 **mg/m³**，美国用 **ppm**；臭氧在美国用 **ppm** 而不是 µg/m³。

**喂错单位不会报错**，只会得到一个看起来正常的错值。做法是先确认单位，再查表：

```moonbit nocheck
///|
@moonaqi.epa_unit(@moonaqi.O3)   // "ppm"
@moonaqi.Pollutant::unit(@moonaqi.O3) // "ug/m3"，中国口径
```

---

## 只查断点表

```moonbit nocheck
///|
match @moonaqi.hj633_2026(@moonaqi.Pm25, @moonaqi.Daily) {
  Some(table) => {
    @moonaqi.iaqi(table, 60.0)              // Some(100)，中国规则
    @moonaqi.iaqi_with(table, 60.0, @moonaqi.Nearest) // 四舍五入
  }
  None => println("标准没有这一列")
}
```

标准没有的列返回 `None`（例如中国的 PM2.5 没有 1 小时列，美国的 PM2.5 没有 1 小时列）。

---

## 命令行

```sh
# 六项浓度
moon run cmd/main
moon run cmd/main -- --realtime
moon run cmd/main -- --json

# 一天的小时数据：值、值xN、空元素=缺测
moon run cmd/main -- --station STATION \
    --series PM2.5=35x24 --series NO2=,40x23 --series O3=100x12,160x12

# 换标准
moon run cmd/main -- --standard epa --series PM2.5=35x24
```

命令行会按所选标准打印单位，**喂错单位会显示成明显不合理的数值**。

---

## 常见问题

**Q: 为什么我的臭氧指标没出现？**
有效小时数不够。检查 `Window` 的第二个参数，以及序列里有多少 `Some`。

**Q: 为什么 AQI 比我手算的高？**
中国规则是**向上进位**：75.1 报 76。按四舍五入会少一档。

**Q: 为什么同一个浓度，日报和实时报结果差很多？**
两者用的是不同的断点柱。例如臭氧 160 µg/m³：日报的 8 小时列读 100，实时报的 1 小时列读 50。

**Q: 数据来源是什么？**
见 README 的 [Sources](../README.md#sources) 一节。

---

## 许可证

Apache-2.0。
