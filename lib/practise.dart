
import 'dart:io';

void main(){

  print("Welcome to Dart Brother!");
  stdout.write("Enter your Name : ");
  var name = stdin.readLineSync();
  print('Welcome, $name');
}