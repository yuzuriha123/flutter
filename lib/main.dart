import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Để load assets

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("SSL Pinning Demo")),
        body: const Center(child: SslPinningTest()),
      ),
    );
  }
}

class SslPinningTest extends StatefulWidget {
  const SslPinningTest({super.key});

  @override
  State<SslPinningTest> createState() => _SslPinningTestState();
}

class _SslPinningTestState extends State<SslPinningTest> {
  String _response = "Chưa gọi server";
  
  // 1. Cấu hình URL
  // Lưu ý: Nếu chạy máy ảo Android, localhost là 10.0.2.2
  // Nếu chạy máy thật, hãy dùng địa chỉ IP LAN của máy tính (VD: 192.168.1.x)
  final String _serverUrl = "https://172.20.10.7:8443/user"; 

  Future<void> fetchData() async {
    setState(() {
      _response = "Đang kết nối...";
    });

    try {
      // 2. Tạo instance Dio
      final dio = Dio();

      // 3. Load chứng chỉ từ Assets
      // Đảm bảo tên file khớp với pubspec.yaml
      final ByteData bytes = await rootBundle.load('assets/certs/server.crt');
      
      // 4. Cấu hình SSL Pinning trong HttpClientAdapter
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          // Tạo SecurityContext
          final SecurityContext clientContext = SecurityContext(withTrustedRoots: false);
          
          // Thêm chứng chỉ của bạn vào danh sách tin cậy
          clientContext.setTrustedCertificatesBytes(bytes.buffer.asUint8List());
          
          final HttpClient client = HttpClient(context: clientContext);
          
          // Kiểm tra lại lần nữa (Optional nhưng khuyên dùng)
          client.badCertificateCallback = (X509Certificate cert, String host, int port) {
            // Chỉ return true nếu bạn muốn bỏ qua lỗi bảo mật (KHÔNG NÊN dùng khi đã pinning)
            // Khi đã setTrustedCertificatesBytes, nếu cert khớp, callback này sẽ không được gọi (hoặc valid).
            // Nếu cert không khớp, nó sẽ quăng lỗi HandshakeException.
            return false; 
          };
          
          return client;
        },
      );

      // 5. Gọi API
      final response = await dio.get(_serverUrl);
      
      setState(() {
        _response = "Success:\n${response.data}";
      });

    } on DioException catch (e) {
      // Xử lý lỗi liên quan đến SSL
      if (e.error is HandshakeException) {
        setState(() {
          _response = "Lỗi bảo mật SSL! Chứng chỉ không khớp hoặc không hợp lệ.";
        });
      } else {
        setState(() {
          _response = "Lỗi Dio: ${e.message}";
        });
      }
    } catch (e) {
      setState(() {
        _response = "Lỗi khác: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_response, textAlign: TextAlign.center),
        ),
        ElevatedButton(
          onPressed: fetchData,
          child: const Text("Call Secure API"),
        ),
      ],
    );
  }
}