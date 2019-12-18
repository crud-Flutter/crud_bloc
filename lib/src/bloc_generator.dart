import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:crud_bloc/src/class_source.dart';
import 'package:flutter_persistence_api/flutter_persistence_api.dart';
import 'package:source_gen/source_gen.dart';

class BlocGenerator extends GeneratorForAnnotation<Entity> {
  @override
  FutureOr<String> generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    var generateClass = GenerateBlocClass(element.name);
    var fieldAnnotation = TypeChecker.fromRuntime(Field);
    for (var field in (element as ClassElement).fields) {
      generateClass.addField(field.type.name, field.name,
          persistField: fieldAnnotation.hasAnnotationOfExact(field));
    }
    return generateClass.build();
  }
  
}