import 'package:get/get.dart';



import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';


class AppBinding extends Bindings {
  @override
  void dependencies() {
    
    
    
    
    
    
    Get.lazyPut(() => ServerController());
    Get.lazyPut(() => TorrentController());
  }
}
