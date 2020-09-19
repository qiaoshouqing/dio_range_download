# 我写了一个断点续传下载的flutter pub库

## 背景

一个大文件如果不支持断点续传，那么当下载过程中被打断了，下次还需要从头开始下载是一件很令人头疼的事情。那么这个断点续传的库就应运而生了。

在flutter pub.dev库上搜索了一番发现以前没有这样的库，那么这件事就由我来做好了。

## 原理

众所周知，http1.1版本中header添加了range头，对于同一个文件可以支持分段请求，每次请求其中一部分资源。

利用这个原理做两件事情。

- 分段请求：将一个文件分成多块使用多线程去分别请求，最后再合并起来。
- 断点续传：对于的大文件下载过程记住当前下载到了文件的某一个位置，如果下载被打断了，还可以在之前下载完的位置继续请求。

[断点续传库](https://pub.dev/packages/dio_range_download)则根据这个原理支持一下分段请求和断点续传。具体来说是先支持分段请求，然后在分段请求的基础上支持一下断点续传。

### 附加思考：多线程分段下载真的可以提高下载速度吗？

不一定。

1. 如果只有一个数据源则不能，流量出口速度必然是恒定的。
2. 如果有多个数据源理论上可以提高下载速度。
3. 如果我们设备的带宽低于数据源的带宽，则可能会受限于设备带宽。
4. 如果多个数据源的带宽差距较大，多线程下载速度也不一定会优于单线程下载。

综上、具体的下载速度会受限于数据源数量、数据源带宽、设备带宽、每个块的大小、分块的数量等。

## 使用

使用起来很简单，只需要传入下载地址，保存地址就可以了。可选参数有分块数量、dio实例（用于设置特殊参数）。

```dart
import 'package:dio_range_download/dio_range_download.dart';

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
      // maxChunk: 6,
      // dio: Dio(),//Optional parameters "dio".Convenient to customize request settings.
      onReceiveProgress: (received, total) {
    if (total != -1) {
      print("${(received / total * 100).floor()}%");
    }
  });
}
```



## 具体编写

目前dio这个网络库比较火，支持的功能比较完善，所以断点续传功能我是基于这个库来完成的。

### 下载

首先是关键的断点续传代码，主要是根据传入的开始和结束节点给到range参数，进行下载。

其中为了支持断点续传，判断了目标文件是否已存在，如果已存在则说明是上次中断了的请求已下载的部分，这里将中断了的请求文件保存下来以备下载完成之后进行合并，并修改一下要下载文件的开始位置，在原来的基础上继续下载。

当然如果你的下载过程连续断了两次，这里会先检查一下是不是不仅有上次断掉的，还有上上次断掉的记录，会将上两次断掉的先进行一次合并，再继续下载。

```dart
    Future<Response> downloadChunk(url, start, end, no, {isMerge = true}) async {
      int initLength = 0;
      --end;
      var path = savePath + "temp$no";
      File targetFile = File(path);
      if(await targetFile.exists() && isMerge) {
        print("good job start:${start} length:${File(path).lengthSync()}");
        if(start + await targetFile.length() < end) {
          initLength = await targetFile.length();
          start += initLength;
          var preFile = File(path + "_pre");
          if(await preFile.exists()) {
            mergeFiles(preFile, targetFile, preFile);
          } else {
            await targetFile.rename(preFile.path);
          }
        } else {
          await targetFile.delete();
        }
      }
      progress.add(initLength);
      progressInit.add(initLength);
      return dio.download(
        url,
        path,
        onReceiveProgress: createCallback(no),
        options: Options(
          headers: {"range": "bytes=$start-$end"},
        ),
      );
    }
```

### 下载进度回调

对于下载一个大文件，需要一个下载进度的回调，以便得知当前的进度状态。对于单文件下载比较简单，但是对于分段下载，需要将各个文件的进度汇总在一起。

这里借用了一个长度为分段数量的数组，每次计算最终大小的时候，将数组里面的所有进度汇总起来返回给使用者。

```dart
    createCallback(no) {
      return (int received, rangeTotal) async {
        if(received >= rangeTotal) {
          var path = savePath + "temp${no}";
          var oldPath = savePath + "temp${no}_pre";
          File oldFile = File(oldPath);
          if(oldFile.existsSync()) {
            await mergeFiles(oldPath, path, path);
          }
        }
        progress[no] = progressInit[no] + received;
        if (onReceiveProgress != null && total != 0) {
          onReceiveProgress(progress.reduce((a, b) => a + b), total);
        }
      };
    }
```

### 文件合并

在分段下载、断点续传结束的时候都需要将文件拼接起来。我们这里主要分两种情况，将多个文件按顺序拼接起来，将两个文件按顺序拼接起来，逻辑都差不多，为了方便这里给分成两段代码。

```dart
    Future mergeTempFiles(chunk) async {
      File f = File(savePath + "temp0");
      IOSink ioSink= f.openWrite(mode: FileMode.writeOnlyAppend);
      for (int i = 1; i < chunk; ++i) {
        File _f = File(savePath + "temp$i");
        await ioSink.addStream(_f.openRead());
        await _f.delete();
      }
      await ioSink.close();
      await f.rename(savePath);
    }

    Future mergeFiles(file1, file2, targetFile) async {
      File f1 = File(file1);
      File f2 = File(file2);
      IOSink ioSink= f1.openWrite(mode: FileMode.writeOnlyAppend);
      await ioSink.addStream(f2.openRead());
      await f2.delete();
      await ioSink.close();
      await f1.rename(targetFile);
    }
```

### 整体流程

整体流程首先请求一小块内容，检测是否支持断点续传，如果支持则根据分段数量机型拆分并启动分段请求，请求结束之后进行文件合并。

```dart
Response response = await downloadChunk(url, 0, firstChunkSize, 0, isMerge: false);
    if (response.statusCode == 206) {
      print("This http protocol support range download");
      total = int.parse(
          response.headers.value(HttpHeaders.contentRangeHeader).split("/").last);
      int reserved = total -
          int.parse(response.headers.value(HttpHeaders.contentLengthHeader));
      int chunk = (reserved / firstChunkSize).ceil() + 1;
      if (chunk > 1) {
        int chunkSize = firstChunkSize;
        if (chunk > maxChunk + 1) {
          chunk = maxChunk + 1;
          chunkSize = (reserved / maxChunk).ceil();
        }
        var futures = <Future>[];
        for (int i = 0; i < maxChunk; ++i) {
          int start = firstChunkSize + i * chunkSize;
          int end;
          if(i == maxChunk - 1) {
            end = total;
          } else {
            end = start + chunkSize;
          }
          futures.add(downloadChunk(url, start, end, i + 1));
        }
        await Future.wait(futures);
      }
      await mergeTempFiles(chunk);
    } else {
      print("This http protocol don't support range download");
    }
```

代码已开源到github，并可能会不断改动，具体代码可以直接前往github：https://github.com/qiaoshouqing/dio_range_download 阅读观看，并欢迎Star。

断点续传库的地址是：https://pub.dev/packages/dio_range_download ，欢迎使用，欢迎like。

如何上传到pub.dev就暂且不说了，步骤很简单，最大的困难是KXSW。

## 参考文章

- https://book.flutterchina.club/chapter11/download_with_chunks.html

- https://blog.csdn.net/qin19930929/article/details/94628973
