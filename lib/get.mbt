///|
pub async fn get(url : String, file_name : String?) -> DownloadResult? {
  println("开始下载: \{url}")
  let urls = parse_url(url)
  if urls.is_empty() {
    return fail("无效的链接")
  }
  get_fatest(urls, file_name)
}

///|
async fn get_fatest(
  urls : Array[String],
  file_name : String?,
) -> DownloadResult? {
  if urls.is_empty() {
    raise StringError("urls不能为空")
  }
  // 对urls去重
  let urls = if urls.length() > 1 {
    Set::from_array(urls).to_array()
  } else {
    urls
  }
  if urls.length() == 1 {
    return get_inner(urls[0], file_name, 0, None)
  }
  let url_text = urls.join("\n  ")
  println("获取最快的链接：\n  \{url_text}")
  let tasks = urls.map(url => async fn(id, task_status) {
    get_inner(url, file_name, id, Some(task_status))
  })
  pick_fatest(
    async fn(task_status) {
      @async.sleep(2000)
      overwrite_line("开始检查哪个链接下载速度更快")
      task_status.start_check()
    },
    FixedArray::from_array(tasks),
  )
}

///|
async fn get_inner(
  url : String,
  file_name : String?,
  id : Int,
  task_status : TaskStatus?,
) -> DownloadResult? {
  let p = yellow("开始")
  println("\{p} \{url}")
  // 从url取出host
  guard url.split("://").collect().get(1) is Some(urlWithoutProtocol) else {
    return None
  }
  let host = urlWithoutProtocol.split("/").collect()[0].to_string()
  // FIXME 下载github链接时，会报500
  let (res, client) = @http.get_stream(url, headers={
    "host": host,
    "User-Agent": "Mozilla/5.0",
    "Accept": "*/*",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
  })
  defer client.close()
  match res.code {
    200 => download(url, file_name, res, client, id, task_status)
    301 | 302 => redirect(file_name, res, id, task_status)
    _ => {
      let code = red(res.code)
      let reason = red(res.reason)
      println(
        "下载 \{url} 失败: HTTP 状态码 \{code}，错误信息 \{reason}",
      )
      None
    }
  }
}

///|
async fn redirect(
  file_name : String?,
  res : @http.Response,
  id : Int,
  task_status : TaskStatus?,
) -> DownloadResult? {
  let location = get_from_map_ignore_case(res.headers, "Location")
  if location is Some(location) {
    println("重定向到: \{location}")
    // 递归调用 get 函数
    get_inner(location, file_name, id, task_status)
  } else {
    println("重定向失败: 未找到 Location 头")
    None
  }
}

///|
const FLE_TMP_SUFFIX = ".tmp"

///|
async fn download(
  url : String,
  file_name : String?,
  res : @http.Response,
  client : @http.Client,
  id : Int,
  task_status : TaskStatus?,
) -> DownloadResult? {
  fn is_only_running() {
    guard task_status is Some(task_status) else { true }
    task_status.only_current_running(id)
  }

  let print_stacks = []
  fn print_when_only_running(text : String) {
    if is_only_running() {
      while print_stacks.pop() is Some(text) {
        overwrite_line(text)
      }
      overwrite_line(text)
    } else {
      print_stacks.push(text)
    }
  }

  print_when_only_running("响应状态码: 200 OK")
  let size = if get_from_map_ignore_case(res.headers, "Content-Length")
    is Some(length) {
    @strconv.parse_double(length) catch {
      _ => 0
    }
  } else {
    0
  }
  print_when_only_running("文件大小: \{size} 字节")
  let file_name = if file_name is Some(file_name) {
    file_name
  } else {
    get_file_name(url, res.headers)
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
  print_when_only_running("保存到文件: \{file_path}")
  let dest_file_path = file_path
  // 将文件名加上.tmp，保存为临时文件，成功后改名为实际文件名
  let file_path = file_path + FLE_TMP_SUFFIX
  let file = @fs.open(file_path, mode=@fs.Mode::WriteOnly, create=0o640)
  // 获取最新文件名用于显示
  let file_name = file_path.split("/").collect().last().unwrap().to_string()
  defer file.close()
  let size_MB = round_to(size / 1024 / 1024)
  let start_time = @env.now()
  let mut prev_time = start_time
  let mut prev_size = 0L
  print_when_only_running("任务 \{id} : \{url} 开始下载...")
  race([
    // 写入内容导文件
    async fn() {
      file.write_reader(client) catch {
        _ => {
          println("中断文件写入，删除临时文件 \{file_path}")
          @fs.remove(file_path)
          return None
        }
      }
      // 判断是否为gzip文件
      let need_rename = if is_gzip_file(file_path) {
        print_when_only_running(
          "文件 \{file_path} 是gzip文件，需要解码",
        )
        let success = gzip_decode(
          file_path,
          dest_file_path,
          retain_src_file=false,
        )
        if success {
          false
        } else {
          // 解码失败
          println(red("gzip解码失败"))
          true
        }
      } else {
        true
      }
      // 最终的文件路径
      let file_path = if need_rename {
        // 重命名
        let success = renmae_file(file_path, dest_file_path)
        if success {
          dest_file_path
        } else {
          println(red("重命名失败"))
          file_path
        }
      } else {
        dest_file_path
      }
      console_clear_line()
      // 计算下载时间
      let time = @cmp.maximum(@env.now() - start_time, 1)
      Some(DownloadResult::{ url, file_name, file_path, size, time })
    },
    // 判断任务是否要终止
    get_async_infinite_loop(async fn() {
      if task_status is Some(task_status) && !task_status.is_continue(id) {
        println("任务 \{id} : \{url} 收到停止信号，终止执行")
        // 删除文件
        @fs.remove(file_path)
        return (false, None)
      }
      (true, None)
    }),
    // 打印实时速度
    get_async_infinite_loop(async fn() {
      let now = @env.now()
      // 耗时（秒）
      let spend_time = now - prev_time
      // 有可能下载速度很快，导致耗时为0
      if spend_time == 0 {
        return (true, None)
      }
      let download_size = file.size() - prev_size
      // println("下载了 \{download_size} 字节, 耗时 \{spend_time} ms")
      // 计算下载速度 (B/s)
      let speed = get_speed(download_size.to_double(), spend_time)
      let readable_speed = get_readable_speed_with_unit(speed)
      // 此次下载大小
      let current_size = file.size()
      let current_size_MB = round_to(current_size.to_double() / 1024 / 1024)
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
      print_when_only_running(
        "下载中: \{file_name}, \{round_to(current_size_MB)}MB / \{size_MB}MB, 速度: \{readable_speed}，剩余时间: \{remaining_time_str}",
      )
      prev_time = now
      prev_size = file.size()
      // 设置任务进度
      if task_status is Some(task_status) {
        task_status.set(id, current_size)
      }
      (true, None)
    }),
  ])
}
