# dio_range_download

A download tool library that supports resumable downloading and segmented downloading.

## Theory
This library is based on the range protocol header of the http1.1 version to achieve segmented download and resumable download.
```
headers: {"range": "bytes=$start-$end"},
```

## Demo
```
import '../lib/dio_range_download.dart';

main() async {
  print("hello world");
  rangeDownload();
}

rangeDownload() async {
  print("start");
  bool isStarted = false;
  var url =
      "http://music.163.com/song/media/outer/url?id=1357233444.mp3";
  var savePath = "download_result/music.mp3";
  await RangeDownload.downloadWithChunks(url, savePath,
      onReceiveProgress: (received, total) {
    if (total != -1) {
      print("${(received / total * 100).floor()}%");
    }
  });
}

```