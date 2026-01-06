///|
async fn parse_url(url : String) -> Array[String] {
  guard @env.current_dir() is Some(dir) else { return [url] }
  let file_paths = ["\{dir}/config.json", "\{dir}/../../../../../config.json"]
  for file_path in file_paths {
    if @fs.exists(file_path) {
      println("找到配置文件：\{file_path}")
      let content = @fs.read_file(file_path).text()
      let json = @json.parse(content) catch {
        e => return fail("\{file_path}内容解析失败: \{e}")
      }
      if json is Object(obj) {
        println("配置文件内容：\{obj}")
        // 先进行精确匹配
        if obj.get(url) is Some(value) {
          return parse_urls(url, value) catch {
            e => {
              println(e)
              continue
            }
          }
        }
        // println("使用glob模式匹配")
        // 匹配不同，则通过glob匹配
        for key, value in obj {
          println("key为：\{key}, value为：\{value}")
          if @glob.glob(key, url) {
            // println("匹配到：\{key}: \{value}")
            return parse_urls(url, value)
          }
        }
        println("没有匹配到url映射")
      } else {
        return fail("配置文件\{file_path}的格式不对")
      }
    }
  }
  [url]
}

///|
fn parse_urls(origin_url : String, value : Json) -> Array[String] raise Failure {
  let urls = match value {
    // { "https:://xxx.com": "https://yyy.com" }
    String(url) => {
      if url.is_empty() {
        fail("不能配置空的映射")
      }
      [url]
    }
    // { "http://xxx.com": ["https://yyy.com", "https://zzz.com", "https://aaa.com"] }
    Array(urls) =>
      urls.map(url => {
        guard url is String(url) else { fail("不支持的格式：\{url}") }
        if url.is_empty() {
          fail("不能配置空的映射")
        }
        url
      })
    _ => fail("不支持的格式: \{value}")
  }
  return urls.map(url => url.replace_all(old="${url}", new=origin_url))
}

///|
async test "test_parse_url_no_matched" {
  inspect(
    parse_url("https://github.com"),
    content=(
      #|["https://github.com"]
    ),
  )
}

///|
async test "test_parse_url_with_machted" {
  @json.inspect(
    parse_url(
      "https://github.com/godotengine/godot/releases/download/4.5.1-stable/godot-4.5.1-stable.tar.xz",
    ),
    content=[
      "https://github.com/godotengine/godot/releases/download/4.5.1-stable/godot-4.5.1-stable.tar.xz",
      "https://gh-proxy.org/https://github.com/godotengine/godot/releases/download/4.5.1-stable/godot-4.5.1-stable.tar.xz",
      "https://hk.gh-proxy.org/https://github.com/godotengine/godot/releases/download/4.5.1-stable/godot-4.5.1-stable.tar.xz",
      "https://cdn.gh-proxy.org/https://github.com/godotengine/godot/releases/download/4.5.1-stable/godot-4.5.1-stable.tar.xz",
      "https://edgeone.gh-proxy.org/https://github.com/godotengine/godot/releases/download/4.5.1-stable/godot-4.5.1-stable.tar.xz",
    ],
  )
}

///|
test "glob" {
  assert_true(
    @glob.glob(
      "https://github.com/**/releases/**", "https://github.com/godotengine/godot/releases/download/4.5.1-stable/godot-4.5.1-stable.tar.xz",
    ),
  )
}
