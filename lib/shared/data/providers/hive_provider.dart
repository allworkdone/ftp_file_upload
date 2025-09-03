import 'package:hive/hive.dart';

class HiveProvider {
  Box<dynamic> box(String name) => Hive.box(name);

  Future<Box<dynamic>> openBox(String name) async => Hive.openBox(name);
}

