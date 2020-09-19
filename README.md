# dio_range_download

A download tool library that supports resumable downloading and segmented downloading.
https://pub.dev/packages/dio_range_download

## Theory
This library is based on the range protocol header of the http1.1 version to achieve segmented download and resumable download.
```
headers: {"range": "bytes=$start-$end"},
```

## Demo
```
import 'package:dio/dio.dart';
import 'package:dio_range_download/dio_range_download.dart';

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
  Response res = await RangeDownload.downloadWithChunks(url, savePath,
      //isRangeDownload: false,//Support normal download
      // maxChunk: 6,
      // dio: Dio(),//Optional parameters "dio".Convenient to customize request settings.
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
  print(res.statusCode);
  print(res.statusMessage);
  print(res.data);
}

```
