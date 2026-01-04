///|
struct DownloadResult {
  // 下载链接
  url : String
  // 保存的文件名
  file_name : String
  // 下载路径
  file_path : String
  // 是否下载成功
  success : Bool
  // 文件大小（字节）
  size : Double
  // 下载耗时（毫秒）
  time : UInt64
} derive(Show, Default)

///|
pub fn get_speed(size : Double, time : UInt64) -> Double {
  return @lib.round_to(size / time.to_double() * 1000)
}

///|
pub fn DownloadResult::get_speed(self : DownloadResult) -> Double {
  return get_speed(self.size, self.time)
}

///|
pub fn get_readable_speed_with_unit(speed : Double) -> String {
  if speed < 1024 {
    return "\{@lib.round_to(speed)} B/s"
  } else if speed < 1024 * 1024 {
    return "\{@lib.round_to(speed / 1024)} KB/s"
  } else {
    return "\{@lib.round_to(speed / 1024 / 1024)} MB/s"
  }
}

///|
pub fn DownloadResult::get_readable_speed_with_unit(
  self : DownloadResult,
) -> String {
  get_readable_speed_with_unit(self.get_speed())
}

///|
pub fn get_readable_size_with_unit(size : Double) -> String {
  if size < 1024 {
    return "\{@lib.round_to(size)} B"
  } else if size < 1024 * 1024 {
    return "\{@lib.round_to(size / 1024)} KB"
  } else if size < 1024 * 1024 * 1024 {
    return "\{@lib.round_to(size / 1024 / 1024)} MB"
  } else {
    return "\{@lib.round_to(size / 1024 / 1024 / 1024)} GB"
  }
}

///|
pub fn DownloadResult::get_readable_size_with_unit(
  self : DownloadResult,
) -> String {
  get_readable_size_with_unit(self.size)
}

///|
pub fn get_readable_time_array_with_unit(
  time_mill_seconds : Double,
) -> Array[String] {
  let time = time_mill_seconds / 1000.0
  let result = []
  if time >= 3600 {
    let hours = (time / 3600).floor()
    result.push("\{hours} 小时")
    let left = time - hours * 3600
    if left > 0 {
      @lib.push_all(result, get_readable_time_array_with_unit(left * 1000))
    }
  } else if time >= 60 {
    let minutes = (time / 60).floor()
    result.push("\{minutes} 分钟")
    let left = time - minutes * 60
    if left > 0 {
      @lib.push_all(result, get_readable_time_array_with_unit(left * 1000))
    }
  } else {
    result.push("\{time.ceil()} 秒")
  }
  return result
}

///|
pub fn get_readable_time_with_unit(time_mill_seconds : Double) -> String {
  let parts = get_readable_time_array_with_unit(time_mill_seconds)
  return parts.join(" ")
}

///|
pub fn DownloadResult::get_readable_time_with_unit(
  self : DownloadResult,
) -> String {
  get_readable_time_with_unit(self.time.to_double())
}
