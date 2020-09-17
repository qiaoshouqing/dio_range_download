import '../lib/dio_range_download.dart';

main() async {
  print("hello world");
  rangeDownload();
}

DateTime startTime;
rangeDownload() async {
  print("start");
  bool isStarted = false;
  var url =
      "http://music.163.com/song/media/outer/url?id=1357233444.mp3";
  var savePath = "download_result/music.mp3";
  await RangeDownload.downloadWithChunks(url, savePath,
      onReceiveProgress: (received, total) {
    if (!isStarted) {
      startTime = DateTime.now();
      isStarted = true;
    }
    if (total != -1) {
      print("${(received / total * 100).floor()}%");
    }
    if ((received / total * 100).floor() >= 100) {
      var duration = (DateTime.now().millisecondsSinceEpoch -
              startTime.millisecondsSinceEpoch) /
          1000;
      print(duration.toString() + "s");
      print(
          (duration ~/ 60).toString() + "m" + (duration % 60).toString() + "s");
    }
  });
}
