import 'package:build/build.dart';
import 'package:crud_bloc/src/bloc_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder blocBuilder(BuilderOptions options) => LibraryBuilder(BlocGenerator(), generatedExtension: '.bloc.dart');