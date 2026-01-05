///|
async fn get(url : String, file_name : String?) -> DownloadResult {
  println("开始下载: \{url}")
  let (res, client) = @http.get_stream(url)
  defer client.close()
  match res.code {
    200 => download(url, file_name, res, client)
    301 | 302 => redirect(url, file_name, res, client)
    _ => {
      println("下载失败: HTTP 状态码 \{res.code}")
      DownloadResult::default(url, file_name)
    }
  }
}

///|
async fn redirect(
  url : String,
  file_name : String?,
  res : @http.Response,
  client : @http.Client,
) -> DownloadResult {
  let location = @lib.get_from_map_ignore_case(res.headers, "Location")
  if location is Some(location) {
    println("重定向到: \{location}")
    // 关闭当前客户端
    client.close()
    // 递归调用 get 函数
    get(location, file_name)
  } else {
    println("重定向失败: 未找到 Location 头")
    DownloadResult::default(url, file_name)
  }
}

///|
async fn download(
  url : String,
  file_name : String?,
  res : @http.Response,
  client : @http.Client,
) -> DownloadResult {
  @lib.overwrite_line("响应状态码: 200 OK")
  let size = if @lib.get_from_map_ignore_case(res.headers, "Content-Length")
    is Some(length) {
    @strconv.parse_double(length) catch {
      _ => 0
    }
  } else {
    0
  }
  @lib.overwrite_line("文件大小: \{size} 字节")
  let file_name = if file_name is Some(file_name) {
    file_name
  } else {
    @lib.get_file_name(url, res.headers)
  }
  // 基于当前运行目录，生成文件路径
  guard @env.current_dir() is Some(dir) else {
    abort("无法获取当前运行目录")
  }
  // let file_path = @fs.realpath("\{dir}/\{file_name}") // 有bug，会一直卡住
  let mut file_path = "\{dir}/\{file_name}"
  let mut index = 0
  // 如果文件已经存在，则添加序号
  let file_path = while @fs.exists(file_path) {
    index += 1
    let file_path_arr = file_name.split(".").collect()
    let add_index = "(\{index})"
    if file_path_arr.length() > 1 {
      file_path_arr.insert(file_path_arr.length() - 1, add_index)
    } else {
      file_path_arr.push(add_index)
    }
    file_path = file_path_arr.join(".")
  } else {
    file_path
  }
  @lib.overwrite_line("保存到文件: \{file_path}")
  let file = @fs.open(file_path, mode=@fs.Mode::WriteOnly, create=0o640)
  // 获取最新文件名用于显示
  let file_name = file_path.split("/").collect().last().unwrap().to_string()
  defer file.close()
  let size_MB = @lib.round_to(size / 1024 / 1024)
  let start_time = @env.now()
  // 每次读取 1024KB
  let chunk_size = 1024 * 1024
  let mut prev_time = start_time
  let mut prev_size = 0L
  while true {
    if client.read_some(max_len=chunk_size) is Some(chunk) {
      file.write(chunk)
      let now = @env.now()
      // 耗时（秒）
      let spend_time = now - prev_time
      // 有可能下载速度很快，导致耗时为0
      if spend_time == 0 {
        continue
      }
      let download_size = file.size() - prev_size
      // println("下载了 \{download_size} 字节, 耗时 \{spend_time} ms")
      // 计算下载速度 (B/s)
      let speed = get_speed(download_size.to_double(), spend_time)
      let readable_speed = get_readable_speed_with_unit(speed)
      // 此次下载大小
      let current_size_MB = @lib.round_to(file.size().to_double() / 1024 / 1024)
      // 剩余时间
      let remaining_time = if size > 0 && speed > 0 {
        ((size - file.size().to_double()) / speed * 1000).ceil()
      } else {
        0
      }
      let remaining_time_str = if remaining_time > 0 {
        get_readable_time_with_unit(remaining_time)
      } else {
        "未知"
      }
      // 打印实时下载进度
      @lib.overwrite_line(
        "下载中: \{file_name}, \{@lib.round_to(current_size_MB)}MB / \{size_MB}MB, 速度: \{readable_speed}，剩余时间: \{remaining_time_str}",
      )
      prev_time = now
      prev_size = file.size()
    } else {
      break
    }
  }
  @lib.console_clear_line()
  // 计算平均下载速度
  let time = @cmp.maximum(@env.now() - start_time, 1)
  return DownloadResult::{
    url,
    file_name,
    file_path,
    success: true,
    size,
    time,
  }
}
