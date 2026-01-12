///|
#borrow(text)
extern "c" fn console_overwrite(text : Bytes) -> Unit = "console_overwrite"

///|
extern "c" fn console_clear_line() -> Unit = "console_clear_line"

///|
extern "C" fn setup_signal_handler(sig : Int) -> Unit = "setup_signal_handler"

///|
extern "C" fn is_interrupted(sig : Int) -> Int = "is_interrupted"

///|
extern "C" fn clear_signal(sig : Int) -> Unit = "is_interrupted"

///|
#borrow(from_path, to_path)
extern "C" fn c_rename_file(from_path : Bytes, to_path : Bytes) -> Int = "rename_file"

///|
pub fn overwrite_line(text : String) -> Unit {
  console_overwrite(@encoding/utf8.encode(text))
}

// ===== Unix signal 常量 =====
// （Windows 下只是占位）

///|
/// 用户中断（Ctrl+C）
const SIGINT : Int = 2

///|
/// 请求程序“正常退出”
const SIGTERM : Int = 15

///|
/// 强制退出 + 生成 core dump
const SIGQUIT : Int = 3

///|
pub(all) enum Signal {
  CTRL_C
  NORMAL_EXIT
  QUIT
}

///|
pub async fn wait_signal(signal : Signal) -> Unit {
  let signal = match signal {
    CTRL_C => SIGINT
    NORMAL_EXIT => SIGTERM
    QUIT => SIGQUIT
  }
  setup_signal_handler(signal)
  while true {
    if is_interrupted(signal) != 0 {
      let signal = yellow(signal)
      println("\n结束，信号值：\{signal}")
      break
    }
    @async.pause()
  }
  clear_signal(signal)
}

// ========== C 指针类型 ==========

///|
priv struct HuffTable {
  sym : FixedArray[UInt16]
  len : FixedArray[UInt]
}

///|
priv struct GzipDecoder {
  input : Bytes
  // input
  in_len : Int64
  in_pos : Int64

  //  bitstream
  bitbuf : UInt
  bitcnt : Int

  //  window
  window : Bytes
  win_pos : UInt64

  //  huffman
  ll : HuffTable
  dd : HuffTable

  //  state 
  header_done : Int
  finished : Int
  last_block : Int
}

// ========== C 回调类型 ==========

///|
type OutputCallback = FuncRef[(UserData, Bytes, UInt64) -> Unit]

// ========== extern C ==========

///|
extern "C" fn gzip_decoder_new() -> GzipDecoder = "gzip_decoder_new"

///|
#owned(d)
extern "C" fn gzip_decoder_free(d : GzipDecoder) = "gzip_decoder_free"

///|
type UserData = @buffer.Buffer

///|
#borrow(data, userdata)
#owned(d)
extern "C" fn gzip_decoder_push(
  d : GzipDecoder,
  data : Bytes,
  len : Int,
  out : OutputCallback,
  userdata : UserData,
) -> Int = "gzip_decoder_push"
